//
//  FeedViewModel.swift
//  informed
//
//  View model for the public feed displaying reels from all users
//

import Foundation
import SwiftUI
import Combine

@MainActor
class FeedViewModel: ObservableObject {
   @Published var publicReels: [PublicReel] = []
   @Published var isLoading: Bool = false
   @Published var isLoadingMore: Bool = false
   @Published var errorMessage: String?
   @Published var blockedUserIds: Set<String> = []
   
   // Pagination
   @Published var currentPage: Int = 1
   @Published var hasMore: Bool = true
   @Published var totalCount: Int = 0
   
   private let pageSize: Int = 10
   private var nextCursor: String?
   
   // MARK: - Initialization
   
   init() {
       // Pre-populate from disk cache so the UI renders immediately.
       let cache = AppDataCache.shared
       if !cache.publicReels.isEmpty {
           publicReels = cache.publicReels
           hasMore     = true  // allow pull-to-refresh even with cached data
       }
       // Load persisted blocked users so the feed is filtered immediately.
       loadBlockedUsers()
       // The actual network load is triggered by the app-level TaskGroup in
       // informedApp.task, so we don't kick it off here.
   }
   
   // MARK: - Public Methods
   
   func loadFeed() async {
       guard !isLoading else { return }
       
       // Debug: Print current user state
       print("🔍 FeedViewModel attempting to load feed...")
       print("   UserManager.shared.currentUserId: \(UserManager.shared.currentUserId ?? "nil")")
       print("   UserManager.shared.currentSessionId: \(UserManager.shared.currentSessionId ?? "nil")")
       print("   UserManager.shared.isAuthenticated: \(UserManager.shared.isAuthenticated)")
       
       // Check if user is logged in first
       guard let userId = UserManager.shared.currentUserId,
             let _ = UserManager.shared.currentSessionId else {
           if UserManager.shared.currentUserId != nil {
               errorMessage = "Session expired. Please log out and log back in."
               print("⚠️ Cannot load feed: User ID exists but session ID is missing")
           } else {
               errorMessage = "Please log in to view the public feed"
               print("⚠️ Cannot load feed: User not logged in")
           }
           return
       }

       // Credentials are valid — clear any stale login error before fetching
       if errorMessage?.contains("log in") == true || errorMessage?.contains("Session expired") == true {
           errorMessage = nil
       }
       
       // Only show the full-screen spinner when there is nothing to show yet
       let hasCache = !publicReels.isEmpty
       if !hasCache { isLoading = true }
       errorMessage = nil
       
       print("✅ Attempting to fetch public feed for user: \(userId)")
       
       do {
           let response = try await fetchPublicFeed(page: 1, limit: pageSize)
           let filtered = blockedUserIds.isEmpty ? response.reels
               : response.reels.filter { !blockedUserIds.contains($0.uploadedBy.id) }
           withAnimation(.easeInOut(duration: 0.25)) {
               publicReels = filtered
               currentPage = response.pagination.currentPage
               hasMore     = response.pagination.hasMore
               totalCount  = response.pagination.totalCount
               nextCursor  = response.pagination.nextCursor
           }
           let cache = AppDataCache.shared
           cache.publicReels         = response.reels
           cache.lastDiscoverRefresh = Date()
           
           print("✅ Loaded \(publicReels.count) public reels")
       } catch let error as NetworkError {
           if case .unauthorized = error {
               errorMessage = "Session expired. Please log out and log back in."
           } else {
               errorMessage = "Backend endpoints not ready. See BACKEND_URGENT_FIX.md"
           }
           print("❌ Error loading feed: \(error)")
       } catch {
           errorMessage = "Backend endpoints not ready. See BACKEND_URGENT_FIX.md"
           print("❌ Error loading feed: \(error)")
       }
       
       isLoading = false
   }

   /// Called from the app-level background preload. Only fetches if cache is stale.
   func loadFeedIfNeeded() async {
       guard AppDataCache.shared.isDiscoverStale || publicReels.isEmpty else {
           print("ℹ️ Discover feed cache is fresh — skipping background fetch")
           return
       }
       await loadFeed()
   }
   
   func loadMoreReels() async {
       guard hasMore && !isLoadingMore && !isLoading else { return }
       
       isLoadingMore = true
       
       do {
           let nextPage = currentPage + 1
           let response = try await fetchPublicFeed(page: nextPage, limit: pageSize)
           
           // Append new reels, excluding any blocked users
           let filtered = blockedUserIds.isEmpty ? response.reels
               : response.reels.filter { !blockedUserIds.contains($0.uploadedBy.id) }
           publicReels.append(contentsOf: filtered)
           currentPage = response.pagination.currentPage
           hasMore = response.pagination.hasMore
           nextCursor = response.pagination.nextCursor
           
           print("✅ Loaded \(response.reels.count) more reels (total: \(publicReels.count))")
       } catch {
           errorMessage = "Failed to load more: \(error.localizedDescription)"
           print("❌ Error loading more reels: \(error)")
       }
       
       isLoadingMore = false
   }
   
   func refresh() async {
       currentPage = 1
       hasMore = true
       nextCursor = nil
       await loadFeed()
   }
   
   func trackView(for reel: PublicReel) async {
       do {
           try await trackInteraction(factCheckId: reel.id, interactionType: "view")
           print("📊 Tracked view for reel: \(reel.id)")
       } catch {
           print("⚠️ Failed to track view: \(error)")
       }
   }
   
   func trackShare(for reel: PublicReel) async {
       // Optimistically increment share count so the UI updates immediately
       // without waiting for the next loadFeed() pull.
       if let idx = publicReels.firstIndex(where: { $0.id == reel.id }) {
           publicReels[idx].engagement.shareCount += 1
       }
       do {
           try await trackInteraction(factCheckId: reel.id, interactionType: "share")
           print("📊 Tracked share for reel: \(reel.id)")
       } catch {
           // Roll back the optimistic increment on failure.
           if let idx = publicReels.firstIndex(where: { $0.id == reel.id }) {
               publicReels[idx].engagement.shareCount = max(0, publicReels[idx].engagement.shareCount - 1)
           }
           print("⚠️ Failed to track share: \(error)")
       }
   }
   
   // MARK: - API Methods

   private func fetchPublicFeed(page: Int, limit: Int) async throws -> PublicFeedResponse {
       guard let userId = UserManager.shared.currentUserId,
             let sessionId = UserManager.shared.currentSessionId else {
           throw NetworkError.unauthorized
       }
       let cursor = page > 1 ? nextCursor : nil
       return try await NetworkService.shared.fetchPublicFeed(
           userId: userId, sessionId: sessionId, page: page, limit: limit, cursor: cursor
       )
   }
   
   private func trackInteraction(factCheckId: String, interactionType: String) async throws {
       guard let userId = UserManager.shared.currentUserId,
             let sessionId = UserManager.shared.currentSessionId else {
           throw NetworkError.unauthorized
       }
       try await NetworkService.shared.trackInteraction(
           userId: userId, sessionId: sessionId,
           factCheckId: factCheckId, interactionType: interactionType
       )
   }

   // MARK: - Block User

   func blockUser(blockedUserId: String, blockedUsername: String) async {
       // Immediately remove from feed & persist locally for instant feedback
       blockedUserIds.insert(blockedUserId)
       publicReels.removeAll { $0.uploadedBy.id == blockedUserId }
       persistBlockedUsers()

       // Fire-and-forget sync to backend
       guard let userId = UserManager.shared.currentUserId,
             let sessionId = UserManager.shared.currentSessionId else { return }
       do {
           try await NetworkService.shared.blockUser(
               userId: userId, sessionId: sessionId, blockedUserId: blockedUserId
           )
           print("🚫 Blocked user: \(blockedUsername)")
       } catch {
           print("⚠️ Block failed to sync to backend: \(error)")
       }
   }

   private func loadBlockedUsers() {
       let saved = UserDefaults.standard.stringArray(forKey: "informed_blocked_user_ids") ?? []
       blockedUserIds = Set(saved)
   }

   private func persistBlockedUsers() {
       UserDefaults.standard.set(Array(blockedUserIds), forKey: "informed_blocked_user_ids")
   }
}
