import SwiftUI
import WhoopStore

// MARK: - SleepCard
// WHOOP-style sleep card for the Sleep tab.
// Shows HOURS OF SLEEP, SLEEP PERFORMANCE, and SLEEP NEEDED from DailyMetric,
// followed by the HypnogramView stage bar when stagesJSON is available.
// All fields show "—" when data is nil.

struct SleepCard: View {

    var session: CachedSleepSession?
    var daily: DailyMetric?

    // MARK: - Derived values

    private var hoursSleepLabel: String {
        if let m = daily?.totalSleepMin, m > 0 {
            return String(format: "%.1f hr", m / 60)
        }
        // Fallback: derive from session timestamps (total time in bed — approximate,
        // includes time awake in bed; prefix "~" to signal imprecision to user)
        if let s = session {
            let totalMin = Double(s.endTs - s.startTs) / 60
            if totalMin > 0 { return String(format: "~%.1f hr", totalMin / 60) }
        }
        return "—"
    }

    private var sleepPerformanceLabel: String {
        // D-04: Read sleepPerformance (ALG-10, composite 0–100) — NOT efficiency (raw 0.0–1.0)
        if let score = daily?.sleepPerformance, score > 0 {
            return "\(Int(score.rounded()))%"
        }
        return "—"
    }

    private var sleepNeededLabel: String {
        // D-01: Show sleepNeededMin (ALG-12) as 3rd stat column
        if let m = daily?.sleepNeededMin, m > 0 {
            return formatMinutes(m)
        }
        return "—"
    }

    // MARK: - Helpers

    private func formatMinutes(_ totalMin: Double) -> String {
        guard totalMin > 0 else { return "—" }
        let hours = Int(totalMin) / 60
        let mins  = Int(totalMin) % 60
        if hours > 0 && mins > 0 { return "\(hours)h \(mins)m" }
        if hours > 0              { return "\(hours)h" }
        return "\(mins)m"
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: WH.Spacing.md) {

            // Header
            Text("SLEEP")
                .font(WH.Font.cardTitle)
                .foregroundStyle(WH.Color.textSecondary)
                .kerning(1.5)

            // Stats row: Hours of Sleep | Sleep Performance | Sleep Needed
            HStack(spacing: 0) {
                statColumn(label: "HOURS OF SLEEP", value: hoursSleepLabel)
                Divider()
                    .frame(height: 40)
                    .background(WH.Color.separator)
                statColumn(label: "SLEEP PERFORMANCE", value: sleepPerformanceLabel)
                Divider()
                    .frame(height: 40)
                    .background(WH.Color.separator)
                statColumn(label: "SLEEP NEEDED", value: sleepNeededLabel)
            }

            Divider()
                .background(WH.Color.separator)

            // Hypnogram or placeholder
            if let s = session {
                HypnogramView(session: s)
            } else {
                HStack(spacing: WH.Spacing.sm) {
                    Image(systemName: "moon.zzz")
                        .font(.system(size: 16, weight: .light))
                        .foregroundStyle(WH.Color.textSecondary)
                    Text("No sleep data")
                        .font(WH.Font.caption)
                        .foregroundStyle(WH.Color.textSecondary)
                }
                .padding(.vertical, WH.Spacing.sm)
            }
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
                .kerning(1.0)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
                .lineLimit(2)
            Text(value)
                .font(WH.Font.metricMedium(size: 20))
                .foregroundStyle(WH.Color.textPrimary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, WH.Spacing.xs)
    }
}

// MARK: - Preview

#Preview("SleepCard — no session") {
    SleepCard(session: nil, daily: nil)
        .padding()
        .background(WH.Color.background)
}

#Preview("SleepCard — with DailyMetric only") {
    let daily = DailyMetric(day: "2026-05-31", totalSleepMin: 452,
                             efficiency: 0.87, deepMin: 88, remMin: 70, lightMin: 192,
                             disturbances: 2, restingHr: 54, avgHrv: 61,
                             recovery: 0.78, strain: nil, exerciseCount: nil,
                             sleepPerformance: 82.0, sleepNeededMin: 450.0)
    SleepCard(session: nil, daily: daily)
        .padding()
        .background(WH.Color.background)
}
