import Foundation

// MARK: - App Configuration

struct Config {
    // MARK: - Backend URL
    
    /// The base URL for the backend API
    /// Change this value when your backend server IP/port changes
    static let backendURL = "https://informed-production.up.railway.app"
    
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
        
        // New endpoints for enhanced features
        static let publicFeed = Config.endpoint("/api/public-feed")
        static let userReels = Config.endpoint("/api/user-reels")
        static let trackInteraction = Config.endpoint("/api/track-interaction")
        static let syncHistory = Config.endpoint("/api/sync-history")
        static let history = Config.endpoint("/history")
        
        // Real-time progress tracking
        static let submissionStatus = Config.endpoint("/api/submission-status")
        
        // Vector & Category endpoints
        static let categories = Config.endpoint("/api/categories")
        static let search = Config.endpoint("/api/search")
        static let personalizedFeed = Config.endpoint("/api/user-feed-personalized")
    }
}
