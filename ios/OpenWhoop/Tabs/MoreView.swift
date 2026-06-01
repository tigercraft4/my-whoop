import SwiftUI

// MARK: - MoreView
// Tab Mais — dispositivo, versão da app, e link para definições.

struct MoreView: View {

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    var body: some View {
        NavigationStack {
            List {
                Section("DISPOSITIVO") {
                    moreRow(label: "Device ID", value: AppConfig.deviceId)
                }

                Section("APP") {
                    moreRow(label: "Versão", value: "\(appVersion) (\(buildNumber))")
                    NavigationLink("Definições") {
                        SettingsView()
                    }
                    .foregroundStyle(WH.Color.textPrimary)
                }

                Section("INFORMAÇÃO") {
                    moreRow(label: "Protocolo", value: "WHOOP 5.0 BLE")
                    moreRow(label: "Desenvolvido por", value: "OpenWhoop")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(WH.Color.background)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("MAIS")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(WH.Color.textPrimary)
                        .tracking(1.5)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func moreRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(WH.Color.textPrimary)
            Spacer()
            Text(value)
                .foregroundStyle(WH.Color.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}
