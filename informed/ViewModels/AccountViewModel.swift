//
//  AccountViewModel.swift
//  informed
//
//  View model for account statistics and management
//

import Foundation
import SwiftUI
import Combine

@MainActor
class AccountViewModel: ObservableObject {
    @Published var checkedCount: Int = 0
    @Published var savedCount: Int = 0
    @Published var sharedCount: Int = 0
    @Published var isLoading: Bool = false

    init() {
        // Seed from cache so stats appear instantly with no flash
        let cache = AppDataCache.shared
        checkedCount = cache.checkedCount
        savedCount   = cache.savedCount
        sharedCount  = cache.sharedCount
    }

    func loadStats() {
        // Read local data synchronously — no network call needed
        let persistence = PersistenceService.shared
        let checked = persistence.getFactCheckHistory().count
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
