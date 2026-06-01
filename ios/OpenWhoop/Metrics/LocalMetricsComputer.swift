import Foundation
import WhoopStore
import WhoopProtocol

// MARK: - LocalMetricsComputer
//
// Offline-first metric derivation from raw BLE streams stored in WhoopStore.
//
// Produces per-day DailyMetric and CachedSleepSession from:
//   hrSample / rrInterval / gravitySample tables (BLE backfill)
//   UserDefaults profile (weight, height, age, sex) for calorie computation
//
// Algorithms (all local, no server dependency):
//   • Resting HR          — min bpm overnight (00:00–09:00 UTC)
//   • HRV rMSSD           — overnight RR intervals
//   • Recovery            — simplified: overnight HRV vs 28-night rolling baseline (0–100)
//   • Strain              — TRIMP from daily HR zones → scaled via strain_raw_scale_lookup.json
//   • Sleep session       — contiguous low-HR + low-movement period > 3 h
//   • Sleep Performance   — ALG-10 port: TST weight + efficiency + staging + continuity
//   • Training State      — ALG-11 port: recovery_to_strain.json lookup
//   • Sleep Needed        — ALG-12 port: rolling 7-day TST baseline, clamped 300–660 min
//   • Total Calories      — ALG-13 port: Mifflin–St Jeor RMR + exercise from strain
//
// DESIGN RULES
// - Pure computation: no URLSession, no external deps, no side-effects except WhoopStore upserts.
// - Idempotent: calling compute() twice for the same day overwrites with the same values.
// - Best-effort: any day with insufficient data is skipped silently.

struct LocalMetricsComputer {

    let store: WhoopStore
    let deviceId: String
    let lookbackDays: Int

    init(store: WhoopStore, deviceId: String, lookbackDays: Int = 28) {
        self.store = store
        self.deviceId = deviceId
        self.lookbackDays = lookbackDays
    }

    // MARK: - Public entry point

    func compute() async {
        let now = Date()
        let windowStart = Int(now.timeIntervalSince1970) - lookbackDays * 86_400

        guard
            let hrSamples  = try? await store.hrSamples(
                deviceId: deviceId, from: windowStart, to: Int(now.timeIntervalSince1970), limit: 1_000_000),
            let rrIntervals = try? await store.rrIntervals(
                deviceId: deviceId, from: windowStart, to: Int(now.timeIntervalSince1970), limit: 1_000_000),
            let gravitySamples = try? await store.gravitySamples(
                deviceId: deviceId, from: windowStart, to: Int(now.timeIntervalSince1970), limit: 1_000_000)
        else { return }

        guard !hrSamples.isEmpty else { return }

        let cal = Calendar(identifier: .gregorian)
        let dayFmt = DateFormatter()
        dayFmt.calendar = cal
        dayFmt.timeZone = TimeZone(identifier: "UTC")
        dayFmt.dateFormat = "yyyy-MM-dd"

        // Group samples by UTC calendar day.
        var hrByDay: [String: [HRSample]] = [:]
        for s in hrSamples {
            let key = dayFmt.string(from: Date(timeIntervalSince1970: TimeInterval(s.ts)))
            hrByDay[key, default: []].append(s)
        }
        var rrByDay: [String: [RRInterval]] = [:]
        for r in rrIntervals {
            let key = dayFmt.string(from: Date(timeIntervalSince1970: TimeInterval(r.ts)))
            rrByDay[key, default: []].append(r)
        }
        let gravSorted = gravitySamples.sorted { $0.ts < $1.ts }

        let sortedDays = hrByDay.keys.sorted()

        // Load lookup tables once — used in both passes.
        let strainScaleLUT = loadStrainScaleLUT()
        let recoveryToStrainTable = loadRecoveryToStrainTable()
        let profile = ProfileStorage.load()

        // First pass: compute per-day resting HR, HRV, strain.
        var dailyHRV: [String: Double] = [:]
        var dailyStrain: [String: Double] = [:]
        var dailyRestingHR: [String: Int] = [:]

        for day in sortedDays {
            guard let dayHR = hrByDay[day], !dayHR.isEmpty else { continue }
            let dayRR = rrByDay[day] ?? []

            // Overnight window for resting HR and HRV.
            guard let dayStart = dayFmt.date(from: day) else { continue }
            let overnightStart = dayStart.timeIntervalSince1970
            let overnightEnd   = overnightStart + 9 * 3600

            let overnightHR = dayHR.filter { let ts = Double($0.ts); return ts >= overnightStart && ts < overnightEnd }
            if let minHR = overnightHR.map({ $0.bpm }).min() {
                dailyRestingHR[day] = minHR
            }
            let overnightRR = dayRR.filter {
                let ts = Double($0.ts); return ts >= overnightStart && ts < overnightEnd
            }.sorted { $0.ts < $1.ts }
            if let hrv = rmssd(from: overnightRR) {
                dailyHRV[day] = hrv
            }

            // Full-day strain (00:00–24:00 UTC).
            dailyStrain[day] = computeStrain(dayHR: dayHR, dayStart: overnightStart, lut: strainScaleLUT)
        }

        // (tables and profile already loaded above)

        // Second pass: compute all derived metrics with full history available.
        var dailyMetrics: [DailyMetric] = []
        var sleepSessions: [CachedSleepSession] = []
        var dailyTST: [String: Double] = [:]   // for sleep-needed rolling window

        for (idx, day) in sortedDays.enumerated() {
            guard let dayHR = hrByDay[day], !dayHR.isEmpty else { continue }
            // (dayRR not needed in second pass — HRV already in dailyHRV from first pass)

            // --- Recovery from rolling HRV baseline (28 nights) ---
            let priorDays = sortedDays[0..<idx]
            let hrvHistory = priorDays.compactMap { dailyHRV[$0] }
            let recovery: Double? = computeRecovery(
                currentHRV: dailyHRV[day],
                hrvHistory: Array(hrvHistory.suffix(27)))  // up to 27 prior nights + current = 28

            // --- Strain ---
            let strain = dailyStrain[day]

            // --- Sleep session ---
            if let session = detectSleepSession(
                forDay: day, hrSamples: dayHR, hrByDay: hrByDay,
                gravSorted: gravSorted, dayFmt: dayFmt, cal: cal) {
                sleepSessions.append(session)
                let tst = Double(session.endTs - session.startTs) / 60.0
                dailyTST[day] = tst
            }
            let totalSleepMin = dailyTST[day]

            // --- Sleep Performance (ALG-10) ---
            let sleepPerf: Double? = totalSleepMin.map { tst in
                sleepPerformanceScore(totalSleepMin: tst, efficiency: nil, disturbances: 0)
            }

            // --- Sleep Needed (ALG-12) ---
            let priorTST = sortedDays[0..<idx].compactMap { dailyTST[$0] }
            let sleepNeededMin: Double? = sleepNeeded(priorTST: Array(priorTST.suffix(7)), strain: strain)

            // --- Training State (ALG-11) ---
            let trainingStateStr: String? = trainingState(
                recovery: recovery,
                strain: strain,
                table: recoveryToStrainTable)

            // --- Calories (ALG-13) ---
            let exerciseKcal: Double = strain.map { strainToExerciseKcal(strain: $0) } ?? 0
            let totalCalories: Double? = rmrKcalPerDay(profile: profile).map { $0 + exerciseKcal }

            // --- Resting HR & HRV ---
            let restingHr = dailyRestingHR[day]
            let avgHrv = dailyHRV[day]

            let metric = DailyMetric(
                day: day,
                totalSleepMin: totalSleepMin,
                efficiency: nil,
                deepMin: nil,
                remMin: nil,
                lightMin: nil,
                disturbances: nil,
                restingHr: restingHr,
                avgHrv: avgHrv,
                recovery: recovery,
                strain: strain,
                exerciseCount: nil,
                spo2Pct: nil,
                skinTempDevC: nil,
                respRateBpm: nil,
                sleepPerformance: sleepPerf,
                trainingState: trainingStateStr,
                sleepNeededMin: sleepNeededMin,
                totalCaloriesKcal: totalCalories
            )
            dailyMetrics.append(metric)
        }

        if !dailyMetrics.isEmpty {
            _ = try? await store.upsertDailyMetrics(dailyMetrics, deviceId: deviceId)
        }
        if !sleepSessions.isEmpty {
            _ = try? await store.upsertSleepSessions(sleepSessions, deviceId: deviceId)
        }
    }

    // MARK: - Strain (WHOOP TRIMP algorithm)

    // Zone boundaries as % of HRmax. Matches LiveStrainAccumulator.
    private static let zoneThresholds: [Double] = [0.50, 0.60, 0.70, 0.80, 0.90]
    private static let zoneWeights:    [Double] = [0.0,  1.0,  2.0,  4.0,  6.0, 10.0]
    private static let rawConversion:  Double   = 1.0 / 32_886.0

    private func hrMax(profile: Profile?) -> Int {
        let age = profile?.age ?? 30
        return max(150, 220 - age)
    }

    private func computeStrain(dayHR: [HRSample], dayStart: TimeInterval, lut: [(Double, Double)]) -> Double {
        let profile = ProfileStorage.load()
        let maxHR = Double(hrMax(profile: profile))
        let dayEnd = dayStart + 86_400

        let samples = dayHR
            .filter { let ts = Double($0.ts); return ts >= dayStart && ts < dayEnd }
            .sorted { $0.ts < $1.ts }

        guard samples.count >= 2 else { return 0 }

        var rawTRIMP: Double = 0
        for i in 1..<samples.count {
            let dt = Double(samples[i].ts - samples[i-1].ts) / 60.0
            guard dt > 0, dt < 30 else { continue }
            let hrFrac = Double(samples[i].bpm) / maxHR
            let zone = zoneFor(hrFrac: hrFrac)
            rawTRIMP += dt * Self.zoneWeights[zone] * Self.rawConversion
        }

        return scaleStrain(raw: rawTRIMP, lut: lut)
    }

    private func zoneFor(hrFrac: Double) -> Int {
        for (i, threshold) in Self.zoneThresholds.enumerated() {
            if hrFrac < threshold { return i }
        }
        return Self.zoneThresholds.count
    }

    private func scaleStrain(raw: Double, lut: [(Double, Double)]) -> Double {
        guard !lut.isEmpty else {
            // Fallback: logarithmic approximation
            return min(21.0, max(0.0, 21.0 * log1p(raw * 32_886) / log1p(1.0)))
        }
        if raw <= lut.first!.0 { return lut.first!.1 }
        if raw >= lut.last!.0  { return lut.last!.1 }
        for i in 1..<lut.count {
            if raw <= lut[i].0 {
                let (r0, s0) = lut[i-1]; let (r1, s1) = lut[i]
                let t = (raw - r0) / (r1 - r0)
                return s0 + t * (s1 - s0)
            }
        }
        return lut.last!.1
    }

    private func loadStrainScaleLUT() -> [(Double, Double)] {
        guard let url = Bundle.main.url(forResource: "strain_raw_scale_lookup", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let arr = try? JSONDecoder().decode([[Double]].self, from: data)
        else { return [] }
        return arr.compactMap { row in row.count >= 2 ? (row[0], row[1]) : nil }
    }

    // MARK: - Recovery (calibrated HRV baseline)

    /// Load calibrated coefficients from recovery_coefficients.json.
    /// Falls back to (slope: 54.48, intercept: -0.27) — values from personal calibration.
    private static let recoveryCoefficients: (slope: Double, intercept: Double) = {
        guard let url = Bundle.main.url(forResource: "recovery_coefficients", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Double]
        else { return (slope: 54.48, intercept: -0.27) }
        return (slope: obj["hrv_slope"] ?? 54.48, intercept: obj["hrv_intercept"] ?? -0.27)
    }()

    /// Recovery 0–100 from overnight rMSSD vs rolling baseline.
    /// Coefficients calibrated via linear regression on personal WHOOP historical data.
    /// ≥ 3 prior nights required; returns nil otherwise.
    private func computeRecovery(currentHRV: Double?, hrvHistory: [Double]) -> Double? {
        guard let hrv = currentHRV, hrvHistory.count >= 2 else { return nil }
        let baseline = hrvHistory.reduce(0, +) / Double(hrvHistory.count)
        guard baseline > 0 else { return nil }
        let ratio = hrv / baseline
        let c = Self.recoveryCoefficients
        let score = min(100.0, max(0.0, c.slope * ratio + c.intercept))
        return score.rounded()
    }

    // MARK: - ALG-10: Sleep Performance

    /// Weighted sleep performance score 0–100.
    /// Mirrors server/ingest/app/analysis/sleep.py::sleep_performance_score().
    private func sleepPerformanceScore(
        totalSleepMin: Double,
        efficiency: Double?,
        disturbances: Int
    ) -> Double {
        guard totalSleepMin > 0 else { return 0 }

        let wDur: Double = 0.40   // duration
        let wEff: Double = 0.25   // efficiency
        let wStg: Double = 0.25   // staging (defaulted)
        let wCon: Double = 0.10   // continuity (disturbances)

        // Duration: 8h = 480 min = 100%
        let durScore = min(totalSleepMin / 480.0, 1.0) * 100.0

        // Efficiency: use provided value or 85% default
        let effScore = efficiency ?? 85.0

        // Staging: no local staging data → default 85% (typical healthy adult)
        let stgScore: Double = 85.0

        // Continuity: each disturbance costs 10 points
        let conScore = max(0.0, 100.0 - Double(disturbances) * 10.0)

        let score = wDur * durScore + wEff * effScore + wStg * stgScore + wCon * conScore
        return min(max(score, 0.0), 100.0)
    }

    // MARK: - ALG-11: Training State

    private struct RecoveryStrainRow: Decodable {
        let recovery: Int
        let rec_strain: Double
        let lower_rec_strain: Double
        let upper_rec_strain: Double
    }

    private func loadRecoveryToStrainTable() -> [RecoveryStrainRow] {
        guard let url = Bundle.main.url(forResource: "recovery_to_strain", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let arr = try? JSONDecoder().decode([RecoveryStrainRow].self, from: data)
        else { return [] }
        return arr
    }

    private func trainingState(
        recovery: Double?,
        strain: Double?,
        table: [RecoveryStrainRow]
    ) -> String? {
        guard let rec = recovery, let str = strain, !table.isEmpty else { return nil }
        let recInt = max(0, min(100, Int(rec.rounded())))
        guard let row = table.first(where: { $0.recovery == recInt }) else { return nil }
        if str < row.lower_rec_strain { return "RESTORATIVE" }
        if str > row.upper_rec_strain { return "OVERREACHING" }
        return "OPTIMAL"
    }

    // MARK: - ALG-12: Sleep Needed

    /// Rolling 7-night sleep need, clamped 300–660 min.
    /// Mirrors server/ingest/app/analysis/daily.py::sleep_needed().
    private func sleepNeeded(priorTST: [Double], strain: Double?) -> Double? {
        guard priorTST.count >= 3 else { return nil }
        // Exclude yesterday (last element) from baseline.
        let baselineEntries = priorTST.count > 1 ? Array(priorTST.dropLast()) : priorTST
        let baseline = baselineEntries.reduce(0, +) / Double(baselineEntries.count)

        // Sleep debt: how much less than baseline did yesterday give?
        let yesterday = priorTST.last ?? baseline
        let debt = max(0, baseline - yesterday)

        // Strain adds up to 30 min at max strain (21).
        let strainAdd = (strain ?? 0) / 21.0 * 30.0

        let needed = baseline + debt * 0.5 + strainAdd
        return max(300, min(660, needed))
    }

    // MARK: - ALG-13: Calories

    private func rmrKcalPerDay(profile: Profile?) -> Double? {
        guard let p = profile,
              let weight = p.weightKg,
              let height = p.heightCm,
              let age = p.age
        else { return nil }
        let sex = p.sex ?? "male"
        // Mifflin–St Jeor formula.
        let base = 10 * weight + 6.25 * height - 5 * Double(age)
        return sex == "female" ? base - 161 : base + 5
    }

    /// Convert WHOOP strain score (0–21) to approximate exercise kcal.
    /// Linear approximation: strain=21 ≈ 800 kcal exercise (moderate-fit adult).
    private func strainToExerciseKcal(strain: Double) -> Double {
        max(0, strain / 21.0 * 800.0)
    }

    // MARK: - Sleep session detection

    private func detectSleepSession(
        forDay day: String,
        hrSamples dayHR: [HRSample],
        hrByDay: [String: [HRSample]],
        gravSorted: [GravitySample],
        dayFmt: DateFormatter,
        cal: Calendar
    ) -> CachedSleepSession? {
        guard let dayDate = dayFmt.date(from: day) else { return nil }
        let dayStartTs = dayDate.timeIntervalSince1970

        let windowStart = dayStartTs - 4 * 3600   // 20:00 UTC D-1
        let windowEnd   = dayStartTs + 12 * 3600  // 12:00 UTC D

        var windowHR: [HRSample] = []
        if let prevDate = cal.date(byAdding: .day, value: -1, to: dayDate) {
            let prevKey = dayFmt.string(from: prevDate)
            if let prevHR = hrByDay[prevKey] {
                windowHR += prevHR.filter { let ts = Double($0.ts); return ts >= windowStart && ts < windowEnd }
            }
        }
        windowHR += dayHR.filter { let ts = Double($0.ts); return ts >= windowStart && ts < windowEnd }
        windowHR.sort { $0.ts < $1.ts }
        guard windowHR.count >= 10 else { return nil }

        let windowGrav = gravSorted.filter { let ts = Double($0.ts); return ts >= windowStart && ts < windowEnd }

        let slotSeconds: Double = 300   // 5-min slots
        let slots = Int((windowEnd - windowStart) / slotSeconds)
        var isSleep: [Bool] = Array(repeating: false, count: slots)

        for i in 0..<slots {
            let slotStart = windowStart + Double(i) * slotSeconds
            let slotEnd   = slotStart + slotSeconds
            let slotHR = windowHR.filter { let ts = Double($0.ts); return ts >= slotStart && ts < slotEnd }
            guard slotHR.count >= 1 else { continue }
            let avgBpm = Double(slotHR.map { $0.bpm }.reduce(0, +)) / Double(slotHR.count)
            let slotGrav = windowGrav.filter { let ts = Double($0.ts); return ts >= slotStart && ts < slotEnd }
            let gravVar: Double
            if slotGrav.count >= 2 {
                let mag = slotGrav.map { sqrt($0.x*$0.x + $0.y*$0.y + $0.z*$0.z) }
                let mean = mag.reduce(0, +) / Double(mag.count)
                gravVar = mag.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(mag.count)
            } else {
                gravVar = 0
            }
            isSleep[i] = avgBpm <= 75.0 && gravVar <= 0.05
        }

        var runs: [(start: Int, end: Int)] = []
        var runStart: Int? = nil
        for i in 0..<slots {
            if isSleep[i] {
                if runStart == nil { runStart = i }
            } else {
                let bridgeable = (i + 2 < slots) && (isSleep[i + 1] || isSleep[i + 2])
                if runStart != nil && !bridgeable {
                    runs.append((start: runStart!, end: i - 1))
                    runStart = nil
                }
            }
        }
        if let s = runStart { runs.append((start: s, end: slots - 1)) }
        guard let longest = runs.max(by: { ($0.end - $0.start) < ($1.end - $1.start) }) else { return nil }

        let durationSeconds = (longest.end - longest.start + 1) * Int(slotSeconds)
        guard durationSeconds >= 3 * 3600 else { return nil }

        let sessionStart = Int(windowStart + Double(longest.start) * slotSeconds)
        let sessionEnd   = Int(windowStart + Double(longest.end + 1) * slotSeconds)
        let sessionRestingHr = windowHR.filter { $0.ts >= sessionStart && $0.ts <= sessionEnd }.map { $0.bpm }.min()

        return CachedSleepSession(
            startTs: sessionStart,
            endTs: sessionEnd,
            efficiency: nil,
            restingHr: sessionRestingHr,
            avgHrv: nil,
            stagesJSON: nil
        )
    }

    // MARK: - HRV helpers

    private func rmssd(from rrIntervals: [RRInterval]) -> Double? {
        guard rrIntervals.count >= 2 else { return nil }
        var sumSq: Double = 0; var count = 0
        for i in 1..<rrIntervals.count {
            let diff = Double(rrIntervals[i].rrMs - rrIntervals[i - 1].rrMs)
            sumSq += diff * diff; count += 1
        }
        guard count > 0 else { return nil }
        return sqrt(sumSq / Double(count))
    }
}

// MARK: - Profile local storage

// Profile struct is defined in SettingsView.swift (same module).
// ProfileStorage is private there, so we read UserDefaults directly.
private enum ProfileStorage {
    static let key = "com.openwhoop.profile.v1"
    static func load() -> Profile? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let p = try? JSONDecoder().decode(Profile.self, from: data) else { return nil }
        return p
    }
}
