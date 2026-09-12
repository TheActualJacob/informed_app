//
//  AccountViewModel.swift
//  informed
//
//  View model for account statistics and management
//

import Foundation
import Combine
import SwiftUI

@MainActor
class AccountViewModel: ObservableObject {
    @Published var checkedCount: Int = 0
    @Published var savedCount: Int = 0
    @Published var sharedCount: Int = 0
    @Published var isLoading: Bool = false

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Seed from cache so stats appear instantly with no flash
        let cache = AppDataCache.shared
        checkedCount = cache.checkedCount
        savedCount   = cache.savedCount
        sharedCount  = cache.sharedCount

        // Refresh whenever History / Saved / Shared change or My Reels finishes syncing.
        NotificationCenter.default.publisher(for: PersistenceService.statsDidChange)
            .sink { [weak self] _ in self?.loadStats() }
            .store(in: &cancellables)
        SharedReelManager.shared.$reels
            .dropFirst()
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.loadStats() }
            .store(in: &cancellables)
    }

    func loadStats() {
        // Read local data synchronously — no network call needed.
        // "Checked" = fact checks this account has run (the My Reels list, synced from
        // the backend per user). "Saved" and "Shared" are per-account local counters.
        let persistence = PersistenceService.shared
        let checked = SharedReelManager.shared.reels.filter { $0.status == .completed }.count
        let saved   = persistence.getSavedFactChecks().count
        let shared  = persistence.getSharedCount()

        // Update published values (still on MainActor)
        checkedCount = checked
        savedCount   = saved
        sharedCount  = shared

        // Persist to cache for next cold launch
        let cache = AppDataCache.shared
        cache.checkedCount = checked
        cache.savedCount   = saved
        cache.sharedCount  = shared
    }
}
