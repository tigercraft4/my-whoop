import SwiftUI
import WhoopStore

// MARK: - HealthView
// Tab Saúde — métricas de saúde locais: HRV, RHR, SpO₂, sleepPerformance (7 dias).
// Sem WHOOP Age / Healthspan (cloud-only features) — apenas dados locais disponíveis.

struct HealthView: View {

    @EnvironmentObject private var metrics: MetricsRepository

    @State private var weeklyMetrics: [DailyMetric] = []
    @State private var selectedHRV: TrendPoint? = nil
    @State private var selectedRHR: TrendPoint? = nil
    @State private var selectedSleep: TrendPoint? = nil
    @State private var isLoading = false

    // MARK: - Series helpers

    private var hrvSeries: [TrendPoint] {
        let fmt = isoFormatter()
        return weeklyMetrics.compactMap { m -> TrendPoint? in
            guard let val = m.avgHrv,
                  let date = fmt.date(from: m.day) else { return nil }
            return TrendPoint(id: m.day, date: date, value: val)
        }
    }

    private var rhrSeries: [TrendPoint] {
        let fmt = isoFormatter()
        return weeklyMetrics.compactMap { m -> TrendPoint? in
            guard let val = m.restingHr,
                  let date = fmt.date(from: m.day) else { return nil }
            return TrendPoint(id: m.day, date: date, value: Double(val))
        }
    }

    private var sleepSeries: [TrendPoint] {
        let fmt = isoFormatter()
        return weeklyMetrics.compactMap { m -> TrendPoint? in
            guard let val = m.sleepPerformance ?? m.efficiency.map({ $0 * 100 }),
                  let date = fmt.date(from: m.day) else { return nil }
            return TrendPoint(id: m.day, date: date, value: val)
        }
    }

    private func isoFormatter() -> DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }

    // MARK: - Load

    private func loadWeeklyMetrics() async {
        isLoading = true
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let sevenDaysAgo = cal.date(byAdding: .day, value: -6, to: today) else {
            isLoading = false
            return
        }
        let fmt = isoFormatter()
        weeklyMetrics = await metrics.daily(fromDay: fmt.string(from: sevenDaysAgo),
                                            toDay: fmt.string(from: today))
        isLoading = false
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: WH.Spacing.lg) {

                    // HRV
                    healthSection(
                        title: "VARIABILIDADE DA FREQUÊNCIA CARDÍACA",
                        subtitle: "HRV",
                        currentValue: metrics.today?.avgHrv.map { "\(Int($0.rounded())) ms" } ?? "—",
                        accentColor: WH.Color.teal,
                        series: hrvSeries,
                        kind: .hrv,
                        selected: $selectedHRV
                    )

                    // RHR
                    healthSection(
                        title: "FREQUÊNCIA CARDÍACA EM REPOUSO",
                        subtitle: "RHR",
                        currentValue: metrics.today?.restingHr.map { "\($0) bpm" } ?? "—",
                        accentColor: WH.Color.textPrimary,
                        series: rhrSeries,
                        kind: .rhr,
                        selected: $selectedRHR
                    )

                    // SpO₂ — último valor (sem gráfico de tendência)
                    spo2Section

                    // Sleep Performance
                    healthSection(
                        title: "QUALIDADE DO SONO",
                        subtitle: "SONO",
                        currentValue: metrics.today?.sleepPerformance.map { "\(Int($0.rounded()))%" } ?? "—",
                        accentColor: WH.Color.sleepPurple,
                        series: sleepSeries,
                        kind: .sleepPerformance,
                        selected: $selectedSleep
                    )

                    Spacer(minLength: WH.Spacing.xl)
                }
                .padding(WH.Spacing.md)
            }
            .background(WH.Color.background)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("SAÚDE")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(WH.Color.textPrimary)
                        .tracking(1.5)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task { await loadWeeklyMetrics() }
    }

    // MARK: - Health section

    @ViewBuilder
    private func healthSection(title: String,
                                subtitle: String,
                                currentValue: String,
                                accentColor: Color,
                                series: [TrendPoint],
                                kind: MetricKind,
                                selected: Binding<TrendPoint?>) -> some View {
        VStack(alignment: .leading, spacing: WH.Spacing.sm) {
            Text(title)
                .font(WH.Font.cardTitle)
                .foregroundStyle(WH.Color.textSecondary)
                .tracking(0.8)
            HStack(alignment: .lastTextBaseline, spacing: WH.Spacing.xs) {
                Text(currentValue)
                    .font(WH.Font.metricLarge())
                    .foregroundStyle(accentColor)
                    .monospacedDigit()
                Text("7 dias")
                    .font(WH.Font.caption)
                    .foregroundStyle(WH.Color.textSecondary)
            }
            MetricChart(series: series, kind: kind, showAxes: false, showSelection: false, selected: selected)
                .frame(height: 80)
                .clipped()
        }
        .padding(WH.Spacing.md)
        .background(WH.Color.surface, in: RoundedRectangle(cornerRadius: WH.Radius.card, style: .continuous))
    }

    // MARK: - SpO₂ section

    private var spo2Section: some View {
        VStack(alignment: .leading, spacing: WH.Spacing.sm) {
            Text("SATURAÇÃO DE OXIGÉNIO")
                .font(WH.Font.cardTitle)
                .foregroundStyle(WH.Color.textSecondary)
                .tracking(0.8)
            Text(metrics.today?.spo2Pct.map { String(format: "%.1f%%", $0) } ?? "—")
                .font(WH.Font.metricLarge())
                .foregroundStyle(WH.Color.teal)
                .monospacedDigit()
            Text("Último valor registado")
                .font(WH.Font.caption)
                .foregroundStyle(WH.Color.textSecondary)
        }
        .padding(WH.Spacing.md)
        .background(WH.Color.surface, in: RoundedRectangle(cornerRadius: WH.Radius.card, style: .continuous))
    }
}
