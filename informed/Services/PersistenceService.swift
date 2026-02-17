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
