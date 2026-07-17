import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @StateObject private var viewModel = WishListViewModel()

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(selectedTab: $selectedTab)
                .tabItem {
                    Label("首页", systemImage: "house")
                }
                .tag(0)

            NearbyView()
                .tabItem {
                    Label("附近", systemImage: "location")
                }
                .tag(1)

            PublishView(selectedTab: $selectedTab)
                .tabItem {
                    Label("发布", systemImage: "plus.circle.fill")
                }
                .tag(2)

            ProgressView()
                .tabItem {
                    Label("进度", systemImage: "clock.arrow.circlepath")
                }
                .tag(3)

            ProfileView()
                .tabItem {
                    Label("我的", systemImage: "person")
                }
                .tag(4)
        }
        .tint(DesignSystem.primaryBlue)
        .environmentObject(viewModel)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
