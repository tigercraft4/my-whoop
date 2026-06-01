import SwiftUI
import WhoopStore

// MARK: - HomeView
// Ecrã principal "Início" — replica o layout do WHOOP 5.37.0.
// Header com navegação de data + 3 rings em linha (Sono/Recuperação/Esforço)
// + secções de scroll: Dados em falta, Monitores de Saúde/Stress, O meu dia,
//   Atividades de Hoje, Sono desta noite.

struct HomeView: View {

    @EnvironmentObject private var metrics: MetricsRepository
    @EnvironmentObject private var live: LiveViewModel
    @State private var selectedDate: Date = .now
    @State private var selectedDayMetric: DailyMetric? = nil

    // MARK: - Derived helpers

    private var effectiveMetric: DailyMetric? {
        selectedDate.isToday ? metrics.today : selectedDayMetric
    }

    private var strainLabel: String {
        metrics.today?.strain.map { String(format: "%.1f", $0) } ?? "—"
    }

    private var recoveryHeaderLabel: String {
        effectiveMetric?.recovery.map { "\(Int(($0 * 100).rounded()))%" } ?? "--"
    }

    private var recoveryHeaderColor: Color {
        guard let r = effectiveMetric?.recovery else { return WH.Color.textSecondary }
        return WH.Color.recoveryColor(forPercent: r * 100)
    }

    private static let dayFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM"
        f.locale = Locale(identifier: "pt_PT")
        return f
    }()

    private static let isoFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private var dateLabelText: String {
        if Calendar.current.isDateInToday(selectedDate) { return "HOJE" }
        return HomeView.dayFmt.string(from: selectedDate).uppercased()
    }

    private var hoursSinceRefresh: Int {
        guard let at = metrics.lastRefreshedAt else { return 24 }
        return max(1, Int(Date().timeIntervalSince(at) / 3600))
    }

    // MARK: - Navigation helpers

    private func navigateDate(_ days: Int) {
        let candidate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) ?? selectedDate
        // Não avançar além de hoje
        if candidate > Date() { return }
        selectedDate = candidate
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                WH.Color.background.ignoresSafeArea()

                if metrics.isRefreshing && effectiveMetric == nil {
                    loadingView
                } else {
                    VStack(spacing: 0) {
                        homeHeader
                        ScrollView {
                            VStack(alignment: .leading, spacing: WH.Spacing.md) {
                                ringsSection

                                if effectiveMetric == nil && !metrics.isRefreshing && selectedDate.isToday {
                                    dadosEmFaltaCard
                                }

                                healthMonitorsRow

                                myDaySection

                                actividadesCard

                                sonoNoiteCard

                                Spacer(minLength: WH.Spacing.xl)
                            }
                            .padding(.horizontal, WH.Spacing.md)
                        }
                        .background(WH.Color.background)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .task {
            await metrics.refresh()
        }
        .task(id: selectedDate) {
            guard !selectedDate.isToday else { return }
            let dayStr = HomeView.isoFmt.string(from: selectedDate)
            let results = await metrics.daily(fromDay: dayStr, toDay: dayStr)
            selectedDayMetric = results.first
        }
        .refreshable { await metrics.refresh() }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: WH.Spacing.md) {
            ProgressView()
                .tint(WH.Color.textSecondary)
            Text("A carregar métricas…")
                .font(WH.Font.caption)
                .foregroundStyle(WH.Color.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Header

    private var homeHeader: some View {
        HStack(alignment: .center, spacing: 0) {
            // Esquerda: perfil + strain
            HStack(spacing: WH.Spacing.xs) {
                Image(systemName: "person.circle")
                    .font(.system(size: 22))
                    .foregroundStyle(WH.Color.textSecondary)
                Image(systemName: "flame.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(WH.Color.strainAccent)
                Text(strainLabel)
                    .font(WH.Font.caption)
                    .foregroundStyle(WH.Color.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Centro: navegação de data
            HStack(spacing: WH.Spacing.sm) {
                Button {
                    navigateDate(-1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(WH.Color.textSecondary)

                Text(dateLabelText)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(WH.Color.textPrimary)

                Button {
                    navigateDate(+1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(selectedDate.isToday ? WH.Color.textSecondary.opacity(0.3) : WH.Color.textSecondary)
                .disabled(selectedDate.isToday)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            // Direita: recovery% + indicador de ligação
            HStack(spacing: WH.Spacing.xs) {
                Text(recoveryHeaderLabel)
                    .font(WH.Font.caption)
                    .foregroundStyle(recoveryHeaderColor)
                Image(systemName: live.state.connected ? "wave.3.right" : "wave.3.right.slash")
                    .font(.system(size: 13))
                    .foregroundStyle(live.state.connected ? WH.Color.recoveryGreen : WH.Color.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, WH.Spacing.md)
        .padding(.top, WH.Spacing.sm)
        .padding(.bottom, WH.Spacing.xs)
    }

    // MARK: - Rings section

    private var ringsSection: some View {
        HStack(spacing: WH.Spacing.lg) {
            ringSono
            ringRecuperacao
            ringEsforco
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, WH.Spacing.sm)
    }

    private var ringSono: some View {
        let sleepPerf = effectiveMetric?.sleepPerformance ?? 0
        let sleepPerfLabel = effectiveMetric?.sleepPerformance.map { "\(Int($0.rounded()))%" } ?? "—"
        return NavigationLink(destination: SleepView()) {
            VStack(spacing: WH.Spacing.xs) {
                ZoneRingView(value: sleepPerf,
                             maxValue: 100,
                             color: WH.Color.sleepPurple,
                             lineWidth: 8,
                             size: 90,
                             centerLabel: sleepPerfLabel)
                Text("SONO")
                    .font(WH.Font.cardTitle)
                    .foregroundStyle(WH.Color.textSecondary)
                    .tracking(0.8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(WH.Color.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }

    private var ringRecuperacao: some View {
        let recoveryVal = effectiveMetric?.recovery.map { $0 * 100 } ?? 0
        let recoveryRingColor = WH.Color.recoveryColor(forPercent: recoveryVal)
        let recoveryLabel = effectiveMetric?.recovery.map { "\(Int(($0 * 100).rounded()))%" } ?? "—"
        return NavigationLink(destination: MetricDetailView(kind: .recovery)) {
            VStack(spacing: WH.Spacing.xs) {
                ZoneRingView(value: recoveryVal,
                             maxValue: 100,
                             color: recoveryRingColor,
                             lineWidth: 8,
                             size: 90,
                             centerLabel: recoveryLabel)
                Text("RECUPERAÇÃO")
                    .font(WH.Font.cardTitle)
                    .foregroundStyle(WH.Color.textSecondary)
                    .tracking(0.8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(WH.Color.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }

    private var ringEsforco: some View {
        let strainVal = effectiveMetric?.strain ?? 0
        let strainLabel = effectiveMetric?.strain.map { String(format: "%.1f", $0) } ?? "—"
        return NavigationLink(destination: StrainView()) {
            VStack(spacing: WH.Spacing.xs) {
                ZoneRingView(value: strainVal,
                             maxValue: 21,
                             color: WH.Color.strainBlue,
                             lineWidth: 8,
                             size: 90,
                             centerLabel: strainLabel)
                Text("ESFORÇO")
                    .font(WH.Font.cardTitle)
                    .foregroundStyle(WH.Color.textSecondary)
                    .tracking(0.8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(WH.Color.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Dados em falta card

    private var dadosEmFaltaCard: some View {
        VStack(alignment: .leading, spacing: WH.Spacing.sm) {
            Text("DADOS EM FALTA")
                .font(WH.Font.cardTitle)
                .foregroundStyle(WH.Color.textSecondary)
                .tracking(0.8)
            Text("O WHOOP não recebeu dados nas últimas \(hoursSinceRefresh)h. Verifica a ligação Bluetooth.")
                .font(WH.Font.caption)
                .foregroundStyle(WH.Color.textSecondary)
        }
        .padding(WH.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WH.Color.surface2, in: RoundedRectangle(cornerRadius: WH.Radius.card, style: .continuous))
    }

    // MARK: - Monitor de Saúde + Stress

    private var healthMonitorsRow: some View {
        let hrv7dayAvgLabel = metrics.today?.avgHrv.map { "\(Int($0.rounded())) ms" } ?? "--"
        let rhr7dayAvgLabel = metrics.today?.restingHr.map { "\($0) bpm" } ?? "--"
        return HStack(spacing: WH.Spacing.sm) {
            NavigationLink(destination: HealthView()) {
                monitorCard(title: "MONITOR\nDE SAÚDE", value: hrv7dayAvgLabel, icon: "waveform.path.ecg")
            }
            .buttonStyle(.plain)

            NavigationLink(destination: HealthView()) {
                monitorCard(title: "MONITOR\nDE STRESS", value: rhr7dayAvgLabel, icon: "brain.head.profile")
            }
            .buttonStyle(.plain)
        }
    }

    private func monitorCard(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: WH.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(WH.Color.textSecondary)
            Text(title)
                .font(WH.Font.cardTitle)
                .foregroundStyle(WH.Color.textSecondary)
                .tracking(0.8)
                .lineLimit(2)
            Text(value)
                .font(WH.Font.metricMedium())
                .foregroundStyle(WH.Color.textPrimary)
                .monospacedDigit()
        }
        .padding(WH.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WH.Color.surface, in: RoundedRectangle(cornerRadius: WH.Radius.card, style: .continuous))
    }

    // MARK: - O meu dia

    private var myDaySection: some View {
        HStack {
            Text("O meu dia")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(WH.Color.textPrimary)
            Spacer()
            Button(action: {}) {
                Image(systemName: "plus")
                    .foregroundStyle(WH.Color.textSecondary)
            }
            .disabled(true)
        }
        .padding(.horizontal, WH.Spacing.md)
        .padding(.top, WH.Spacing.sm)
    }

    // MARK: - Atividades de Hoje

    private var actividadesCard: some View {
        VStack(spacing: WH.Spacing.sm) {
            Text("ATIVIDADES DE HOJE")
                .font(WH.Font.cardTitle)
                .foregroundStyle(WH.Color.textSecondary)
                .tracking(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: WH.Spacing.sm) {
                Button("ADICIONAR ATIVIDADE") {}
                    .disabled(true)
                    .font(WH.Font.caption)
                    .foregroundStyle(WH.Color.textSecondary)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(WH.Color.surface2, in: RoundedRectangle(cornerRadius: WH.Radius.chip))

                Button("INICIAR ATIVIDADE") {}
                    .disabled(true)
                    .font(WH.Font.caption)
                    .foregroundStyle(WH.Color.textSecondary)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(WH.Color.surface2, in: RoundedRectangle(cornerRadius: WH.Radius.chip))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(WH.Spacing.md)
        .background(WH.Color.surface, in: RoundedRectangle(cornerRadius: WH.Radius.card, style: .continuous))
    }

    // MARK: - Sono desta noite

    private var sonoNoiteCard: some View {
        VStack(alignment: .leading, spacing: WH.Spacing.sm) {
            Text("SONO DESTA NOITE")
                .font(WH.Font.cardTitle)
                .foregroundStyle(WH.Color.textSecondary)
                .tracking(0.8)

            if let needed = effectiveMetric?.sleepNeededMin {
                Text("Recomendado: \(formatSleepMinutes(needed))")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(WH.Color.textPrimary)
            } else {
                Text("—")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(WH.Color.textSecondary)
            }

            NavigationLink(destination: AlarmView()) {
                Text("CONFIGURAR ALARME")
                    .font(WH.Font.caption)
                    .foregroundStyle(WH.Color.sleepPurple)
            }
        }
        .padding(WH.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WH.Color.surface, in: RoundedRectangle(cornerRadius: WH.Radius.card, style: .continuous))
    }

    // MARK: - Helpers

    private func formatSleepMinutes(_ totalMin: Double) -> String {
        guard totalMin > 0 else { return "—" }
        let hours = Int(totalMin) / 60
        let mins  = Int(totalMin) % 60
        if hours > 0 && mins > 0 { return "\(hours)h \(mins)m" }
        if hours > 0              { return "\(hours)h" }
        return "\(mins)m"
    }
}

// MARK: - Date extension

private extension Date {
    var isToday: Bool { Calendar.current.isDateInToday(self) }
}

// MARK: - Preview

#Preview("Home — vazio") {
    let m = MetricsRepository(deviceId: "preview")
    let l = LiveViewModel(deviceId: "preview")
    let hk = HealthKitExporterViewModel()
    return HomeView()
        .environmentObject(m)
        .environmentObject(l)
        .environmentObject(hk)
}
