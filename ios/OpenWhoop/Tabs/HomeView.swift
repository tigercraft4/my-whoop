import SwiftUI

/// Stub de compilação — conteúdo completo criado pelo plano 18.1-02.
struct HomeView: View {
    @EnvironmentObject private var metrics: MetricsRepository
    @EnvironmentObject private var live: LiveViewModel
    @EnvironmentObject private var hkExporter: HealthKitExporterViewModel
    var body: some View {
        Text("Home")
            .foregroundStyle(WH.Color.textPrimary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(WH.Color.background)
    }
}
