import SwiftUI

struct RootTabView: View {

    @SceneStorage("selectedTab") private var selectedTab = "home"
    @State private var showLive = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem {
                        Label("Início", systemImage: "house")
                    }
                    .tag("home")

                HealthView()
                    .tabItem {
                        Label("Saúde", systemImage: "heart.text.clipboard")
                    }
                    .tag("health")

                CommunityView()
                    .tabItem {
                        Label("Comunidade", systemImage: "person.3")
                    }
                    .tag("community")

                MoreView()
                    .tabItem {
                        Label("Mais", systemImage: "line.3.horizontal")
                    }
                    .tag("more")
            }
            .preferredColorScheme(.dark)

            // Botão W circular overlay — acede ao LiveView (dispositivo BLE)
            Button {
                showLive = true
            } label: {
                ZStack {
                    Circle()
                        .fill(WH.Color.sleepPurple)
                        .frame(width: 52, height: 52)
                    Text("W")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .shadow(color: WH.Color.sleepPurple.opacity(0.4), radius: 8, x: 0, y: 4)
            .padding(.trailing, 20)
            .padding(.bottom, 8)
        }
        .sheet(isPresented: $showLive) {
            NavigationStack {
                LiveView()
            }
        }
    }
}
