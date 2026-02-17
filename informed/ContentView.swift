import SwiftUI

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
