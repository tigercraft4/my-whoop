import Foundation
import Combine

/// Real-time strain accumulator using the exact WHOOP scaling table.
///
/// Algorithm confirmed via Ghidra MCP analysis of WHOOP 5.37.0:
/// - Zone boundaries: %HRmax (not %HRR) — 6 zones (0–5)
/// - Raw TRIMP = sum(dt_minutes * zone_weight) / 32886
/// - Scaled 0–21 via `strain_raw_scale_lookup.json` (211-entry table bundled with IPA)
/// - HRmax = 220 - age (from Body Profile) or last stored value
///
/// Thread-safety: ingest() dispatches to main queue before mutating @Published.
public final class LiveStrainAccumulator: ObservableObject {

    // MARK: - Published

    @Published public private(set) var dayStrain: Double = 0.0
    @Published public private(set) var sessionMinutes: Double = 0.0

    // MARK: - HRmax

    private static let hrMaxKey = "liveStrain.hrMax"

    public var hrMax: Int {
        get {
            let v = UserDefaults.standard.integer(forKey: Self.hrMaxKey)
            return v > 0 ? v : defaultHRmax()
        }
        set { UserDefaults.standard.set(newValue, forKey: Self.hrMaxKey) }
    }

    private func defaultHRmax() -> Int {
        let age = (UserDefaults.standard.data(forKey: "com.openwhoop.profile.v1")
            .flatMap { try? JSONDecoder().decode(AgeOnlyProfile.self, from: $0) }
            .flatMap { $0.age }) ?? 30
        return max(150, 220 - age)
    }

    // MARK: - Zone config (matches WHOOP binary, %HRmax)

    // 6 zones: zone 0 = rest (<50%), zones 1-5 = active
    private static let thresholds: [Double] = [0.50, 0.60, 0.70, 0.80, 0.90]
    private static let weights:    [Double] = [0.0,  1.0,  2.0,  4.0,  6.0,  10.0]

    // Conversion: Edwards_TRIMP_minutes → WHOOP raw (confirmed from strain_raw_scale_lookup.json)
    // 60min zone2 (weight=2.0) → raw=0.003649 → scaled=10.0
    // k = 0.003649 / (60 * 2.0) = 1/32886
    private static let rawConversion: Double = 1.0 / 32886.0

    // MARK: - Lookup table (loaded once)

    private static let lookupTable: [(raw: Double, scaled: Double)] = {
        guard let url = Bundle.main.url(forResource: "strain_raw_scale_lookup", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let arr = try? JSONDecoder().decode([[Double]].self, from: data)
        else {
            // Fallback: logarithmic approximation if table missing
            return []
        }
        return arr.map { ($0[0], $0[1]) }
    }()

    // MARK: - Private accumulators (main thread only)

    private var rawTRIMP: Double = 0.0
    private var lastHR: Int = 0
    private var lastTimestamp: Date?

    // MARK: - Public API

    public func reset() {
        rawTRIMP = 0; lastHR = 0; lastTimestamp = nil
        dayStrain = 0; sessionMinutes = 0
    }

    /// Call from any thread. Dispatches to main before touching @Published.
    public func ingest(heartRate hr: Int, at now: Date = Date()) {
        guard hr > 0 else { return }
        DispatchQueue.main.async { [weak self] in
            self?.accumulate(hr: hr, at: now)
        }
    }

    // MARK: - Private (main thread)

    private func accumulate(hr: Int, at now: Date) {
        defer { lastHR = hr; lastTimestamp = now }
        guard let prev = lastTimestamp, lastHR > 0 else { return }

        let dtMin = now.timeIntervalSince(prev) / 60.0
        guard dtMin > 0, dtMin < 10 else { return }

        let pct = Double(hr) / Double(hrMax)
        let w   = zoneWeight(for: pct)
        rawTRIMP    += dtMin * w * Self.rawConversion
        sessionMinutes += dtMin
        dayStrain    = scaledStrain(rawTRIMP)
    }

    private func zoneWeight(for pct: Double) -> Double {
        for (i, t) in Self.thresholds.enumerated() where pct < t {
            return Self.weights[i]
        }
        return Self.weights.last!
    }

    private func scaledStrain(_ raw: Double) -> Double {
        let table = Self.lookupTable
        guard !table.isEmpty else {
            // Logarithmic fallback (approximate, not WHOOP-exact)
            guard raw > 0 else { return 0 }
            return min(21, max(0, 21 * log(raw + 1) / log(7201)))
        }
        guard raw > 0 else { return 0 }
        if raw >= table.last!.raw { return 21 }
        // Binary search + linear interpolation
        var lo = 0, hi = table.count - 1
        while lo < hi - 1 {
            let mid = (lo + hi) / 2
            if table[mid].raw <= raw { lo = mid } else { hi = mid }
        }
        let (r0, s0) = table[lo]
        let (r1, s1) = table[lo + 1]
        let t = (raw - r0) / (r1 - r0)
        return min(21, s0 + t * (s1 - s0))
    }
}

private struct AgeOnlyProfile: Decodable { var age: Int? }
