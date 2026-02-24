import SwiftUI
import ActivityKit

// MARK: - Main Content View

struct ContentView: View {
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var reelManager: SharedReelManager
    @State private var selectedTab: Int = 0

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
                    Image(systemName: "person.circle.fill")
                    Text("Account")
                }
                .tag(3)
        }
        .accentColor(.brandBlue)
        .onChange(of: selectedTab) { oldValue, newValue in
            if newValue == 2 {
                if #available(iOS 16.1, *) {
                    Task {
                        print("🎬 User switched to My Reels tab - dismissing completed activities")
                        await dismissCompletedActivitiesForMyReels()
                    }
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
                selectedTab = 2
                if let submissionId = notification.userInfo?["submissionId"] as? String {
                    reelManager.pendingDeepLinkId = submissionId
                }
            }

            // Open a specific fact-check detail view directly
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("ShowFactCheckDetail"),
                object: nil,
                queue: .main
            ) { notification in
                selectedTab = 2
                if let item = notification.userInfo?["factCheckItem"] as? FactCheckItem {
                    reelManager.pendingDeepLinkItem = item
                }
            }
        }
    }

    @available(iOS 16.1, *)
    private func dismissCompletedActivitiesForMyReels() async {
        let terminalIds = SharedReelManager.shared.reels
            .filter { $0.status == .completed || $0.status == .failed }
            .map { $0.id }
        for submissionId in terminalIds {
            await ReelProcessingActivityManager.shared.endActivity(
                submissionId: submissionId,
                dismissalPolicy: .immediate
            )
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
    }
}
