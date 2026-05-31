import SwiftUI
import WhoopStore

// MARK: - StrainView
// Strain tab — shows today's strain score as a StrainCard hero at the top,
// followed by a list of recent workouts (same data as WorkoutsView).
// Data source: MetricsRepository.today for StrainCard; MetricsRepository.workouts for the list.

struct StrainView: View {
    @EnvironmentObject private var metrics: MetricsRepository

    // MARK: - State

    @State private var workouts: [Workout] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                WH.Color.background.ignoresSafeArea()

                if isLoading {
                    loadingView
                } else {
                    scrollContent
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .task {
            await reload()
        }
        .refreshable {
            await reload()
        }
    }

    // MARK: - Data loading

    private func reload() async {
        errorMessage = nil
        await metrics.refresh()
        let (from, to) = dateRange()
        workouts = await metrics.workouts(from: from, to: to)
        if isLoading { isLoading = false }
    }

    private func dateRange() -> (from: String, to: String) {
        let cal = Calendar(identifier: .gregorian)
        let utc = TimeZone(identifier: "UTC")!
        let fmt = DateFormatter()
        fmt.calendar = cal
        fmt.timeZone = utc
        fmt.dateFormat = "yyyy-MM-dd"
        let today = Date()
        let from = cal.date(byAdding: .day, value: -30, to: today) ?? today
        return (fmt.string(from: from), fmt.string(from: today))
    }

    // MARK: - Loading view

    private var loadingView: some View {
        VStack(spacing: WH.Spacing.md) {
            ProgressView()
                .tint(WH.Color.textSecondary)
            Text("Loading strain…")
                .font(WH.Font.caption)
                .foregroundStyle(WH.Color.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Scroll content

    private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WH.Spacing.lg) {

                ScreenHeader("Strain")

                // Hero strain card
                StrainCard(daily: metrics.today)
                    .padding(.horizontal, 0)

                // Workouts section
                workoutsSection

                if let err = metrics.lastError {
                    errorBanner(err)
                }

                Spacer(minLength: WH.Spacing.xl)
            }
            .padding(WH.Spacing.md)
        }
        .background(WH.Color.background)
    }

    // MARK: - Workouts section

    private var workoutsSection: some View {
        VStack(alignment: .leading, spacing: WH.Spacing.sm) {
            Text("WORKOUTS")
                .font(WH.Font.cardTitle)
                .foregroundStyle(WH.Color.textSecondary)
                .kerning(1.5)

            if workouts.isEmpty {
                emptyWorkoutsState
            } else {
                workoutList
            }
        }
    }

    private var workoutList: some View {
        VStack(spacing: 1) {
            ForEach(workouts) { workout in
                NavigationLink(destination: WorkoutDetailView(workout: workout)) {
                    workoutRow(workout)
                }
                .buttonStyle(.plain)
            }
        }
        .background(WH.Color.surface,
                    in: RoundedRectangle(cornerRadius: WH.Radius.card, style: .continuous))
    }

    private func workoutRow(_ w: Workout) -> some View {
        HStack(spacing: WH.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(rowDate(w.startTs))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(WH.Color.textPrimary)
                Text(rowTime(w.startTs))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(WH.Color.textSecondary)
            }
            .frame(width: 72, alignment: .leading)

            Text(formatDuration(w.durationS))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(WH.Color.textSecondary)
                .frame(width: 44, alignment: .leading)

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text(String(format: "%.0f", w.avgHr))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(WH.Color.textPrimary)
                    .monospacedDigit()
                Text("bpm")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(WH.Color.textSecondary)
            }
            .frame(width: 44, alignment: .trailing)

            strainBadge(w.strain)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(WH.Color.textSecondary.opacity(0.5))
        }
        .padding(.horizontal, WH.Spacing.md)
        .padding(.vertical, WH.Spacing.sm)
    }

    private func strainBadge(_ strain: Double?) -> some View {
        Group {
            if let s = strain {
                Text(String(format: "%.1f", s))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(WH.Color.strainAccent)
                    .monospacedDigit()
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(WH.Color.strainAccent.opacity(0.15),
                                in: RoundedRectangle(cornerRadius: WH.Radius.small, style: .continuous))
            } else {
                Text("—")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(WH.Color.textSecondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(WH.Color.surface2,
                                in: RoundedRectangle(cornerRadius: WH.Radius.small, style: .continuous))
            }
        }
        .frame(width: 52, alignment: .center)
    }

    // MARK: - Empty state

    private var emptyWorkoutsState: some View {
        HStack {
            Spacer()
            VStack(spacing: WH.Spacing.sm) {
                Image(systemName: "bolt.heart")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(WH.Color.textSecondary)
                Text("No workouts detected")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(WH.Color.textPrimary)
                Text("Workouts are found automatically from your HR data.")
                    .font(WH.Font.caption)
                    .foregroundStyle(WH.Color.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, WH.Spacing.lg)
            Spacer()
        }
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

    // MARK: - Formatting

    private func rowDate(_ ts: Int) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE M/d"
        return fmt.string(from: Date(timeIntervalSince1970: TimeInterval(ts)))
    }

    private func rowTime(_ ts: Int) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .none
        fmt.timeStyle = .short
        return fmt.string(from: Date(timeIntervalSince1970: TimeInterval(ts)))
    }

    private func formatDuration(_ seconds: Int) -> String {
        let totalMin = seconds / 60
        let h = totalMin / 60
        let m = totalMin % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0           { return "\(h)h" }
        return "\(m)m"
    }
}

// MARK: - Preview

#Preview("StrainView — empty") {
    StrainView()
        .environmentObject(MetricsRepository(deviceId: "preview"))
}
