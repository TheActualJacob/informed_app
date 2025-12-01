import Foundation
internal import Combine

// MARK: - User Defaults Manager (for storing userId)

class UserManager: ObservableObject {
    static let shared = UserManager()
    
    @Published var isAuthenticated: Bool = false
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
        let appGroupName = "group.com.jacob.informed"
        if let sharedDefaults = UserDefaults(suiteName: appGroupName) {
            sharedDefaults.set(userId, forKey: userIdKey)
            sharedDefaults.set(username, forKey: usernameKey)
            sharedDefaults.set(sessionId, forKey: "stored_session_id")
            print("💾 User info also saved to App Group for Share Extension")
        }
        
        self.currentUserId = userId
        self.currentUsername = username
        self.currentSessionId = sessionId
        self.isAuthenticated = true
        
        print("✅ User saved: \(username) (ID: \(userId), Session: \(sessionId))")
    }
    
    func logout() {
        UserDefaults.standard.removeObject(forKey: userIdKey)
        UserDefaults.standard.removeObject(forKey: usernameKey)
        
        // Delete session ID from Keychain
        KeychainManager.shared.deleteSessionId()
        
        // Also remove from App Group
        let appGroupName = "group.com.jacob.informed"
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
    }
}
