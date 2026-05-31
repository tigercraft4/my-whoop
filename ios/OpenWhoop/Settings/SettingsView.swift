import SwiftUI

// MARK: - Profile model

/// Body-stat profile sent to / received from the server's /v1/profile endpoint.
/// All values stored in SI units (cm, kg); nil = not yet set.
struct Profile: Codable, Equatable {
    var heightCm: Double?
    var weightKg: Double?
    var age: Int?
    var sex: String?          // "male" | "female" | "nonbinary"

    private enum CodingKeys: String, CodingKey {
        case heightCm = "height_cm"
        case weightKg = "weight_kg"
        case age
        case sex
    }
}


// MARK: - Local persistence

private enum ProfileStorage {
    static let key = "com.openwhoop.profile.v1"

    static func load() -> Profile? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let profile = try? JSONDecoder().decode(Profile.self, from: data) else {
            return nil
        }
        return profile
    }

    static func save(_ profile: Profile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

// MARK: - SettingsView

struct SettingsView: View {
    @EnvironmentObject private var metrics: MetricsRepository
    @EnvironmentObject private var model: LiveViewModel

    // Height (metric)
    @State private var heightCmStr: String  = ""

    // Weight (metric)
    @State private var weightKgStr: String  = ""

    // Age
    @State private var ageStr: String = ""

    // Sex
    @State private var sex: String = "male"   // "male" | "female" | "nonbinary"

    // Save status
    @State private var saveStatus: SaveStatus = .idle
    @State private var isBackfilling = false

    private enum SaveStatus: Equatable {
        case idle
        case saving
        case synced
        case savedLocally
        case error(String)

        var label: String? {
            switch self {
            case .idle:                return nil
            case .saving:             return "Saving…"
            case .synced:             return "Synced ✓"
            case .savedLocally:       return "Saved locally (will sync when online)"
            case .error(let msg):     return "Error: \(msg)"
            }
        }

        var color: Color {
            switch self {
            case .idle:         return .clear
            case .saving:       return WH.Color.textSecondary
            case .synced:       return WH.Color.recoveryGreen
            case .savedLocally: return WH.Color.recoveryYellow
            case .error:        return WH.Color.recoveryRed
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                heightSection
                weightSection
                ageSection
                sexSection
                saveSection
                footerSection
            }
            .scrollContentBackground(.hidden)
            .background(WH.Color.background)
            .navigationTitle("Body Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .task { await loadProfile() }
    }

    // MARK: - Form sections

    private var heightSection: some View {
        Section {
            HStack {
                TextField("cm", text: $heightCmStr)
                    .keyboardType(.decimalPad)
                Text("cm")
                    .foregroundStyle(WH.Color.textSecondary)
            }
        } header: {
            Text("Height")
        }
    }

    private var weightSection: some View {
        Section {
            HStack {
                TextField("kg", text: $weightKgStr)
                    .keyboardType(.decimalPad)
                Text("kg")
                    .foregroundStyle(WH.Color.textSecondary)
            }
        } header: {
            Text("Weight")
        }
    }

    private var ageSection: some View {
        Section {
            HStack {
                TextField("years", text: $ageStr)
                    .keyboardType(.numberPad)
                Text("years")
                    .foregroundStyle(WH.Color.textSecondary)
            }
        } header: {
            Text("Age")
        }
    }

    private var sexSection: some View {
        Section {
            Picker("Biological Sex", selection: $sex) {
                Text("Male").tag("male")
                Text("Female").tag("female")
                Text("Non-binary").tag("nonbinary")
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Biological Sex")
        } footer: {
            Text("Used to improve calorie burn and strain estimates.")
                .font(WH.Font.caption)
                .foregroundStyle(WH.Color.textSecondary)
        }
    }

    private var saveSection: some View {
        Section {
            Button(action: { Task { await save() } }) {
                HStack {
                    Spacer()
                    if saveStatus == .saving {
                        ProgressView()
                            .tint(.white)
                            .padding(.trailing, WH.Spacing.xs)
                    }
                    Text("Save")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(saveStatus == .saving ? WH.Color.textSecondary : .white)
                    Spacer()
                }
                .frame(height: 44)
            }
            .disabled(saveStatus == .saving)
            .listRowBackground(
                RoundedRectangle(cornerRadius: WH.Radius.chip)
                    .fill(saveStatus == .saving ? WH.Color.surface2 : WH.Color.strainBlue)
            )

            if let label = saveStatus.label, saveStatus != .saving {
                HStack {
                    Spacer()
                    Text(label)
                        .font(WH.Font.caption)
                        .foregroundStyle(saveStatus.color)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }

            if isBackfilling {
                HStack {
                    Spacer()
                    Text("Recomputing calories…")
                        .font(WH.Font.caption)
                        .foregroundStyle(WH.Color.textSecondary)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
        }
    }

    private var footerSection: some View {
        Section {
            EmptyView()
        } footer: {
            Text("Height, weight, age, and sex are used server-side for calorie estimation, HRmax calculation, and strain analysis. They are stored on your personal server only.")
                .font(WH.Font.caption)
                .foregroundStyle(WH.Color.textSecondary)
        }
    }

    // MARK: - Load

    private func loadProfile() async {
        // 1. Prefill from local cache immediately.
        if let local = ProfileStorage.load() {
            applyProfile(local)
        }
        // 2. Best-effort server reconcile (server wins if local is empty).
        if let remote = await metrics.getProfile() {
            // If local is empty, apply remote unconditionally.
            // If local already had values, keep local (user may have edited since last sync).
            if ProfileStorage.load() == nil {
                applyProfile(remote)
            }
        }
    }

    private func applyProfile(_ p: Profile) {
        if let h = p.heightCm { heightCmStr = formatDouble(h, zeroIsEmpty: true) }
        if let w = p.weightKg { weightKgStr = formatDouble(w, zeroIsEmpty: true) }
        if let a = p.age { ageStr = a > 0 ? String(a) : "" }
        if let s = p.sex, !s.isEmpty { sex = s }
    }

    // MARK: - Build profile from fields

    private func buildProfile() -> Profile {
        let heightCm = Double(heightCmStr).flatMap { $0 > 0 ? $0 : nil }
        let weightKg = Double(weightKgStr).flatMap { $0 > 0 ? $0 : nil }
        let age      = Int(ageStr).flatMap { $0 > 0 ? $0 : nil }
        return Profile(heightCm: heightCm, weightKg: weightKg, age: age, sex: sex)
    }

    // MARK: - Save

    @MainActor
    private func save() async {
        let profile = buildProfile()

        // 1. Persist locally immediately.
        ProfileStorage.save(profile)
        saveStatus = .saving

        // 2. Best-effort push to server.
        let ok = await metrics.putProfile(profile)

        withAnimation {
            saveStatus = ok ? .synced : .savedLocally
        }

        // 3. On success, fire-and-forget a calorie backfill over the last 60 days so
        //    historical workouts pick up estimates derived from the new body profile.
        //    This must NOT block the save or fail it; errors are silently ignored.
        if ok {
            let cal = Calendar(identifier: .gregorian)
            let fmt = DateFormatter()
            fmt.calendar = cal
            fmt.timeZone = TimeZone(identifier: "UTC")
            fmt.dateFormat = "yyyy-MM-dd"
            let now = Date()
            let fromDay = fmt.string(from: cal.date(byAdding: .day, value: -60, to: now) ?? now)
            let toDay = fmt.string(from: now)
            isBackfilling = true
            Task {
                await metrics.backfillWorkouts(from: fromDay, to: toDay)
                await MainActor.run { isBackfilling = false }
            }
        }

        // Dismiss the status after 3 seconds.
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        withAnimation {
            if saveStatus == .synced || saveStatus == .savedLocally {
                saveStatus = .idle
            }
        }
    }

    // MARK: - Helpers

    private func formatDouble(_ v: Double, zeroIsEmpty: Bool) -> String {
        if zeroIsEmpty && v == 0 { return "" }
        // Show as integer if no fractional part, otherwise 1 decimal.
        if v.truncatingRemainder(dividingBy: 1) == 0 { return String(Int(v)) }
        return String(format: "%.1f", v)
    }
}

// MARK: - Preview

#Preview("Settings") {
    SettingsView()
        .environmentObject(MetricsRepository(deviceId: "preview"))
        .environmentObject(LiveViewModel(deviceId: "preview"))
}
