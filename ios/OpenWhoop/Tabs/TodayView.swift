import SwiftUI
import HealthKit

// MARK: - TodayView
// The command-centre "Today" tab. Renders server-cached recovery/strain/sleep/HRV/RHR
// metrics pulled from MetricsRepository.
// Tapping any metric card → MetricDetailView (full history, range selector).

struct TodayView: View {
    @EnvironmentObject private var metrics:    MetricsRepository
    @EnvironmentObject private var live:       LiveViewModel
    @EnvironmentObject private var hkExporter: HealthKitExporterViewModel

    // One-time "Health not connected" banner state
    @State private var showHealthBanner = false
    @AppStorage("hk.authDeniedShown") private var authDeniedShown = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                WH.Color.background.ignoresSafeArea()

                Group {
                    if metrics.isRefreshing && metrics.today == nil && metrics.lastNight == nil {
                        loadingView
                    } else {
                        scrollContent
                    }
                }

                // Subtle "Health not connected" banner — shown once on denial
                if showHealthBanner {
                    healthNotConnectedBanner
                        .padding(.top, WH.Spacing.sm)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(1)
                }
            }
            // Hide the system nav bar on the root so the custom ScreenHeader sits tight
            // below the status bar/Dynamic Island. Pushed detail views manage their own bars.
            .toolbar(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .task {
            await metrics.refresh()
            // Lazy HealthKit auth — only when there is data to export (D-03)
            guard metrics.today != nil else { return }
            if let store = metrics.whoopStore {
                await hkExporter.requestAuthorizationAndExport(
                    whoopStore: store,
                    deviceId: AppConfig.deviceId
                )
            }
            // Show one-time "Health not connected" banner if denied and not previously shown
            if hkExporter.authDenied && !authDeniedShown {
                withAnimation { showHealthBanner = true }
                authDeniedShown = true
            }
        }
        .refreshable { await metrics.refresh() }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: WH.Spacing.md) {
            ProgressView()
                .tint(WH.Color.textSecondary)
            Text("Loading metrics…")
                .font(WH.Font.caption)
                .foregroundStyle(WH.Color.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Main scroll content

    private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WH.Spacing.lg) {

                // Custom tight header (replaces the hidden system large-title nav bar)
                ScreenHeader("Today")

                // Hero recovery ring (tappable → recovery history)
                heroSection

                // Strain card → strain history
                NavigationLink(destination: MetricDetailView(kind: .strain)) {
                    strainCard
                }
                .buttonStyle(.plain)

                // Sleep card → sleep duration history
                NavigationLink(destination: MetricDetailView(kind: .sleepDuration)) {
                    sleepCard
                }
                .buttonStyle(.plain)

                // HRV + RHR cards (half width each)
                hrvAndRhrRow

                if let err = metrics.lastError {
                    errorBanner(err)
                }

                if metrics.today == nil && metrics.lastNight == nil && !metrics.isRefreshing {
                    emptyState
                }

                strapNote
                syncFooter

                Spacer(minLength: WH.Spacing.xl)
            }
            .padding(WH.Spacing.md)
        }
        .background(WH.Color.background)
    }

    // MARK: - Hero section (recovery card → recovery history)

    private var heroSection: some View {
        VStack(spacing: WH.Spacing.xs) {
            NavigationLink(destination: MetricDetailView(kind: .recovery)) {
                RecoveryCard(daily: metrics.today)
            }
            .buttonStyle(.plain)
            .padding(.top, WH.Spacing.sm)

            // Staleness label — only when lastRefreshedAt > 6h (D-06: hero section only, D-07: no other cards)
            if let at = metrics.lastRefreshedAt,
               Date().timeIntervalSince(at) > StalenessPolicy.staleAfterSeconds {
                Text("Updated \(Int(Date().timeIntervalSince(at) / 3600))h ago")
                    .font(WH.Font.caption)
                    .foregroundStyle(WH.Color.textSecondary)
            }
        }
    }

    // MARK: - Strain card

    private var strainCard: some View {
        let value: String = {
            guard let s = metrics.today?.strain else { return "—" }
            return String(format: "%.1f", s)
        }()
        let hasStrain = metrics.today?.strain != nil
        return MetricCard(title: "Day Strain",
                          value: value,
                          unit: hasStrain ? "/ 21" : nil,
                          accentColor: hasStrain ? WH.Color.strainBlue : WH.Color.textSecondary)
    }

    // MARK: - Sleep card

    private var sleepCard: some View {
        let sleepMin: Double? = {
            if let m = metrics.today?.totalSleepMin, m > 0 { return m }
            if let s = metrics.lastNight {
                let d = Double(s.endTs - s.startTs) / 60
                return d > 0 ? d : nil
            }
            return nil
        }()

        let efficiency: Double? = {
            guard sleepMin != nil else { return nil }
            if let e = metrics.today?.efficiency, e > 0 { return e }
            if let e = metrics.lastNight?.efficiency, e > 0 { return e }
            return nil
        }()

        return VStack(alignment: .leading, spacing: WH.Spacing.sm) {
            HStack {
                Text("LAST NIGHT")
                    .font(WH.Font.cardTitle)
                    .foregroundStyle(WH.Color.textSecondary)
                    .tracking(1.2)
                Spacer()
            }

            if let min = sleepMin {
                HStack(alignment: .lastTextBaseline, spacing: WH.Spacing.sm) {
                    Text(formatSleepMinutes(min))
                        .font(WH.Font.metricLarge())
                        .foregroundStyle(WH.Color.textPrimary)
                        .monospacedDigit()

                    if let eff = efficiency {
                        Text("·  \(Int((eff * 100).rounded()))% efficiency")
                            .font(WH.Font.unit)
                            .foregroundStyle(WH.Color.textSecondary)
                    }

                    Spacer(minLength: 0)
                }
            } else {
                Text("No sleep data")
                    .font(WH.Font.metricMedium())
                    .foregroundStyle(WH.Color.textSecondary)
            }
        }
        .padding(WH.Spacing.md)
        .background(WH.Color.surface,
                    in: RoundedRectangle(cornerRadius: WH.Radius.card, style: .continuous))
    }

    // MARK: - HRV + RHR row

    private var hrvAndRhrRow: some View {
        HStack(spacing: WH.Spacing.sm) {
            NavigationLink(destination: MetricDetailView(kind: .hrv)) {
                hrvCard.frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)

            NavigationLink(destination: MetricDetailView(kind: .rhr)) {
                rhrCard.frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
    }

    private var hrvCard: some View {
        let hrv = metrics.today?.avgHrv ?? metrics.lastNight?.avgHrv
        let value = hrv.map { String(format: "%.0f", $0) } ?? "—"
        let accent: Color = hrv != nil ? WH.Color.recoveryGreen : WH.Color.textSecondary
        return MetricCard(title: "HRV",
                          value: value,
                          unit: hrv != nil ? "ms" : nil,
                          accentColor: accent)
    }

    private var rhrCard: some View {
        let rhr = metrics.today?.restingHr ?? metrics.lastNight?.restingHr
        let value = rhr.map { "\($0)" } ?? "—"
        let accent: Color = rhr != nil ? WH.Color.textPrimary : WH.Color.textSecondary
        return MetricCard(title: "Resting HR",
                          value: value,
                          unit: rhr != nil ? "bpm" : nil,
                          accentColor: accent)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: WH.Spacing.sm) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(WH.Color.textSecondary)
                Text("No metrics yet")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(WH.Color.textPrimary)
                Text("Pull down to refresh")
                    .font(WH.Font.caption)
                    .foregroundStyle(WH.Color.textSecondary)
            }
            .padding(.vertical, WH.Spacing.xxl)
            Spacer()
        }
    }

    // MARK: - Live strap status row (HR + battery when connected; caption when not)

    /// Compact pill showing a single live reading (HR or battery).
    private func liveChip(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: WH.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(WH.Color.textPrimary)
                .monospacedDigit()
        }
        .padding(.horizontal, WH.Spacing.sm)
        .padding(.vertical, WH.Spacing.xs)
        .background(WH.Color.surface2,
                    in: Capsule())
    }

    /// Shows live HR + battery pills when connected; otherwise shows the connect caption.
    private var strapNote: some View {
        Group {
            if live.state.connected, let hr = live.state.heartRate {
                HStack(spacing: WH.Spacing.sm) {
                    liveChip(icon: "heart.fill",
                             label: "\(hr) BPM LIVE",
                             color: WH.Color.recoveryRed)
                    if let bat = live.state.batteryPct {
                        let pct = Int(bat.rounded())
                        let batColor: Color = pct > 30 ? WH.Color.recoveryGreen
                                                       : WH.Color.recoveryYellow
                        let batIcon = pct > 70 ? "battery.100" :
                                      pct > 30 ? "battery.50"  : "battery.25"
                        liveChip(icon: batIcon,
                                 label: "\(pct)%",
                                 color: batColor)
                    }
                    Spacer()
                }
            } else {
                HStack(spacing: WH.Spacing.xs) {
                    Image(systemName: "wave.3.right")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(WH.Color.textSecondary.opacity(0.5))
                    Text("Live HR & battery appear when your strap is connected (Device tab)")
                        .font(WH.Font.caption)
                        .foregroundStyle(WH.Color.textSecondary.opacity(0.5))
                        .lineLimit(2)
                }
            }
        }
    }

    // MARK: - Sync footer

    private var syncFooter: some View {
        HStack {
            if metrics.isRefreshing {
                HStack(spacing: WH.Spacing.xs) {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(WH.Color.textSecondary)
                    Text("Updating…")
                        .font(WH.Font.caption)
                        .foregroundStyle(WH.Color.textSecondary)
                }
            } else if let at = metrics.lastRefreshedAt {
                Text("Updated \(relativeTime(from: at))")
                    .font(WH.Font.caption)
                    .foregroundStyle(WH.Color.textSecondary)
            }
            Spacer()
        }
    }

    // MARK: - Health Not Connected Banner (one-time, non-blocking)

    private var healthNotConnectedBanner: some View {
        HStack(spacing: WH.Spacing.sm) {
            Image(systemName: "heart.slash")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(WH.Color.textSecondary)
            Text("Health not connected")
                .font(WH.Font.caption)
                .foregroundStyle(WH.Color.textSecondary)
            Spacer()
            Button {
                // Attempt Apple Health deep link; fall back to Settings
                if let healthURL = URL(string: "x-apple-health://"),
                   UIApplication.shared.canOpenURL(healthURL) {
                    UIApplication.shared.open(healthURL)
                } else if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            } label: {
                Text("Open")
                    .font(WH.Font.caption)
                    .foregroundStyle(WH.Color.textSecondary)
                    .underline()
            }
            Button {
                withAnimation { showHealthBanner = false }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(WH.Color.textSecondary)
            }
        }
        .padding(.horizontal, WH.Spacing.md)
        .padding(.vertical, WH.Spacing.xs)
        .background(WH.Color.surface2,
                    in: Capsule())
        .padding(.horizontal, WH.Spacing.md)
    }

    // MARK: - Error banner

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: WH.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(WH.Color.recoveryYellow)
            Text(message)
                .font(WH.Font.caption)
                .foregroundStyle(WH.Color.textSecondary)
                .lineLimit(2)
            Spacer()
        }
        .padding(WH.Spacing.sm)
        .background(WH.Color.surface2,
                    in: RoundedRectangle(cornerRadius: WH.Radius.chip, style: .continuous))
    }

    // MARK: - Formatting helpers

    private func formatSleepMinutes(_ totalMin: Double) -> String {
        guard totalMin > 0 else { return "—" }
        let hours = Int(totalMin) / 60
        let mins  = Int(totalMin) % 60
        if hours > 0 && mins > 0 { return "\(hours)h \(mins)m" }
        if hours > 0              { return "\(hours)h" }
        return "\(mins)m"
    }

    private func relativeTime(from date: Date) -> String {
        let elapsed = Int(-date.timeIntervalSinceNow)
        switch elapsed {
        case ..<5:   return "just now"
        case ..<60:  return "\(elapsed)s ago"
        case ..<3600:
            let m = elapsed / 60
            return "\(m)m ago"
        default:
            let h = elapsed / 3600
            return "\(h)h ago"
        }
    }
}

// MARK: - Preview

#Preview("Today — empty (cold start)") {
    TodayView()
        .environmentObject(MetricsRepository(deviceId: "preview"))
}

#Preview("Today — design gallery reference") {
    DesignGallery()
}
