import SwiftUI

/// Stub — "Em breve" placeholder para Comunidade.
struct CommunityView: View {
    var body: some View {
        NavigationStack {
            Text("Em breve")
                .font(WH.Font.metricMedium())
                .foregroundStyle(WH.Color.textSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(WH.Color.background)
                .navigationTitle("COMUNIDADE")
        }
    }
}
