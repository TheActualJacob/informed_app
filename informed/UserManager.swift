import Foundation
internal import Combine

// MARK: - User Defaults Manager (for storing userId)

class UserManager: ObservableObject {
    static let shared = UserManager()
    
    @Published var isAuthenticated: Bool = false
    @Published var currentUserId: String?
    @Published var currentUsername: String?
    
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
            self.isAuthenticated = true
        }
    }
    
    func saveUser(userId: String, username: String) {
        UserDefaults.standard.set(userId, forKey: userIdKey)
        UserDefaults.standard.set(username, forKey: usernameKey)
        
        // Also save to App Group for Share Extension access
        let appGroupName = "group.com.jacob.informed"
        if let sharedDefaults = UserDefaults(suiteName: appGroupName) {
            sharedDefaults.set(userId, forKey: userIdKey)
            sharedDefaults.set(username, forKey: usernameKey)
            print("💾 User info also saved to App Group for Share Extension")
        }
        
        self.currentUserId = userId
        self.currentUsername = username
        self.isAuthenticated = true
    }
    
    func logout() {
        UserDefaults.standard.removeObject(forKey: userIdKey)
        UserDefaults.standard.removeObject(forKey: usernameKey)
        self.currentUserId = nil
        self.currentUsername = nil
        self.isAuthenticated = false
    }
}
