import SwiftUI
import ActivityKit

// MARK: - Main Content View
// This is now a lightweight container that composes the modular views

struct ContentView: View {
    @EnvironmentObject var userManager: UserManager
    @State private var selectedTab: Int = 0
    
    init() {
        // Configure tab bar appearance
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
            // When user switches to My Reels tab, dismiss completed activities
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
            // Listen for navigation requests from notifications
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("NavigateToMyReels"),
                object: nil,
                queue: .main
            ) { _ in
                // Switch to My Reels tab
                selectedTab = 2
            }
        }
    }
    
    @available(iOS 16.1, *)
    private func dismissCompletedActivitiesForMyReels() async {
        // Get SharedReelManager instance
        let completedReelIds = SharedReelManager.shared.reels
            .filter { $0.status == .completed }
            .map { $0.id }
        
        // Dismiss their Live Activities
        for submissionId in completedReelIds {
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
