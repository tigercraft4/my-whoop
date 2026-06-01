import SwiftUI
import WhoopStore

// MARK: - RecoveryCard
// WHOOP-style recovery card for the Today tab hero section.
// Shows a ZoneRingView coloured by recovery zone (green/yellow/red),
// plus a horizontal stats row for HRV, RHR, and sleep performance.
// All fields show "—" when DailyMetric is nil.

struct RecoveryCard: View {

    var daily: DailyMetric?

    // MARK: - Derived values

    private var recoveryPct: Double? {
        daily?.recovery.map { $0 * 100 }
    }

    private var ringColor: Color {
        guard let pct = recoveryPct else { return WH.Color.ringTrack }
        return WH.Color.recoveryColor(forPercent: pct)
    }

    private var scoreLabel: String {
        guard let pct = recoveryPct else { return "—" }
        return "\(Int(pct.rounded()))"
    }

    private var hrvLabel: String {
        daily?.avgHrv.map { String(format: "%.0f ms", $0) } ?? "—"
    }

    private var rhrLabel: String {
        daily?.restingHr.map { "\($0) bpm" } ?? "—"
    }

    private var sleepLabel: String {
        // D-05: Read sleepPerformance (ALG-10, composite 0–100) — NOT efficiency (raw 0.0–1.0)
        daily?.sleepPerformance.map { "\(Int($0.rounded()))%" } ?? "—"
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: WH.Spacing.md) {

            // Header
            Text("RECOVERY")
                .font(WH.Font.cardTitle)
                .foregroundStyle(WH.Color.textSecondary)
                .kerning(1.5)

            // Hero ring — centred
            HStack {
                Spacer()
                ZoneRingView(
                    value: recoveryPct ?? 0,
                    maxValue: 100,
                    color: ringColor,
                    lineWidth: 20,
                    size: 160,
                    centerLabel: scoreLabel
                )
                Spacer()
            }

            // Stats row
            HStack(spacing: 0) {
                statColumn(label: "HRV", value: hrvLabel)
                Divider()
                    .frame(height: 36)
                    .background(WH.Color.separator)
                statColumn(label: "RHR", value: rhrLabel)
                Divider()
                    .frame(height: 36)
                    .background(WH.Color.separator)
                statColumn(label: "SLEEP", value: sleepLabel)
            }
            .padding(.top, WH.Spacing.xs)
        }
        .padding(WH.Spacing.lg)
        .background(Color.black,
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

#Preview("RecoveryCard — green zone") {
    let daily = DailyMetric(day: "2026-05-31", totalSleepMin: 435,
                             efficiency: 0.84, deepMin: 90, remMin: 72, lightMin: 180,
                             disturbances: 3, restingHr: 56, avgHrv: 52,
                             recovery: 0.73, strain: 14.2, exerciseCount: nil,
                             respRateBpm: 15.8, sleepPerformance: 84.0)
    VStack {
        RecoveryCard(daily: daily)
        RecoveryCard(daily: nil) // placeholder state
    }
    .padding()
    .background(WH.Color.background)
}
