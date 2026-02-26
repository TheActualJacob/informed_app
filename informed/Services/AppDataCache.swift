//
//  AppDataCache.swift
//  informed
//
//  Singleton cache that persists the last-known feed, categories, and account
//  stats to UserDefaults. ViewModels seed themselves from here immediately on
//  init so the UI always shows *something* before the network responds.
//

import Foundation
import Combine

final class AppDataCache: ObservableObject {

    static let shared = AppDataCache()

    let objectWillChange = PassthroughSubject<Void, Never>()

    private let defaults = UserDefaults.standard
    private let encoder  = JSONEncoder()
    private let decoder  = JSONDecoder()

    // MARK: - Keys

    private enum Keys {
        static let personalizedFeed  = "cache_personalized_feed"
        static let feedSource        = "cache_feed_source"
        static let publicReels       = "cache_public_reels"
        static let categories        = "cache_categories"
        static let checkedCount      = "cache_checked_count"
        static let savedCount        = "cache_saved_count"
        static let sharedCount       = "cache_shared_count"
        static let lastFeedRefresh   = "cache_last_feed_refresh"
        static let lastDiscoverRefresh = "cache_last_discover_refresh"
    }

    // MARK: - Staleness threshold

    /// Skip a background refresh if the cached data is younger than this.
    static let refreshThresholdSeconds: TimeInterval = 5 * 60  // 5 minutes

    // MARK: - Personalized Feed

    var personalizedFeed: [PublicReel] {
        get { load([PublicReel].self, forKey: Keys.personalizedFeed) ?? [] }
        set { save(newValue, forKey: Keys.personalizedFeed) }
    }

    var feedSource: String {
        get { defaults.string(forKey: Keys.feedSource) ?? "chronological" }
        set { defaults.set(newValue, forKey: Keys.feedSource) }
    }

    var lastFeedRefresh: Date? {
        get {
            let t = defaults.double(forKey: Keys.lastFeedRefresh)
            return t > 0 ? Date(timeIntervalSince1970: t) : nil
        }
        set { defaults.set(newValue?.timeIntervalSince1970 ?? 0, forKey: Keys.lastFeedRefresh) }
    }

    var isFeedStale: Bool {
        guard let last = lastFeedRefresh else { return true }
        return Date().timeIntervalSince(last) > Self.refreshThresholdSeconds
    }

    // MARK: - Public (Discover) Feed

    var publicReels: [PublicReel] {
        get { load([PublicReel].self, forKey: Keys.publicReels) ?? [] }
        set { save(newValue, forKey: Keys.publicReels) }
    }

    var lastDiscoverRefresh: Date? {
        get {
            let t = defaults.double(forKey: Keys.lastDiscoverRefresh)
            return t > 0 ? Date(timeIntervalSince1970: t) : nil
        }
        set { defaults.set(newValue?.timeIntervalSince1970 ?? 0, forKey: Keys.lastDiscoverRefresh) }
    }

    var isDiscoverStale: Bool {
        guard let last = lastDiscoverRefresh else { return true }
        return Date().timeIntervalSince(last) > Self.refreshThresholdSeconds
    }

    // MARK: - Categories

    var categories: [CategoryItem] {
        get { load([CategoryItem].self, forKey: Keys.categories) ?? [] }
        set { save(newValue, forKey: Keys.categories) }
    }

    // MARK: - Account Stats

    var checkedCount: Int {
        get { defaults.integer(forKey: Keys.checkedCount) }
        set { defaults.set(newValue, forKey: Keys.checkedCount) }
    }

    var savedCount: Int {
        get { defaults.integer(forKey: Keys.savedCount) }
        set { defaults.set(newValue, forKey: Keys.savedCount) }
    }

    var sharedCount: Int {
        get { defaults.integer(forKey: Keys.sharedCount) }
        set { defaults.set(newValue, forKey: Keys.sharedCount) }
    }

    // MARK: - Helpers

    private func load<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    private func save<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? encoder.encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}
