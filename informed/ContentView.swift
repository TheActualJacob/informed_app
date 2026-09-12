import SwiftUI
import ActivityKit

// MARK: - Main Content View

struct ContentView: View {
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var reelManager: SharedReelManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var notificationManager: NotificationManager
    @State private var selectedTab: Int = 0
    @State private var sharedLinkUniqueId: String = ""
    @State private var showSharedLinkSheet: Bool = false
    @State private var sharedLinkSheetOnScreen: Bool = false
    @State private var sharedLinkPresentAttempts: Int = 0
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

            // DailyDashboardView(pendingStoryId: $pendingStoryId)
            //     .tabItem {
            //         Image(systemName: "sun.max.fill")
            //         Text("Daily")
            //     }
            //     .tag(1)
            DiscoverFeedView()
                .tabItem {
                    Image(systemName: "safari.fill")
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
                .onAppear { sharedLinkSheetOnScreen = true }
                .onDisappear { sharedLinkSheetOnScreen = false }
        }
        // Shared fact-check links (Universal Link, factcheckapp://open, or a deferred
        // match after install) queue on reelManager.pendingSharedLinkId and are presented
        // here once nothing else covers the screen — the tutorial, the welcome/pro
        // screen, the notification primer or the paywall. SwiftUI silently drops a sheet
        // requested while another presentation is up, so every gate is re-checked.
        .onChange(of: reelManager.pendingSharedLinkId) { _, _ in
            presentPendingSharedLinkIfReady()
        }
        .onChange(of: userManager.needsTutorial) { _, _ in
            presentPendingSharedLinkIfReady(delay: 0.6)
        }
        .onChange(of: userManager.isNewUser) { _, _ in
            presentPendingSharedLinkIfReady(delay: 0.6)
        }
        .onChange(of: notificationManager.showPermissionPrimer) { _, _ in
            presentPendingSharedLinkIfReady(delay: 0.6)
        }
        .onChange(of: notificationManager.permissionPrimerOnScreen) { _, _ in
            presentPendingSharedLinkIfReady(delay: 0.6)
        }
        .onChange(of: subscriptionManager.showPaywall) { _, _ in
            presentPendingSharedLinkIfReady(delay: 0.6)
        }
        .onChange(of: showSharedLinkSheet) { _, showing in
            // A second link may have queued while the sheet was open — show it next.
            if !showing { presentPendingSharedLinkIfReady(delay: 0.6) }
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
            // Drain any shared link that arrived before this view was mounted (cold
            // launch, or while the sign-in screen was showing). onChange only fires for
            // changes made after the observer subscribes.
            presentPendingSharedLinkIfReady(delay: 0.3)

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

    // MARK: - Shared link presentation

    /// Nothing else may be presented over the tab view when the shared-link sheet opens.
    private var canPresentSharedLink: Bool {
        !userManager.needsTutorial
            && !userManager.isNewUser
            && !notificationManager.showPermissionPrimer
            && !notificationManager.permissionPrimerOnScreen
            && !subscriptionManager.showPaywall
            && !showSharedLinkSheet
    }

    /// Consumes `reelManager.pendingSharedLinkId` and shows the sheet, but only once every
    /// gate is clear. The delay lets a dismissing cover/sheet finish animating first; the
    /// gates are re-checked after it so a cover that opened meanwhile keeps the link queued.
    /// If SwiftUI drops the sheet anyway (another presentation won the race), the link is
    /// re-queued and retried a few times instead of being lost.
    private func presentPendingSharedLinkIfReady(delay: TimeInterval = 0.15) {
        guard reelManager.pendingSharedLinkId != nil, canPresentSharedLink else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard let uniqueId = reelManager.pendingSharedLinkId, canPresentSharedLink else { return }
            reelManager.pendingSharedLinkId = nil
            sharedLinkUniqueId = uniqueId
            sharedLinkPresentAttempts += 1
            showSharedLinkSheet = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                guard showSharedLinkSheet, !sharedLinkSheetOnScreen else {
                    sharedLinkPresentAttempts = 0
                    return
                }
                // Requested but never appeared. Reset the binding and try again later.
                showSharedLinkSheet = false
                if sharedLinkPresentAttempts < 3 {
                    reelManager.pendingSharedLinkId = uniqueId
                } else {
                    print("⚠️ Gave up presenting shared fact check \(uniqueId) after repeated drops")
                    sharedLinkPresentAttempts = 0
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
