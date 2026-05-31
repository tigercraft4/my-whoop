import SwiftUI
import WhoopStore

// MARK: - StrainCard
// WHOOP-style strain card using ZoneRingView with strainAccent color.
// Shows daily strain score 0–21 with zone label (RESTORATIVE/OPTIMAL/OVERREACHING).
// All fields show "—" when DailyMetric is nil.

struct StrainCard: View {

    var daily: DailyMetric?

    // MARK: - Derived values

    private var strainValue: Double {
        daily?.strain ?? 0
    }

    private var centerLabel: String {
        daily?.strain.map { String(format: "%.1f", $0) } ?? "—"
    }

    private var zoneLabel: String {
        guard let strain = daily?.strain else { return "—" }
        switch strain {
        case ..<10: return "RESTORATIVE"
        case 10...17: return "OPTIMAL"
        default: return "OVERREACHING"
        }
    }

    private var ringColor: Color {
        daily?.strain != nil ? WH.Color.strainAccent : WH.Color.ringTrack
    }

    // MARK: - Body

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

                    // Zone label below ring
                    Text(zoneLabel)
                        .font(WH.Font.cardTitle)
                        .foregroundStyle(daily?.strain != nil ? WH.Color.strainAccent : WH.Color.textSecondary)
                        .kerning(1.5)
                        .animation(.easeInOut, value: zoneLabel)
                }
                Spacer()
            }
        }
        .padding(WH.Spacing.lg)
        .background(Color.black,
                    in: RoundedRectangle(cornerRadius: WH.Radius.card, style: .continuous))
    }
}

// MARK: - Preview

#Preview("StrainCard — examples") {
    let optimal = DailyMetric(day: "2026-05-31", totalSleepMin: 435,
                               efficiency: 0.84, deepMin: 90, remMin: 72, lightMin: 180,
                               disturbances: 3, restingHr: 56, avgHrv: 52,
                               recovery: 0.73, strain: 14.2, exerciseCount: nil)
    let overreach = DailyMetric(day: "2026-05-30", totalSleepMin: 360,
                                 efficiency: 0.72, deepMin: 60, remMin: 50, lightMin: 140,
                                 disturbances: 6, restingHr: 62, avgHrv: 38,
                                 recovery: 0.28, strain: 19.5, exerciseCount: nil)
    VStack(spacing: WH.Spacing.md) {
        StrainCard(daily: optimal)     // OPTIMAL — 14.2
        StrainCard(daily: overreach)   // OVERREACHING — 19.5
        StrainCard(daily: nil)         // placeholder — "—"
    }
    .padding()
    .background(WH.Color.background)
}
