import Foundation

/// Real-time strain accumulator using Edwards 5-zone TRIMP.
///
/// Mirrors the WHOOP 5.0 approach confirmed via Ghidra MCP analysis:
/// - Strain accumulates locally on-device from live HR during the BLE session
/// - Zone boundaries use %HRmax (6 zones, 0-5, matching WHOOP's 5.37.0 binary)
/// - Raw TRIMP is scaled to 0-21 via logarithmic mapping
/// - HRmax = 220 - age (or last known value from UserDefaults)
///
/// Session window: from first HR sample after connect until disconnect (matching
/// WHOOP's sleep-to-sleep accumulation window for day strain).
@MainActor
public final class LiveStrainAccumulator: ObservableObject {

    // MARK: - Published state

    @Published public private(set) var dayStrain: Double = 0.0     // 0–21 current session
    @Published public private(set) var sessionMinutes: Double = 0.0

    // MARK: - HRmax

    private static let hrMaxKey = "liveStrain.hrMax"

    public var hrMax: Int {
        get { UserDefaults.standard.integer(forKey: Self.hrMaxKey).nonzero ?? defaultHRmax() }
        set { UserDefaults.standard.set(newValue, forKey: Self.hrMaxKey) }
    }

    private func defaultHRmax() -> Int {
        let age = ProfileStorage.load()?.age ?? 30
        return max(150, 220 - age)
    }

    // MARK: - Private accumulators

    private var rawTRIMP: Double = 0.0
    private var lastHR: Int = 0
    private var lastTimestamp: Date? = nil

    // Zone weight multipliers (Edwards 5-zone for %HRmax, matching WHOOP binary)
    // Zone 0 (<50%): rest, no contribution
    // Zone 1 (50–60%): 1.0
    // Zone 2 (60–70%): 2.0
    // Zone 3 (70–80%): 4.0
    // Zone 4 (80–90%): 6.0 (WHOOP uses 6 zones; zone 4/5 split at 90%)
    // Zone 5 (>90%): 10.0
    private static let zoneThresholdsPct: [Double] = [0.50, 0.60, 0.70, 0.80, 0.90, 1.00]
    private static let zoneWeights: [Double]        = [0.0,  1.0,  2.0,  4.0,  6.0, 10.0]

    // Scaling denominator for 0-21: raw TRIMP when you sustain max HR for 2h
    // 2h * 60min * 10.0 (max zone weight) = 1200, ln(1201) ≈ 7.09
    // WHOOP uses a denominator that maps ~full-day max effort to 21
    private static let scalingDenominator: Double = log(7201.0)  // matches our strain.py

    // MARK: - Session control

    public func reset() {
        rawTRIMP = 0.0
        lastHR = 0
        lastTimestamp = nil
        dayStrain = 0.0
        sessionMinutes = 0.0
    }

    // MARK: - HR ingestion

    /// Call this every time a new HR sample arrives from BLE.
    public func ingest(heartRate hr: Int, at now: Date = Date()) {
        guard hr > 0 else { return }
        defer { lastHR = hr; lastTimestamp = now }

        guard let prev = lastTimestamp, lastHR > 0 else {
            lastTimestamp = now
            lastHR = hr
            return
        }

        let dtMinutes = now.timeIntervalSince(prev) / 60.0
        guard dtMinutes > 0, dtMinutes < 10 else { return }   // ignore gaps > 10 min

        let contribution = trimp(hr: hr, dtMinutes: dtMinutes)
        rawTRIMP += contribution
        sessionMinutes += dtMinutes
        dayStrain = scaledStrain(rawTRIMP)
    }

    // MARK: - Private computation

    private func trimp(hr: Int, dtMinutes: Double) -> Double {
        let pct = Double(hr) / Double(hrMax)
        let weight = zoneWeight(for: pct)
        return dtMinutes * weight
    }

    private func zoneWeight(for pct: Double) -> Double {
        if pct < Self.zoneThresholdsPct[0] { return Self.zoneWeights[0] }
        for i in 1..<Self.zoneThresholdsPct.count {
            if pct < Self.zoneThresholdsPct[i] { return Self.zoneWeights[i - 1] }
        }
        return Self.zoneWeights.last!
    }

    private func scaledStrain(_ raw: Double) -> Double {
        guard raw > 0 else { return 0 }
        let scaled = 21.0 * log(raw + 1.0) / Self.scalingDenominator
        return min(21.0, max(0.0, scaled))
    }
}

// MARK: - ProfileStorage access (read-only from accumulator)

private extension Int {
    var nonzero: Int? { self == 0 ? nil : self }
}

// Re-export ProfileStorage from Settings — the accumulator reads age for HRmax estimation.
// ProfileStorage is file-private in SettingsView.swift; we duplicate the minimal read here.
private enum ProfileStorage {
    static let key = "com.openwhoop.profile.v1"
    struct Profile: Codable { var age: Int? }
    static func load() -> Profile? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Profile.self, from: data)
    }
}
