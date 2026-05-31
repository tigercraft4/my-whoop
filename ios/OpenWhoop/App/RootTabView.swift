import SwiftUI

struct RootTabView: View {

    @SceneStorage("selectedTab") private var selectedTab = "today"

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "house")
                }
                .tag("today")

            SleepView()
                .tabItem {
                    Label("Sleep", systemImage: "bed.double")
                }
                .tag("sleep")

            StrainView()
                .tabItem {
                    Label("Strain", systemImage: "bolt.heart")
                }
                .tag("strain")

            TrendsView()
                .tabItem {
                    Label("Trends", systemImage: "chart.xyaxis.line")
                }
                .tag("trends")

            NavigationStack {
                LiveView()
            }
            .tabItem {
                Label("Device", systemImage: "wave.3.right")
            }
            .tag("device")
        }
        .preferredColorScheme(.dark)
    }
}
