import SwiftUI

/// Stub de compilação — conteúdo completo criado pelo plano 18.1-03.
struct HealthView: View {
    var body: some View {
        NavigationStack {
            Text("Saúde")
                .navigationTitle("SAÚDE")
                .foregroundStyle(WH.Color.textPrimary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(WH.Color.background)
        }
    }
}
