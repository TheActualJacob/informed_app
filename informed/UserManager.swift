import Foundation
import Combine

// MARK: - User Defaults Manager (for storing userId)

class UserManager: ObservableObject {
    static let shared = UserManager()
    
    @Published var isAuthenticated: Bool = false
    @Published var isNewUser: Bool = false
    @Published var needsTutorial: Bool = false
    @Published var currentUserId: String?
    @Published var currentUsername: String?
    @Published var currentSessionId: String?
    
    private let userIdKey = "stored_user_id"
    private let usernameKey = "stored_username"
    
    init() {
        loadStoredUser()
    }
    
    func loadStoredUser() {
        if let userId = UserDefaults.standard.string(forKey: userIdKey),
           let username = UserDefaults.standard.string(forKey: usernameKey) {
            self.currentUserId = userId
            self.currentUsername = username
            
            // Load session ID from Keychain
            self.currentSessionId = KeychainManager.shared.getSessionId()
            
            self.isAuthenticated = true
            
            if currentSessionId != nil {
                print("✅ User loaded: \(username) (ID: \(userId), Session: \(currentSessionId!))")
            } else {
                print("⚠️ User loaded but no session ID found: \(username) (ID: \(userId))")
            }
        }
    }
    
    func saveUser(userId: String, username: String, sessionId: String) {
        // Save user ID and username to UserDefaults
        UserDefaults.standard.set(userId, forKey: userIdKey)
        UserDefaults.standard.set(username, forKey: usernameKey)
        
        // Save session ID to Keychain
        KeychainManager.shared.saveSessionId(sessionId)
        
        // Also save to App Group for Share Extension access
        let appGroupName = "group.rob"
        if let sharedDefaults = UserDefaults(suiteName: appGroupName) {
            sharedDefaults.set(userId, forKey: userIdKey)
            sharedDefaults.set(username, forKey: usernameKey)
            sharedDefaults.set(sessionId, forKey: "stored_session_id")
            print("💾 User info also saved to App Group for Share Extension")
        }
        
        let oldUserId = self.currentUserId
        self.currentUserId = userId
        self.currentUsername = username
        self.currentSessionId = sessionId
        self.isAuthenticated = true

        // Show tutorial only for brand-new users who have never seen either flow,
        // OR for existing users who haven't seen the tutorial for the current app version.
        let tutorialKey = "hasSeenTutorial_\(userId)"
        let welcomeKey = "hasSeenWelcome_\(userId)"
        let tutorialVersionKey = "tutorialSeenVersion_\(userId)"
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let seenVersion = UserDefaults.standard.string(forKey: tutorialVersionKey)

        // Reset tutorial flag if the app was updated since they last saw it
        if UserDefaults.standard.bool(forKey: tutorialKey) && seenVersion != currentVersion {
            UserDefaults.standard.removeObject(forKey: tutorialKey)
        }

        if !UserDefaults.standard.bool(forKey: tutorialKey) && !UserDefaults.standard.bool(forKey: welcomeKey) {
            self.needsTutorial = true
        }

        print("✅ User saved: \(username) (ID: \(userId), Session: \(sessionId))")

        // Always reload reels immediately when the active user changes so that
        // SharedReelManager has the right data before ContentView/SharedReelsView
        // appear and trigger syncHistoryFromBackend.
        if oldUserId != userId {
            SharedReelManager.shared.reloadReelsForCurrentUser(userId: userId)
            NotificationCenter.default.post(name: NSNotification.Name("UserDidChange"), object: nil)
            print("📢 Posted UserDidChange notification")
        }
    }
    
    /// Call once the welcome/onboarding screen is dismissed so it never shows again.
    func markWelcomeSeen() {
        if let userId = currentUserId {
            UserDefaults.standard.set(true, forKey: "hasSeenWelcome_\(userId)")
        }
        isNewUser = false
    }

    /// Call once the video tutorial is completed so it never shows again.
    /// Chains the WelcomeView (pro upgrade screen) immediately after.
    func markTutorialSeen() {
        if let userId = currentUserId {
            let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
            UserDefaults.standard.set(true, forKey: "hasSeenTutorial_\(userId)")
            UserDefaults.standard.set(currentVersion, forKey: "tutorialSeenVersion_\(userId)")
        }
        needsTutorial = false
        isNewUser = true
    }

    func deleteAccount() async throws {
        guard let userId = currentUserId, let sessionId = currentSessionId else {
            throw NetworkError.unauthorized
        }
        try await NetworkService.shared.deleteAccount(userId: userId, sessionId: sessionId)
        logout()
    }

    func logout() {
        UserDefaults.standard.removeObject(forKey: userIdKey)
        UserDefaults.standard.removeObject(forKey: usernameKey)
        
        // Delete session ID from Keychain
        KeychainManager.shared.deleteSessionId()
        
        // Also remove from App Group
        let appGroupName = "group.rob"
        if let sharedDefaults = UserDefaults(suiteName: appGroupName) {
            sharedDefaults.removeObject(forKey: userIdKey)
            sharedDefaults.removeObject(forKey: usernameKey)
            sharedDefaults.removeObject(forKey: "stored_session_id")
        }
        
        self.currentUserId = nil
        self.currentUsername = nil
        self.currentSessionId = nil
        self.isAuthenticated = false
        
        print("✅ User logged out and session cleared")
        
        // Notify that user changed (logged out)
        NotificationCenter.default.post(name: NSNotification.Name("UserDidChange"), object: nil)
        print("📢 Posted UserDidChange notification (logout)")
    }
}
