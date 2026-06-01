import SwiftUI
import WhoopStore

// MARK: - StrainCard
// WHOOP-style strain card using ZoneRingView with strainAccent color.
// Shows daily strain score 0–21 with a Training State badge
// (RESTORATIVE / OPTIMAL / OVERREACHING) driven by recovery_to_strain.json.
// Badge is omitted entirely when DailyMetric.recovery is nil (D-07).

struct StrainCard: View {

    var daily: DailyMetric?

    // MARK: - Derived values

    private var strainValue: Double {
        daily?.strain ?? 0
    }

    private var centerLabel: String {
        daily?.strain.map { String(format: "%.1f", $0) } ?? "—"
    }

    /// Training State badge label, server-first (ALG-11).
    /// Prefers DailyMetric.trainingState computed by the server (Phase 13); falls back to the
    /// bundled lookup table client-side for rows predating Phase 13 (trainingState nil).
    /// Returns nil when neither source can produce a label (recovery nil OR table fails to load).
    private var trainingStateLabel: String? {
        // Server value wins when present (Phase-13 backend parity).
        if let serverState = daily?.trainingState, !serverState.isEmpty {
            return serverState
        }
        // Fallback: client-side lookup for pre-Phase-13 rows.
        guard let recoveryFraction = daily?.recovery,
              let strain = daily?.strain else { return nil }
        // DailyMetric.recovery is stored as 0–1 fraction; lookup expects 0–100.
        return TrainingState.trainingState(recovery: recoveryFraction * 100, strain: strain)
    }

    /// Colour for the Training State badge per D-06.
    private var trainingStateBadgeColor: Color {
        switch trainingStateLabel {
        case "RESTORATIVE": return WH.Color.strainAccent      // blue (D-06)
        case "OPTIMAL":     return WH.Color.recoveryGreen
        case "OVERREACHING": return WH.Color.recoveryRed
        default:            return WH.Color.textSecondary
        }
    }

    private var ringColor: Color {
        guard let s = daily?.strain else { return WH.Color.ringTrack }
        switch s {
        case ..<10: return WH.Color.strainBlue
        case ..<18: return WH.Color.strainBlueMedium
        default:    return WH.Color.strainBlueHigh
        }
    }

    // MARK: - Body

    /// Stats for the secondary row: Recovery % and Calories
    private var recoveryStatLabel: String {
        daily?.recovery.map { "\(Int(($0 * 100).rounded()))%" } ?? "—"
    }

    private var caloriesStatLabel: String {
        daily?.totalCaloriesKcal.map { "\(Int($0)) kcal" } ?? "—"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: WH.Spacing.md) {

            // Header
            Text("STRAIN")
                .font(WH.Font.cardTitle)
                .foregroundStyle(WH.Color.textSecondary)
                .kerning(1.5)

            // Hero ring — centred
            HStack {
                Spacer()
                VStack(spacing: WH.Spacing.sm) {
                    ZoneRingView(
                        value: strainValue,
                        maxValue: 21.0,
                        color: ringColor,
                        lineWidth: 20,
                        size: 160,
                        centerLabel: centerLabel
                    )

                    // Training State badge — omitted when recovery is nil (D-07)
                    if let label = trainingStateLabel {
                        Text(label)
                            .font(WH.Font.cardTitle)
                            .foregroundStyle(trainingStateBadgeColor)
                            .kerning(1.5)
                            .animation(.easeInOut, value: label)
                    }
                }
                Spacer()
            }

            // Secondary stats row: Recovery | Calories
            HStack(spacing: 0) {
                statColumn(label: "RECOVERY", value: recoveryStatLabel)
                Divider()
                    .frame(height: 36)
                    .background(WH.Color.separator)
                statColumn(label: "CALORIES", value: caloriesStatLabel)
            }
            .padding(.top, WH.Spacing.xs)
        }
        .padding(WH.Spacing.lg)
        .background(WH.Color.surface,
                    in: RoundedRectangle(cornerRadius: WH.Radius.card, style: .continuous))
    }

    // MARK: - Sub-component

    private func statColumn(label: String, value: String) -> some View {
        VStack(spacing: WH.Spacing.xs) {
            Text(label)
                .font(WH.Font.cardTitle)
                .foregroundStyle(WH.Color.textSecondary)
                .kerning(1.2)
            Text(value)
                .font(WH.Font.metricMedium(size: 18))
                .foregroundStyle(WH.Color.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, WH.Spacing.xs)
    }
}

// MARK: - Preview

#Preview("StrainCard — examples") {
    // With recovery → badge visible
    let optimal = DailyMetric(day: "2026-05-31", totalSleepMin: 435,
                               efficiency: 0.84, deepMin: 90, remMin: 72, lightMin: 180,
                               disturbances: 3, restingHr: 56, avgHrv: 52,
                               recovery: 0.73, strain: 14.2, exerciseCount: nil)
    let overreach = DailyMetric(day: "2026-05-30", totalSleepMin: 360,
                                 efficiency: 0.72, deepMin: 60, remMin: 50, lightMin: 140,
                                 disturbances: 6, restingHr: 62, avgHrv: 38,
                                 recovery: 0.28, strain: 19.5, exerciseCount: nil)
    let restorative = DailyMetric(day: "2026-05-29", totalSleepMin: 450,
                                   efficiency: 0.92, deepMin: 110, remMin: 90, lightMin: 200,
                                   disturbances: 1, restingHr: 50, avgHrv: 72,
                                   recovery: 0.95, strain: 4.0, exerciseCount: nil)
    // Without recovery → badge omitted
    let noRecovery = DailyMetric(day: "2026-05-28", totalSleepMin: nil,
                                  efficiency: nil, deepMin: nil, remMin: nil, lightMin: nil,
                                  disturbances: nil, restingHr: nil, avgHrv: nil,
                                  recovery: nil, strain: 11.0, exerciseCount: nil,
                                  spo2Pct: nil, skinTempDevC: nil, respRateBpm: nil)

    VStack(spacing: WH.Spacing.md) {
        StrainCard(daily: restorative) // RESTORATIVE — 4.0 (blue badge)
        StrainCard(daily: optimal)     // OPTIMAL — 14.2 (green badge)
        StrainCard(daily: overreach)   // OVERREACHING — 19.5 (red badge)
        StrainCard(daily: noRecovery)  // no badge (recovery nil)
        StrainCard(daily: nil)         // placeholder — "—"
    }
    .padding()
    .background(WH.Color.background)
}
