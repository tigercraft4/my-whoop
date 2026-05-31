import Foundation
import Combine

/// Real-time strain accumulator using Edwards 6-zone %HRmax TRIMP.
///
/// Mirrors WHOOP on-device computation confirmed via Ghidra MCP:
/// - Zone boundaries: %HRmax (not %HRR)
/// - 6 zones (0–5), zone 0 = rest/no contribution
/// - Raw TRIMP scaled to 0–21 via logarithm
/// - HRmax from profile age (220 - age) or last stored value
///
/// Thread-safety: all mutations go through `ingest()` which dispatches
/// to the main queue before touching @Published properties.
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
        let age = (UserDefaults.standard.object(forKey: "com.openwhoop.profile.v1")
            .flatMap { $0 as? Data }
            .flatMap { try? JSONDecoder().decode(AgeOnlyProfile.self, from: $0) }
            .flatMap { $0.age }) ?? 30
        return max(150, 220 - age)
    }

    // MARK: - Accumulators (private, main-thread only)

    private var rawTRIMP: Double = 0.0
    private var lastHR: Int = 0
    private var lastTimestamp: Date?

    // Zone thresholds as fraction of HRmax — 6 zones matching WHOOP binary
    private static let thresholds: [Double] = [0.50, 0.60, 0.70, 0.80, 0.90]
    private static let weights:    [Double] = [0.0,  1.0,  2.0,  4.0,  6.0,  10.0]

    // ln(7201) ≈ 8.882 — denominator matching our strain.py
    private static let D = log(7201.0)

    // MARK: - API

    public func reset() {
        rawTRIMP = 0; lastHR = 0; lastTimestamp = nil
        dayStrain = 0; sessionMinutes = 0
    }

    /// Ingest one HR reading. Safe to call from any thread.
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

        let dt = now.timeIntervalSince(prev) / 60.0   // minutes
        guard dt > 0, dt < 10 else { return }

        let pct = Double(hr) / Double(hrMax)
        let w   = weight(for: pct)
        rawTRIMP   += dt * w
        sessionMinutes += dt
        dayStrain   = min(21, max(0, 21 * log(rawTRIMP + 1) / Self.D))
    }

    private func weight(for pct: Double) -> Double {
        for (i, t) in Self.thresholds.enumerated() where pct < t {
            return Self.weights[i]
        }
        return Self.weights.last!
    }
}

// Minimal decodable just to read age from the profile UserDefaults blob.
private struct AgeOnlyProfile: Decodable { var age: Int? }
