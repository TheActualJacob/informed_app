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
    @State private var pendingStoryId: String? = nil

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

            DailyDashboardView(pendingStoryId: $pendingStoryId)
                .tabItem {
                    Image(systemName: "sun.max.fill")
                    Text("Daily")
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
        // Handles universal links set directly on reelManager — works for both
        // cold launches (before onAppear registers the NotificationCenter observer)
        // and foreground launches.
        .onChange(of: reelManager.pendingSharedLinkId) { _, uniqueId in
            guard let uniqueId else { return }
            reelManager.pendingSharedLinkId = nil
            sharedLinkUniqueId = uniqueId
            // Delay sheet slightly to avoid racing with any ongoing view transitions
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                showSharedLinkSheet = true
            }
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
            // Drain any universal link that arrived before this view was mounted.
            // onChange only fires on changes AFTER the observer subscribes, so cold-
            // launch links set on reelManager before ContentView was in the hierarchy
            // are consumed here instead.
            if let uniqueId = reelManager.pendingSharedLinkId {
                reelManager.pendingSharedLinkId = nil
                sharedLinkUniqueId = uniqueId
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showSharedLinkSheet = true
                }
            }

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

            // Navigate to Daily tab and open a specific story (from push notification)
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("OpenStory"),
                object: nil,
                queue: .main
            ) { notification in
                guard let storyId = notification.userInfo?["storyId"] as? String else { return }
                DispatchQueue.main.async {
                    selectedTab = 1
                    pendingStoryId = storyId
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
