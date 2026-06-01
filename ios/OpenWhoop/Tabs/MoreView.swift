import SwiftUI

/// Stub — será expandido pelo plano 18.1-03.
struct MoreView: View {
    var body: some View {
        NavigationStack {
            Text("Mais")
                .navigationTitle("MAIS")
                .foregroundStyle(WH.Color.textPrimary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(WH.Color.background)
        }
    }
}
