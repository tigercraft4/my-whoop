import SwiftUI
import Charts
import WhoopStore

// MARK: - MetricKind
// Enum that drives chart style, color, data extraction, and formatting for every
// supported metric. Adding a new metric only requires a new case here.

enum MetricKind: String, Identifiable {
    case recovery
    case hrv
    case rhr
    case strain
    case sleepDuration
    /// Sleep performance (0–100%). Sourced from DailyMetric.efficiency (stored 0–1 on server).
    /// Replaces sleepDuration as the primary sleep metric in the Trends cards loop (D-09/D-10/D-11).
    case sleepPerformance
    /// Blood oxygen saturation (%). Daily aggregate from sleep session.
    /// Nil when PROTO-11 stream is not yet verified for this device.
    case spo2
    /// Skin temperature deviation from baseline (°C). Daily aggregate from sleep session.
    /// Nil when PROTO-11 stream is not yet verified for this device.
    case skinTemp
    /// High-resolution 1 Hz HR stream. Stream-backed — NOT a daily aggregate.
    /// Excluded from the daily Trends card loop; has its own HeartRateDetailView.
    case rawHR

    var id: String { rawValue }

    /// The ordered list of daily-aggregate metrics shown in the Trends cards loop.
    /// rawHR is intentionally excluded — it is stream-backed, not daily.
    /// sleepPerformance replaces sleepDuration as the primary sleep metric (D-11).
    /// spo2 and skinTemp are included; they return nil when PROTO-11 stream is unavailable.
    static let dailyCases: [MetricKind] = [.recovery, .hrv, .rhr, .strain, .sleepPerformance, .spo2, .skinTemp]

    // MARK: Display

    var title: String {
        switch self {
        case .recovery:         return "Recovery"
        case .hrv:              return "HRV"
        case .rhr:              return "RHR"
        case .strain:           return "Day Strain"
        case .sleepDuration:    return "Sleep"
        case .sleepPerformance: return "Sleep Performance"
        case .spo2:             return "Blood Oxygen"
        case .skinTemp:         return "Skin Temp"
        case .rawHR:            return "Heart Rate"
        }
    }

    var unit: String {
        switch self {
        case .recovery:         return "%"
        case .hrv:              return "ms"
        case .rhr:              return "bpm"
        case .strain:           return "/ 21"
        case .sleepDuration:    return "hr"
        case .sleepPerformance: return "%"
        case .spo2:             return "%"
        case .skinTemp:         return "°C"
        case .rawHR:            return "bpm"
        }
    }

    // MARK: Color

    var color: Color {
        switch self {
        case .recovery:         return WH.Color.recoveryGreen   // band-colored at runtime
        case .hrv:              return WH.Color.teal
        case .rhr:              return WH.Color.textPrimary
        case .strain:           return WH.Color.strainBlue
        case .sleepDuration:    return WH.Color.sleepPurple
        case .sleepPerformance: return WH.Color.sleepPurple
        case .spo2:             return WH.Color.teal             // cyan — distinct from other metrics
        case .skinTemp:         return SwiftUI.Color(hex: "#FF9F0A")  // warm orange — deviation signal
        case .rawHR:            return WH.Color.recoveryRed
        }
    }

    // MARK: Mark type

    enum MarkType { case line, bar }

    var markType: MarkType {
        switch self {
        case .recovery, .hrv, .rhr, .spo2, .skinTemp, .rawHR: return .line
        case .strain, .sleepDuration, .sleepPerformance: return .bar
        }
    }

    // MARK: Fixed y-domain (nil = auto)

    var fixedYDomain: ClosedRange<Double>? {
        switch self {
        case .recovery:         return 0...100
        case .strain:           return 0...21
        case .sleepPerformance: return 0...100
        case .spo2:             return 90...100  // physiologically relevant SpO2 range
        case .skinTemp:         return nil       // auto-scale — deviation range varies
        case .rawHR:            return nil       // auto-scaled — HR range varies widely
        default:                return nil
        }
    }

    // MARK: Recovery banding

    /// Whether to draw the green/yellow/red zone bands behind the chart.
    var hasRecoveryBands: Bool { self == .recovery }

    /// Whether this kind is stream-backed (not a daily aggregate).
    /// Stream-backed kinds must not be passed to value(from:).
    var isStreamBacked: Bool { self == .rawHR }

    // MARK: Value formatting

    func format(_ value: Double) -> String {
        switch self {
        case .recovery:         return String(format: "%.0f%%", value)
        case .hrv:              return String(format: "%.0f ms", value)
        case .rhr:              return String(format: "%.0f bpm", value)
        case .strain:           return String(format: "%.1f", value)
        case .sleepDuration:    return String(format: "%.1f hr", value)
        case .sleepPerformance: return String(format: "%.0f%%", value)
        case .spo2:             return String(format: "%.0f%%", value)
        case .skinTemp:         return String(format: "%+.1f °C", value)  // show sign for deviation
        case .rawHR:            return String(format: "%.0f bpm", value)
        }
    }

    /// Short value-only label (no unit) for axis labels and stat strip.
    func formatShort(_ value: Double) -> String {
        switch self {
        case .recovery:         return String(format: "%.0f", value)
        case .hrv:              return String(format: "%.0f", value)
        case .rhr:              return String(format: "%.0f", value)
        case .strain:           return String(format: "%.1f", value)
        case .sleepDuration:    return String(format: "%.1f", value)
        case .sleepPerformance: return String(format: "%.0f", value)
        case .spo2:             return String(format: "%.0f", value)
        case .skinTemp:         return String(format: "%+.1f", value)
        case .rawHR:            return String(format: "%.0f", value)
        }
    }

    // MARK: Data extraction from DailyMetric

    /// Returns nil for stream-backed kinds (rawHR) so they are never accidentally
    /// included in the daily Trends card loop. Call-sites on .rawHR should use hrSeries instead.
    func value(from metric: DailyMetric) -> Double? {
        guard !isStreamBacked else { return nil }
        switch self {
        case .recovery:
            guard let r = metric.recovery else { return nil }
            return r * 100    // stored as 0–1 fraction → display 0–100
        case .hrv:
            return metric.avgHrv
        case .rhr:
            return metric.restingHr.map { Double($0) }
        case .strain:
            return metric.strain
        case .sleepDuration:
            guard let m = metric.totalSleepMin, m > 0 else { return nil }
            return m / 60.0   // minutes → hours
        case .sleepPerformance:
            // ALG-10: prefer the server-computed sleep-performance score (0–100); fall back to
            // efficiency × 100 for rows predating Phase 13 (sleepPerformance nil) for retrocompat.
            return metric.sleepPerformance ?? metric.efficiency.map { $0 * 100 }
        case .spo2:
            return metric.spo2Pct      // nil when PROTO-11 stream not verified
        case .skinTemp:
            return metric.skinTempDevC // nil when PROTO-11 stream not verified; shown as "—"
        case .rawHR:
            return nil   // unreachable: guarded by isStreamBacked above
        }
    }
}
