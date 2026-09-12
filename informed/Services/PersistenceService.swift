//
//  PersistenceService.swift
//  informed
//
//  Centralized persistence layer for app data
//

import Foundation
import Combine

class PersistenceService {
    static let shared = PersistenceService()

    /// Posted after History, Saved or the Shared counter changes so the Account stats
    /// can refresh without polling.
    static let statsDidChange = Notification.Name("PersistenceService.statsDidChange")

    private let defaults = UserDefaults.standard
    private let appGroupDefaults = UserDefaults(suiteName: Config.appGroupName)
    
    // MARK: - Keys
    
    private enum Keys {
        static let factCheckHistory = "fact_check_history"
        static let savedFactChecks = "saved_fact_checks"
        static let sharedCount = "shared_count"
        static let lastSyncDate = "last_sync_date"
    }

    private static let historyLimit = 100

    // MARK: - Per-account scoping

    /// History, Saved and Shared belong to the signed-in account, not the device, so two
    /// people sharing a phone never see each other's stats. Data written before this
    /// existed (un-suffixed keys) is moved to the first account that reads it.
    private func scopedKey(_ base: String) -> String {
        guard let userId = UserManager.shared.currentUserId, !userId.isEmpty else { return base }
        let scoped = "\(base)_\(userId)"
        if defaults.object(forKey: scoped) == nil, let legacy = defaults.object(forKey: base) {
            defaults.set(legacy, forKey: scoped)
            defaults.removeObject(forKey: base)
        }
        return scoped
    }

    private func notifyStatsChanged() {
        NotificationCenter.default.post(name: PersistenceService.statsDidChange, object: nil)
    }

    private func encode(_ items: [FactCheckItem]) -> Data? {
        try? JSONEncoder().encode(items.map { FactCheckCodable(from: $0) })
    }

    private func decode(_ key: String) -> [FactCheckItem] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([FactCheckCodable].self, from: data) else {
            return []
        }
        return decoded.map { $0.toFactCheckItem() }
    }
    
    // MARK: - Fact Check History

    /// Records a viewed or completed fact check. Re-viewing an item moves it to the top.
    func saveFactCheck(_ item: FactCheckItem) {
        var history = getFactCheckHistory()
        let key = item.stableKey
        history.removeAll { $0.stableKey == key }
        history.insert(item, at: 0)
        if history.count > PersistenceService.historyLimit {
            history = Array(history.prefix(PersistenceService.historyLimit))
        }
        if let encoded = encode(history) {
            defaults.set(encoded, forKey: scopedKey(Keys.factCheckHistory))
            notifyStatsChanged()
        }
    }
    
    func getFactCheckHistory() -> [FactCheckItem] {
        decode(scopedKey(Keys.factCheckHistory))
    }
    
    func clearHistory() {
        defaults.removeObject(forKey: scopedKey(Keys.factCheckHistory))
        notifyStatsChanged()
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
                    reelID: item.reelID,
                    sourceName: item.sourceName,
                    sourceIcon: item.sourceIcon,
                    timeAgo: item.timeAgo,
                    title: item.title,
                    summary: item.summary,
                    thumbnailURL: realURL,
                    credibilityScore: item.credibilityScore,
                    sources: item.sources,
                    verdict: item.verdict,
                    claims: item.claims,
                    originalLink: item.originalLink,
                    datePosted: item.datePosted,
                    aiGenerated: item.aiGenerated,
                    aiProbability: item.aiProbability,
                    mediaDurationSeconds: item.mediaDurationSeconds,
                    analyzedDurationSeconds: item.analyzedDurationSeconds
                )
            }
            
            if changed {
                if let encoded = encode(patched) {
                    defaults.set(encoded, forKey: scopedKey(Keys.factCheckHistory))
                    print("✅ Patched stale thumbnails in local history")
                }
            }
        } catch {
            print("⚠️ Could not resolve stale thumbnails: \(error)")
        }
    }
    
    // MARK: - Saved Fact Checks

    // `FactCheckItem.id` is a fresh UUID on every decode, so Saved lookups go through
    // `stableKey` (backend id, else source link) — never the in-memory id.

    func saveFactCheckForLater(_ item: FactCheckItem) {
        var saved = getSavedFactChecks()
        guard !saved.contains(where: { $0.stableKey == item.stableKey }) else { return }
        saved.insert(item, at: 0)   // newest bookmark first
        if let encoded = encode(saved) {
            defaults.set(encoded, forKey: scopedKey(Keys.savedFactChecks))
            notifyStatsChanged()
        }
    }
    
    func unsaveFactCheck(_ item: FactCheckItem) {
        var saved = getSavedFactChecks()
        saved.removeAll { $0.stableKey == item.stableKey }
        if let encoded = encode(saved) {
            defaults.set(encoded, forKey: scopedKey(Keys.savedFactChecks))
            notifyStatsChanged()
        }
    }

    /// Flips the bookmark and returns the new state.
    @discardableResult
    func toggleSaved(_ item: FactCheckItem) -> Bool {
        if isFactCheckSaved(item) {
            unsaveFactCheck(item)
            return false
        }
        saveFactCheckForLater(item)
        return true
    }
    
    func getSavedFactChecks() -> [FactCheckItem] {
        decode(scopedKey(Keys.savedFactChecks))
    }
    
    func isFactCheckSaved(_ item: FactCheckItem) -> Bool {
        getSavedFactChecks().contains { $0.stableKey == item.stableKey }
    }
    
    // MARK: - Shared Count
    
    func incrementSharedCount() {
        let current = getSharedCount()
        defaults.set(current + 1, forKey: scopedKey(Keys.sharedCount))
        syncToAppGroup()
        notifyStatsChanged()
    }
    
    func getSharedCount() -> Int {
        defaults.integer(forKey: scopedKey(Keys.sharedCount))
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
    let reelID: String?
    let sourceName: String
    let sourceIcon: String
    let timeAgo: String
    let title: String
    let summary: String
    let thumbnailURLString: String?
    let credibilityScore: Double
    let sources: String
    let verdict: String
    /// New storage format — 1-3 claims.
    let claims: [ClaimEntry]
    /// Legacy field kept only for migrating old data on disk — not written in new saves.
    let factCheck: FactCheck?
    let originalLink: String?
    let datePosted: String?
    let aiGenerated: String?
    let aiProbability: Double?
    let mediaDurationSeconds: Int?
    let analyzedDurationSeconds: Int?

    init(from item: FactCheckItem) {
        self.reelID = item.reelID
        self.sourceName = item.sourceName
        self.sourceIcon = item.sourceIcon
        self.timeAgo = item.timeAgo
        self.title = item.title
        self.summary = item.summary
        self.thumbnailURLString = item.thumbnailURL?.absoluteString
        self.credibilityScore = item.credibilityScore
        self.sources = item.sources
        self.verdict = item.verdict
        self.claims = item.claims
        self.factCheck = nil  // no longer persisted; only claims is written
        self.originalLink = item.originalLink
        self.datePosted = item.datePosted
        self.aiGenerated = item.aiGenerated
        self.aiProbability = item.aiProbability
        self.mediaDurationSeconds = item.mediaDurationSeconds
        self.analyzedDurationSeconds = item.analyzedDurationSeconds
    }

    func toFactCheckItem() -> FactCheckItem {
        // Prefer new claims array; migrate from legacy factCheck field for old disk data
        let resolvedClaims: [ClaimEntry]
        if !claims.isEmpty {
            resolvedClaims = claims
        } else if let fc = factCheck {
            resolvedClaims = [ClaimEntry(claim: fc.claim, verdict: fc.verdict,
                                         claimAccuracyRating: fc.claimAccuracyRating,
                                         explanation: fc.explanation,
                                         summary: summary, sources: fc.sources)]
        } else {
            resolvedClaims = [ClaimEntry(claim: "", verdict: verdict,
                                         claimAccuracyRating: "\(Int(credibilityScore * 100))%",
                                         explanation: "", summary: summary, sources: [])]
        }
        return FactCheckItem(
            reelID: reelID,
            sourceName: sourceName, sourceIcon: sourceIcon,
            timeAgo: timeAgo, title: title, summary: summary,
            thumbnailURL: thumbnailURLString.flatMap { URL(string: $0) },
            credibilityScore: credibilityScore, sources: sources,
            verdict: verdict, claims: resolvedClaims,
            originalLink: originalLink, datePosted: datePosted,
            aiGenerated: aiGenerated, aiProbability: aiProbability,
            mediaDurationSeconds: mediaDurationSeconds, analyzedDurationSeconds: analyzedDurationSeconds
        )
    }
}
