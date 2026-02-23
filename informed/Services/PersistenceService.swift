//
//  PersistenceService.swift
//  informed
//
//  Centralized persistence layer for app data
//

import Foundation

class PersistenceService {
    static let shared = PersistenceService()
    
    private let defaults = UserDefaults.standard
    private let appGroupDefaults = UserDefaults(suiteName: Config.appGroupName)
    
    // MARK: - Keys
    
    private enum Keys {
        static let factCheckHistory = "fact_check_history"
        static let savedFactChecks = "saved_fact_checks"
        static let sharedCount = "shared_count"
        static let lastSyncDate = "last_sync_date"
    }
    
    // MARK: - Fact Check History
    
    func saveFactCheck(_ item: FactCheckItem) {
        var history = getFactCheckHistory()
        history.insert(item, at: 0)
        
        // Keep only last 100 items
        if history.count > 100 {
            history = Array(history.prefix(100))
        }
        
        // Encode and save
        if let encoded = try? JSONEncoder().encode(history.map { FactCheckCodable(from: $0) }) {
            defaults.set(encoded, forKey: Keys.factCheckHistory)
        }
    }
    
    func getFactCheckHistory() -> [FactCheckItem] {
        guard let data = defaults.data(forKey: Keys.factCheckHistory),
              let decoded = try? JSONDecoder().decode([FactCheckCodable].self, from: data) else {
            return []
        }
        return decoded.map { $0.toFactCheckItem() }
    }
    
    func clearHistory() {
        defaults.removeObject(forKey: Keys.factCheckHistory)
    }
    
    // MARK: - Stale Thumbnail Resolution
    
    /// Fetches the user's reel list from the backend and patches any locally-stored
    /// FactCheckItems whose thumbnailURL is still pointing at a social page URL
    /// (i.e. was saved before the backend started returning real image URLs).
    func resolveStaleThumbnails() async {
        guard let userId = UserManager.shared.currentUserId,
              let sessionId = UserManager.shared.currentSessionId else { return }
        
        guard var urlComponents = URLComponents(string: Config.Endpoints.userReels) else { return }
        urlComponents.queryItems = [
            URLQueryItem(name: "userId", value: userId),
            URLQueryItem(name: "sessionId", value: sessionId),
            URLQueryItem(name: "limit", value: "100")
        ]
        guard let url = urlComponents.url else { return }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else { return }
            
            let userReels = try JSONDecoder().decode(UserReelsResponse.self, from: data)
            
            // Build a map of videoLink -> real thumbnailUrl
            var thumbnailMap: [String: String] = [:]
            for reel in userReels.reels {
                if let thumb = reel.thumbnailUrl, !thumb.isEmpty {
                    thumbnailMap[reel.link] = thumb
                }
            }
            
            guard !thumbnailMap.isEmpty else { return }
            
            // Patch history
            let history = getFactCheckHistory()
            var changed = false
            let patched = history.map { item -> FactCheckItem in
                guard let link = item.originalLink,
                      let realThumb = thumbnailMap[link],
                      let realURL = URL(string: realThumb) else { return item }
                
                // Only patch if current thumbnail is missing or is a social page URL
                let current = item.thumbnailURL?.absoluteString ?? ""
                let isSocialPage = current.contains("instagram.com/reel") ||
                                   current.contains("instagram.com/p/") ||
                                   current.contains("tiktok.com/@") ||
                                   current.contains("vm.tiktok.com") ||
                                   current.isEmpty
                guard isSocialPage else { return item }
                
                changed = true
                return FactCheckItem(
                    sourceName: item.sourceName,
                    sourceIcon: item.sourceIcon,
                    timeAgo: item.timeAgo,
                    title: item.title,
                    summary: item.summary,
                    thumbnailURL: realURL,
                    credibilityScore: item.credibilityScore,
                    sources: item.sources,
                    verdict: item.verdict,
                    factCheck: item.factCheck,
                    originalLink: item.originalLink,
                    datePosted: item.datePosted
                )
            }
            
            if changed {
                if let encoded = try? JSONEncoder().encode(patched.map { FactCheckCodable(from: $0) }) {
                    defaults.set(encoded, forKey: Keys.factCheckHistory)
                    print("✅ Patched stale thumbnails in local history")
                }
            }
        } catch {
            print("⚠️ Could not resolve stale thumbnails: \(error)")
        }
    }
    
    // MARK: - Saved Fact Checks
    
    func saveFactCheckForLater(_ item: FactCheckItem) {
        var saved = getSavedFactChecks()
        if !saved.contains(where: { $0.id == item.id }) {
            saved.append(item)
            
            if let encoded = try? JSONEncoder().encode(saved.map { FactCheckCodable(from: $0) }) {
                defaults.set(encoded, forKey: Keys.savedFactChecks)
            }
        }
    }
    
    func unsaveFactCheck(_ item: FactCheckItem) {
        var saved = getSavedFactChecks()
        saved.removeAll { $0.id == item.id }
        
        if let encoded = try? JSONEncoder().encode(saved.map { FactCheckCodable(from: $0) }) {
            defaults.set(encoded, forKey: Keys.savedFactChecks)
        }
    }
    
    func getSavedFactChecks() -> [FactCheckItem] {
        guard let data = defaults.data(forKey: Keys.savedFactChecks),
              let decoded = try? JSONDecoder().decode([FactCheckCodable].self, from: data) else {
            return []
        }
        return decoded.map { $0.toFactCheckItem() }
    }
    
    func isFactCheckSaved(_ item: FactCheckItem) -> Bool {
        return getSavedFactChecks().contains { $0.id == item.id }
    }
    
    // MARK: - Shared Count
    
    func incrementSharedCount() {
        let current = getSharedCount()
        defaults.set(current + 1, forKey: Keys.sharedCount)
    }
    
    func getSharedCount() -> Int {
        return defaults.integer(forKey: Keys.sharedCount)
    }
    
    // MARK: - Sync Methods
    
    func syncToAppGroup() {
        // Sync critical data to app group for share extension
        if let appGroupDefaults = appGroupDefaults {
            // Sync shared count
            appGroupDefaults.set(getSharedCount(), forKey: Keys.sharedCount)
        }
    }
}

// MARK: - Codable Wrapper for FactCheckItem

struct FactCheckCodable: Codable {
    let sourceName: String
    let sourceIcon: String
    let timeAgo: String
    let title: String
    let summary: String
    let thumbnailURLString: String?
    let credibilityScore: Double
    let sources: String
    let verdict: String
    let factCheck: FactCheck
    let originalLink: String?
    let datePosted: String?
    
    init(from item: FactCheckItem) {
        self.sourceName = item.sourceName
        self.sourceIcon = item.sourceIcon
        self.timeAgo = item.timeAgo
        self.title = item.title
        self.summary = item.summary
        self.thumbnailURLString = item.thumbnailURL?.absoluteString
        self.credibilityScore = item.credibilityScore
        self.sources = item.sources
        self.verdict = item.verdict
        self.factCheck = item.factCheck
        self.originalLink = item.originalLink
        self.datePosted = item.datePosted
    }
    
    func toFactCheckItem() -> FactCheckItem {
        return FactCheckItem(
            sourceName: sourceName,
            sourceIcon: sourceIcon,
            timeAgo: timeAgo,
            title: title,
            summary: summary,
            thumbnailURL: thumbnailURLString.flatMap { URL(string: $0) },
            credibilityScore: credibilityScore,
            sources: sources,
            verdict: verdict,
            factCheck: factCheck,
            originalLink: originalLink,
            datePosted: datePosted
        )
    }
}
