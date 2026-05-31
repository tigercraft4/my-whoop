import Foundation
import WhoopStore
import WhoopProtocol

// MARK: - LocalMetricsComputer
//
// Offline-first metric derivation from raw BLE streams stored in WhoopStore.
//
// When the server is unconfigured (Secrets.xcconfig has placeholder values → serverSync == nil),
// the app still has rich biometric history in the local hrSample / rrInterval / gravitySample
// tables from BLE backfill. This computer reads those raw streams and produces:
//
//   • CachedSleepSession — contiguous low-HR + low-movement period > 3 h (20:00–12:00 window)
//   • DailyMetric        — resting HR (min bpm 00:00–09:00), HRV rMSSD (overnight RR intervals)
//
// All estimates are clearly heuristic — they are displayed as-is and labelled "estimated" in the
// UI. They are NEVER uploaded to the server. When server metrics are available they take priority
// (upsertSleepSessions / upsertDailyMetrics ON CONFLICT → server values win on re-pull).
//
// DESIGN RULES
// - Pure computation: no URLSession, no external deps, no side-effects except WhoopStore upserts.
// - Idempotent: calling compute() twice for the same day overwrites with the same values.
// - Best-effort: any day with insufficient data is skipped silently (not an error).
// - lookback: number of calendar days to analyse (default 14, matching MetricsRepository.load).

struct LocalMetricsComputer {

    let store: WhoopStore
    let deviceId: String
    let lookbackDays: Int

    init(store: WhoopStore, deviceId: String, lookbackDays: Int = 14) {
        self.store = store
        self.deviceId = deviceId
        self.lookbackDays = lookbackDays
    }

    // MARK: - Public entry point

    /// Derive sleep sessions and daily metrics from raw BLE streams and upsert them into the
    /// local cache. Safe to call from any async context. No-op on any fetch/upsert error.
    func compute() async {
        let now = Date()
        let windowStart = Int(now.timeIntervalSince1970) - lookbackDays * 86_400

        // Fetch raw streams for the entire lookback window in one pass.
        guard
            let hrSamples  = try? await store.hrSamples(
                deviceId: deviceId, from: windowStart, to: Int(now.timeIntervalSince1970), limit: 500_000),
            let rrIntervals = try? await store.rrIntervals(
                deviceId: deviceId, from: windowStart, to: Int(now.timeIntervalSince1970), limit: 500_000),
            let gravitySamples = try? await store.gravitySamples(
                deviceId: deviceId, from: windowStart, to: Int(now.timeIntervalSince1970), limit: 500_000)
        else { return }

        guard !hrSamples.isEmpty else { return }   // nothing to compute

        // Partition samples into UTC calendar days.
        let cal = Calendar(identifier: .gregorian)
        var utcComponents = cal.dateComponents([.year, .month, .day], from: now)
        utcComponents.timeZone = TimeZone(identifier: "UTC")

        let dayFmt = DateFormatter()
        dayFmt.calendar = cal
        dayFmt.timeZone = TimeZone(identifier: "UTC")
        dayFmt.dateFormat = "yyyy-MM-dd"

        // Group HR samples by UTC day key.
        var hrByDay: [String: [HRSample]] = [:]
        for s in hrSamples {
            let date = Date(timeIntervalSince1970: TimeInterval(s.ts))
            let key = dayFmt.string(from: date)
            hrByDay[key, default: []].append(s)
        }

        // Group RR intervals by UTC day key.
        var rrByDay: [String: [RRInterval]] = [:]
        for r in rrIntervals {
            let date = Date(timeIntervalSince1970: TimeInterval(r.ts))
            let key = dayFmt.string(from: date)
            rrByDay[key, default: []].append(r)
        }

        // Index gravity by ts for fast range lookup (sorted, used for variance in sleep windows).
        let gravSorted = gravitySamples.sorted { $0.ts < $1.ts }

        // Compute per-day metrics.
        var dailyMetrics: [DailyMetric] = []
        var sleepSessions: [CachedSleepSession] = []

        // Iterate each day for which we have HR data.
        let sortedDays = hrByDay.keys.sorted()
        for day in sortedDays {
            guard let dayHR = hrByDay[day], !dayHR.isEmpty else { continue }
            let dayRR = rrByDay[day] ?? []

            // DAILY METRIC — resting HR and HRV from the overnight window (00:00–09:00 UTC).
            let dayMetric = computeDailyMetric(
                day: day, hrSamples: dayHR, rrIntervals: dayRR, dayFmt: dayFmt)
            if let m = dayMetric { dailyMetrics.append(m) }

            // SLEEP SESSION — detect sleep in the 20:00 (prior day) → 12:00 (this day) window.
            // The "night before day D" spans from 20:00 UTC on day D-1 to 12:00 UTC on day D.
            if let session = detectSleepSession(
                forDay: day, hrSamples: dayHR, hrByDay: hrByDay,
                gravSorted: gravSorted, dayFmt: dayFmt, cal: cal) {
                sleepSessions.append(session)
            }
        }

        // Upsert results. ON CONFLICT clauses mean server values override these on next server pull.
        if !dailyMetrics.isEmpty {
            try? await store.upsertDailyMetrics(dailyMetrics, deviceId: deviceId)
        }
        if !sleepSessions.isEmpty {
            try? await store.upsertSleepSessions(sleepSessions, deviceId: deviceId)
        }
    }

    // MARK: - Daily metric computation

    /// Returns a DailyMetric for `day` if there are enough overnight HR/RR samples.
    private func computeDailyMetric(
        day: String,
        hrSamples: [HRSample],
        rrIntervals: [RRInterval],
        dayFmt: DateFormatter
    ) -> DailyMetric? {
        // Overnight window: 00:00 → 09:00 UTC of `day`.
        guard let dayStart = dayFmt.date(from: day) else { return nil }
        let overnightStart = dayStart.timeIntervalSince1970              // 00:00 UTC
        let overnightEnd   = overnightStart + 9 * 3600                  // 09:00 UTC

        let overnightHR = hrSamples.filter {
            let ts = Double($0.ts)
            return ts >= overnightStart && ts < overnightEnd
        }
        guard overnightHR.count >= 5 else { return nil }   // need at least 5 samples

        // Resting HR: minimum bpm in the overnight window.
        let restingHr = overnightHR.map { $0.bpm }.min()!

        // HRV (rMSSD): root mean square of successive RR differences, overnight window.
        let overnightRR = rrIntervals.filter {
            let ts = Double($0.ts)
            return ts >= overnightStart && ts < overnightEnd
        }.sorted { $0.ts < $1.ts }
        let avgHrv: Double? = rmssd(from: overnightRR)

        return DailyMetric(
            day: day,
            totalSleepMin: nil,     // filled by sleep session detection below (or by server)
            efficiency: nil,
            deepMin: nil,
            remMin: nil,
            lightMin: nil,
            disturbances: nil,
            restingHr: restingHr,
            avgHrv: avgHrv,
            recovery: nil,          // cannot be computed locally (needs HRV trend baseline)
            strain: nil,
            exerciseCount: nil,
            spo2Pct: nil,
            skinTempDevC: nil,
            respRateBpm: nil
        )
    }

    // MARK: - Sleep session detection

    /// Detect the main sleep period for the night leading into `day`.
    ///
    /// Algorithm:
    /// 1. Build a candidate window: 20:00 UTC of the PREVIOUS calendar day → 12:00 UTC of `day`.
    /// 2. Collect HR samples in this window from both the previous day's bucket and this day's bucket.
    /// 3. Slide a 30-minute rolling window looking for contiguous low-HR (≤ 75 bpm) + low-movement
    ///    (gravity variance ≤ 0.05 g²) epochs. Adjacent windows are merged if gap ≤ 10 min.
    /// 4. The longest merged block ≥ 3 h is declared the sleep session.
    private func detectSleepSession(
        forDay day: String,
        hrSamples dayHR: [HRSample],
        hrByDay: [String: [HRSample]],
        gravSorted: [GravitySample],
        dayFmt: DateFormatter,
        cal: Calendar
    ) -> CachedSleepSession? {
        guard let dayDate = dayFmt.date(from: day) else { return nil }
        let dayStartTs = dayDate.timeIntervalSince1970   // 00:00 UTC of day D

        // Window: 20:00 UTC D-1 → 12:00 UTC D.
        let windowStart = dayStartTs - 4 * 3600          // = 20:00 UTC of D-1
        let windowEnd   = dayStartTs + 12 * 3600         // = 12:00 UTC of D

        // Collect HR from previous day's bucket + this day's bucket.
        var windowHR: [HRSample] = []
        // Previous day key.
        if let prevDate = cal.date(byAdding: .day, value: -1, to: dayDate) {
            let prevKey = dayFmt.string(from: prevDate)
            if let prevHR = hrByDay[prevKey] {
                windowHR += prevHR.filter {
                    let ts = Double($0.ts); return ts >= windowStart && ts < windowEnd
                }
            }
        }
        windowHR += dayHR.filter {
            let ts = Double($0.ts); return ts >= windowStart && ts < windowEnd
        }
        windowHR.sort { $0.ts < $1.ts }

        guard windowHR.count >= 10 else { return nil }   // too sparse

        // Gravity samples in this window.
        let windowGrav = gravSorted.filter {
            let ts = Double($0.ts); return ts >= windowStart && ts < windowEnd
        }

        // Epoch-based sliding-window: bucket by 5-minute slots.
        let slotSeconds: Double = 300   // 5 min
        let slots = Int((windowEnd - windowStart) / slotSeconds)

        var isSleep: [Bool] = Array(repeating: false, count: slots)

        for i in 0..<slots {
            let slotStart = windowStart + Double(i) * slotSeconds
            let slotEnd   = slotStart + slotSeconds

            let slotHR = windowHR.filter {
                let ts = Double($0.ts); return ts >= slotStart && ts < slotEnd
            }
            guard slotHR.count >= 1 else { continue }
            let avgBpm = Double(slotHR.map { $0.bpm }.reduce(0, +)) / Double(slotHR.count)

            // Gravity variance in this slot.
            let slotGrav = windowGrav.filter {
                let ts = Double($0.ts); return ts >= slotStart && ts < slotEnd
            }
            let gravVar: Double
            if slotGrav.count >= 2 {
                let magnitudes = slotGrav.map { sqrt($0.x*$0.x + $0.y*$0.y + $0.z*$0.z) }
                let mean = magnitudes.reduce(0, +) / Double(magnitudes.count)
                let variance = magnitudes.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(magnitudes.count)
                gravVar = variance
            } else {
                gravVar = 0   // no movement data → assume still (conservative)
            }

            // Sleep slot: low heart rate AND low movement.
            isSleep[i] = avgBpm <= 75.0 && gravVar <= 0.05
        }

        // Merge adjacent sleep slots (allow gap of up to 2 slots = 10 min for brief awakenings).
        var runs: [(start: Int, end: Int)] = []
        var runStart: Int? = nil
        for i in 0..<slots {
            if isSleep[i] {
                if runStart == nil { runStart = i }
            } else {
                // Check gap tolerance: if the next 2 slots have sleep, bridge the gap.
                let bridgeable = (i + 2 < slots) && (isSleep[i + 1] || isSleep[i + 2])
                if runStart != nil && !bridgeable {
                    runs.append((start: runStart!, end: i - 1))
                    runStart = nil
                }
            }
        }
        if let s = runStart { runs.append((start: s, end: slots - 1)) }

        // Find the longest run.
        guard let longest = runs.max(by: { ($0.end - $0.start) < ($1.end - $1.start) }) else { return nil }

        let durationSlots = longest.end - longest.start + 1
        let durationSeconds = durationSlots * Int(slotSeconds)
        guard durationSeconds >= 3 * 3600 else { return nil }   // minimum 3 hours

        let sessionStart = Int(windowStart + Double(longest.start) * slotSeconds)
        let sessionEnd   = Int(windowStart + Double(longest.end + 1) * slotSeconds)

        // Compute resting HR and HRV for the detected window.
        let sessionHR = windowHR.filter { $0.ts >= sessionStart && $0.ts <= sessionEnd }
        let sessionRestingHr = sessionHR.map { $0.bpm }.min()

        return CachedSleepSession(
            startTs: sessionStart,
            endTs: sessionEnd,
            efficiency: nil,        // cannot determine without gold-standard PSG
            restingHr: sessionRestingHr,
            avgHrv: nil,            // rMSSD available via dailyMetric.avgHrv
            stagesJSON: nil         // stage classification not available offline
        )
    }

    // MARK: - HRV helpers

    /// Root mean square of successive differences between consecutive RR intervals (rMSSD, ms).
    /// Returns nil when fewer than 2 intervals are available.
    private func rmssd(from rrIntervals: [RRInterval]) -> Double? {
        guard rrIntervals.count >= 2 else { return nil }
        var sumSq: Double = 0
        var count = 0
        for i in 1..<rrIntervals.count {
            let diff = Double(rrIntervals[i].rrMs - rrIntervals[i - 1].rrMs)
            sumSq += diff * diff
            count += 1
        }
        guard count > 0 else { return nil }
        return sqrt(sumSq / Double(count))
    }
}
