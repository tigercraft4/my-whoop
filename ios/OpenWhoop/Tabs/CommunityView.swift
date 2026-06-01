import SwiftUI

// MARK: - CommunityView
// Placeholder "Em breve" para a funcionalidade de Comunidade (cloud-only, pós-v4.0).

struct CommunityView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: WH.Spacing.md) {
                Spacer()
                Image(systemName: "person.3")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(WH.Color.textSecondary.opacity(0.5))
                Text("Em breve")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(WH.Color.textPrimary)
                Text("A funcionalidade de Comunidade estará disponível numa versão futura.")
                    .font(WH.Font.caption)
                    .foregroundStyle(WH.Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, WH.Spacing.xl)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(WH.Color.background)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("COMUNIDADE")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(WH.Color.textPrimary)
                        .tracking(1.5)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
