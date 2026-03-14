import SwiftUI
import ActivityKit

// MARK: - Main Content View

struct ContentView: View {
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var reelManager: SharedReelManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var selectedTab: Int = 0
    @State private var sharedLinkUniqueId: String = ""
    @State private var showSharedLinkSheet: Bool = false

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .tag(0)

            FeedView()
                .tabItem {
                    Image(systemName: "photo.on.rectangle.angled")
                    Text("Discover")
                }
                .tag(1)

            SharedReelsView()
                .tabItem {
                    Image(systemName: "square.and.arrow.down.fill")
                    Text("My Reels")
                }
                .tag(2)

            AccountView()
                .tabItem {
                    Image(systemName: subscriptionManager.isPro ? "star.circle.fill" : "person.circle.fill")
                    Text(subscriptionManager.isPro ? "+Account" : "Account")
                }
                .tag(3)
        }
        .accentColor(.brandBlue)
        .sheet(isPresented: $subscriptionManager.showPaywall) {
            PaywallView(limitType: subscriptionManager.paywallLimitType)
                .environmentObject(subscriptionManager)
        }
        .sheet(isPresented: $showSharedLinkSheet) {
            SharedFactCheckSheet(uniqueId: sharedLinkUniqueId)
                .environmentObject(reelManager)
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            if newValue == 2 {
                // Sync so newly completed reels appear immediately on tab switch
                Task {
                    await SharedReelManager.shared.syncHistoryFromBackend()
                }
            }
        }
        .onAppear {
            // Navigate to My Reels (from notifications / Live Activity taps)
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("NavigateToMyReels"),
                object: nil,
                queue: .main
            ) { notification in
                let submissionId = notification.userInfo?["submissionId"] as? String
                DispatchQueue.main.async {
                    selectedTab = 2
                    if let submissionId {
                        reelManager.pendingDeepLinkId = submissionId
                    }
                }
            }

            // Open a specific fact-check detail view directly
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("ShowFactCheckDetail"),
                object: nil,
                queue: .main
            ) { notification in
                let item = notification.userInfo?["factCheckItem"] as? FactCheckItem
                DispatchQueue.main.async {
                    selectedTab = 2
                    if let item {
                        reelManager.pendingDeepLinkItem = item
                    }
                }
            }

            // Open a shared fact check via universal link (informed-app.com/share/{id})
            // Navigates to the Discover tab and presents the result as a sheet
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("ShowSharedFactCheck"),
                object: nil,
                queue: .main
            ) { notification in
                guard let uniqueId = notification.userInfo?["uniqueId"] as? String else { return }
                DispatchQueue.main.async {
                    selectedTab = 1
                    sharedLinkUniqueId = uniqueId
                    showSharedLinkSheet = true
                }
            }
        }
    }

}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(UserManager())
            .environmentObject(NotificationManager.shared)
            .environmentObject(SharedReelManager.shared)
            .environmentObject(SubscriptionManager.shared)
    }
}
