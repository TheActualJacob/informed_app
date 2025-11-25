import Foundation

// MARK: - App Configuration

struct Config {
    // MARK: - Backend URL
    
    /// The base URL for the backend API
    /// Change this value when your backend server IP/port changes
    static let backendURL = "http://172.20.10.2:5001"
    
    // MARK: - App Group
    
    /// Shared container identifier for sharing data between app and extensions
    static let appGroupName = "group.com.jacob.informed"
    
    // MARK: - Initialization
    
    /// Call this on app launch to sync backend URL to shared storage
    static func syncBackendURLToSharedStorage() {
        if let sharedDefaults = UserDefaults(suiteName: appGroupName) {
            sharedDefaults.set(backendURL, forKey: "backend_url")
            print("🔄 Backend URL synced to App Group: \(backendURL)")
        }
    }
    
    // MARK: - API Endpoints
    
    /// Constructs the full URL for a given endpoint
    /// - Parameter endpoint: The API endpoint path (e.g., "/create-user")
    /// - Returns: The complete URL string
    static func endpoint(_ path: String) -> String {
        return "\(backendURL)\(path)"
    }
    
    // MARK: - Predefined Endpoints
    
    struct Endpoints {
        static let createUser = Config.endpoint("/create-user")
        static let login = Config.endpoint("/login")
        static let factCheck = Config.endpoint("/fact-check")
        static let shareReel = Config.endpoint("/share-reel")
        static let getUserReels = Config.endpoint("/get-user-reels")
        static let registerDevice = Config.endpoint("/register-device")
    }
}
