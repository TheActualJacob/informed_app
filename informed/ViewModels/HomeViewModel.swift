//
//  HomeViewModel.swift
//  informed
//
//  View model for the home feed with fact-checking functionality
//

import Foundation
import SwiftUI
import Combine
import ActivityKit

@MainActor
class HomeViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var searchText: String = "" {
        didSet {
            if searchText != oldValue {
                handleSearchTextChange(searchText)
            }
        }
    }
    
    // Search & mode state
    @Published var isSearchMode: Bool = false
    @Published var isSearching: Bool = false
    @Published var searchResults: [PublicReel] = []
    @Published var searchResultCount: Int = 0
    
    // Categories
    @Published var categories: [CategoryItem] = []
    @Published var isCategoriesLoading: Bool = false
    @Published var selectedCategory: String? = nil
    
    // Personalized feed
    @Published var personalizedFeed: [PublicReel] = []
    @Published var isFeedLoading: Bool = false
    @Published var feedSource: String = "chronological" // "personalized" | "chronological"
    
    // Shared state
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var processingLink: String? // For showing processing banner
    @Published var processingThumbnailURL: URL? // For link preview in banner

    // Keep items for any legacy references (populated from personalizedFeed)
    var items: [FactCheckItem] { personalizedFeed.map { $0.toFactCheckItem() } }
    
    // Track current Live Activity submission ID for testing
    private var currentSubmissionId: String?
    
    // MARK: - Properties
    
    private var debounceTask: Task<Void, Never>?
    private var searchDebounceTask: Task<Void, Never>?
    var userId: String = "default-user"
    var sessionId: String = ""
    
    // MARK: - Initialization
    
    init() {
        // Data loads triggered by HomeView.onAppear once userId/sessionId are set
    }
    
    // MARK: - Initial Load
    
    func loadInitialData() {
        Task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.loadCategories() }
                group.addTask { await self.loadPersonalizedFeed() }
                group.addTask { await PersistenceService.shared.resolveStaleThumbnails() }
            }
        }
    }
    
    // MARK: - Categories
    
    func loadCategories() async {
        guard !isCategoriesLoading else { return }
        isCategoriesLoading = true
        do {
            let cats = try await NetworkService.shared.fetchCategories()
            categories = cats
        } catch {
            print("⚠️ Could not load categories: \(error)")
            // Populate with static fallback so UI still shows
            categories = Self.staticCategories
        }
        isCategoriesLoading = false
    }
    
    // MARK: - Personalized Feed
    
    func loadPersonalizedFeed() async {
        guard !isFeedLoading else { return }
        isFeedLoading = true
        do {
            let response = try await NetworkService.shared.fetchPersonalizedFeed(
                userId: userId,
                sessionId: sessionId,
                limit: 20
            )
            personalizedFeed = response.reels
            feedSource = response.source
        } catch {
            print("⚠️ Could not load personalized feed: \(error)")
            personalizedFeed = []
        }
        isFeedLoading = false
    }
    
    func refresh() {
        Task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.loadCategories() }
                group.addTask { await self.loadPersonalizedFeed() }
            }
        }
    }
    
    // MARK: - Search Text Handling
    
    private func handleSearchTextChange(_ text: String) {
        // Cancel pending tasks
        debounceTask?.cancel()
        searchDebounceTask?.cancel()
        
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            isSearchMode = false
            searchResults = []
            return
        }
        
        // Check if it's a social media link
        if let url = URL(string: trimmed),
           url.scheme != nil,
           url.host != nil {
            let lower = trimmed.lowercased()
            let isSocialLink = lower.contains("instagram.com") ||
                               lower.contains("instagr.am") ||
                               lower.contains("tiktok.com") ||
                               lower.contains("vm.tiktok.com")
            if isSocialLink {
                // It's a URL — debounce and fact-check
                isSearchMode = false
                debounceTask = Task {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    guard !Task.isCancelled else { return }
                    await performFactCheck(for: trimmed, userId: userId, sessionId: sessionId)
                }
                return
            }
        }
        
        // It's a text search query
        isSearchMode = true
        searchDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s debounce
            guard !Task.isCancelled else { return }
            await performSearch(query: trimmed)
        }
    }
    
    // MARK: - Search
    
    func performSearch(query: String, category: String? = nil) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isSearching = true
        do {
            let response = try await NetworkService.shared.searchReels(
                query: query,
                userId: userId,
                sessionId: sessionId,
                limit: 30,
                category: category ?? selectedCategory
            )
            searchResults = response.reels
            searchResultCount = response.totalCount
        } catch {
            print("❌ Search failed: \(error)")
            searchResults = []
            searchResultCount = 0
        }
        isSearching = false
    }
    
    func clearSearch() {
        searchText = ""
        isSearchMode = false
        searchResults = []
        selectedCategory = nil
    }
    
    // MARK: - Category Filter for Search
    
    func filterSearchByCategory(_ category: String?) {
        selectedCategory = category
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if isSearchMode && !query.isEmpty {
            Task { await performSearch(query: query, category: category) }
        }
    }
    
    // MARK: - Fact Checking
    
    func performFactCheck(for link: String, userId: String, sessionId: String) async {
        self.processingLink = link
        self.errorMessage = nil
        
        if let url = URL(string: link) {
            self.processingThumbnailURL = url
        }
        
        print("🔍 Starting fact check for: \(link)")

        // ── GHOST DIAGNOSTICS ──────────────────────────────────────────
        if #available(iOS 16.1, *) {
            let sysActivities = Activity<ReelProcessingActivityAttributes>.activities
            print("🔬 [GHOST_DIAG] performFactCheck START")
            print("🔬 [GHOST_DIAG]   System activities at entry: \(sysActivities.count)")
            for a in sysActivities {
                print("🔬 [GHOST_DIAG]     • sid=\(a.attributes.submissionId) state=\(a.activityState) progress=\(Int((a.content.state.progress)*100))%")
            }
            print("🔬 [GHOST_DIAG]   currentSubmissionId at entry: \(currentSubmissionId ?? "nil")")
            print("🔬 [GHOST_DIAG]   currentActivities keys: \(ReelProcessingActivityManager.shared.currentActivities.keys.map{$0.prefix(8)})")
        }
        // ───────────────────────────────────────────────────────────────

        // Start the Live Activity and AWAIT it before launching the network call.
        if #available(iOS 16.1, *) {
            let submissionId = UUID().uuidString
            currentSubmissionId = submissionId
            print("🔬 [GHOST_DIAG] Calling startActivity for sid=\(submissionId.prefix(8))…")
            await ReelProcessingActivityManager.shared.startActivity(
                submissionId: submissionId,
                reelURL: link,
                thumbnailURL: nil
            )
            if #available(iOS 16.1, *) {
                let tracked = ReelProcessingActivityManager.shared.currentActivities[submissionId] != nil
                let inSystem = Activity<ReelProcessingActivityAttributes>.activities.contains { $0.attributes.submissionId == submissionId }
                print("🔬 [GHOST_DIAG] After startActivity: tracked=\(tracked) inSystem=\(inSystem)")
            }
        }
        
        do {
            let factCheckData = try await NetworkService.shared.performFactCheck(
                link: link,
                userId: userId,
                sessionId: sessionId
            )
            
            let factCheck = FactCheck(
                claim: factCheckData.claim,
                verdict: factCheckData.verdict,
                claimAccuracyRating: factCheckData.claimAccuracyRating,
                explanation: factCheckData.explanation,
                summary: factCheckData.summary,
                sources: factCheckData.sources
            )
            
            let platformName: String
            let platformIcon: String
            if let platform = factCheckData.platform {
                if platform.lowercased() == "tiktok" {
                    platformName = "TikTok"; platformIcon = "music.note"
                } else {
                    platformName = "Instagram"; platformIcon = "camera.fill"
                }
            } else if link.lowercased().contains("tiktok") {
                platformName = "TikTok"; platformIcon = "music.note"
            } else {
                platformName = "Instagram"; platformIcon = "camera.fill"
            }
            
            // Use thumbnailUrl only — do NOT fall back to videoLink because videoLink is
            // a social-page URL (instagram.com/reel/…) that LinkPreviewView's
            // hasRealThumbnail guard will reject.  A nil thumbnail shows the platform
            // placeholder until loadPersonalizedFeed() returns with the real CDN URL.
            let thumbnailURL: URL? = factCheckData.thumbnailUrl.flatMap { URL(string: $0) }
            let newItem = FactCheckItem(
                sourceName: platformName,
                sourceIcon: platformIcon,
                timeAgo: "Just now",
                title: factCheckData.title,
                summary: factCheckData.summary,
                thumbnailURL: thumbnailURL,
                credibilityScore: calculateCredibilityScore(from: factCheckData.claimAccuracyRating),
                sources: factCheckData.sources.joined(separator: ", "),
                verdict: factCheckData.verdict,
                factCheck: factCheck,
                originalLink: link,
                datePosted: factCheckData.date,
                aiGenerated: factCheckData.aiGenerated,
                aiProbability: factCheckData.aiProbability
            )
            
            PersistenceService.shared.saveFactCheck(newItem)
            
            let storedData = StoredFactCheckData(
                title: factCheckData.title,
                summary: factCheckData.summary,
                thumbnailURL: factCheckData.thumbnailUrl,
                claim: factCheckData.claim,
                verdict: factCheckData.verdict,
                claimAccuracyRating: factCheckData.claimAccuracyRating,
                explanation: factCheckData.explanation,
                sources: factCheckData.sources,
                datePosted: factCheckData.date,
                platform: factCheckData.platform,
                aiGenerated: factCheckData.aiGenerated,
                aiProbability: factCheckData.aiProbability
            )
            
            // Re-use the same submissionId that was given to the Live Activity so
            // SharedReel.id == Live Activity submissionId. This is critical: the
            // dismissAllCompletedLiveActivities sweep looks up reels by id, so a
            // mismatched id means the activity can never be found and ended, leaving
            // a ghost stuck at 10%.
            let reelId = currentSubmissionId ?? UUID().uuidString
            let newReel = SharedReel(
                id: reelId,
                url: link,
                submittedAt: Date(),
                status: .completed,
                resultId: factCheckData.title,
                errorMessage: nil,
                factCheckData: storedData
            )
            
            SharedReelManager.shared.reels.insert(newReel, at: 0)
            SharedReelManager.shared.saveReels()
            
            if #available(iOS 16.1, *), let submissionId = currentSubmissionId {
                print("🔬 [GHOST_DIAG] Fact check SUCCESS. sid=\(submissionId.prefix(8))")
                print("🔬 [GHOST_DIAG]   tracked=\(ReelProcessingActivityManager.shared.currentActivities[submissionId] != nil)")
                // Remove from App Group so the periodic checker can never re-spawn a ghost.
                ReelProcessingActivityManager.removeFromAppGroupPendingSubmissions(submissionId: submissionId)
                currentSubmissionId = nil
                Task { @MainActor in
                    print("🔬 [GHOST_DIAG] Calling completeActivity for sid=\(submissionId.prefix(8))…")
                    await ReelProcessingActivityManager.shared.completeActivity(
                        submissionId: submissionId,
                        title: factCheckData.title,
                        verdict: factCheckData.verdict
                    )
                    print("🔬 [GHOST_DIAG] completeActivity done. Sleeping 3s then ending…")
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    await ReelProcessingActivityManager.shared.endActivity(
                        submissionId: submissionId,
                        dismissalPolicy: .default
                    )
                    let stillInSystem = Activity<ReelProcessingActivityAttributes>.activities
                        .contains { $0.attributes.submissionId == submissionId }
                    print("🔬 [GHOST_DIAG] After endActivity: stillInSystem=\(stillInSystem)")
                    print("🏁 [HomeViewModel] Live Activity fully ended for \(submissionId.prefix(8))")
                }
            } else {
                print("🔬 [GHOST_DIAG] ⚠️ No currentSubmissionId at success point")
                currentSubmissionId = nil
            }

            self.searchText = ""
            self.processingLink = nil
            self.processingThumbnailURL = nil

            await loadPersonalizedFeed()

            // Patch any social-page thumbnail URLs that slipped through in PersistenceService
            // history and in SharedReel.factCheckData (covers both home and My Reels cards).
            SharedReelManager.shared.scheduleThumbnailRefresh()

        } catch let networkError as NetworkError {
            let msg = networkError.errorDescription ?? "An error occurred"
            self.errorMessage = msg
            if #available(iOS 16.1, *), let submissionId = currentSubmissionId {
                ReelProcessingActivityManager.removeFromAppGroupPendingSubmissions(submissionId: submissionId)
                Task { @MainActor in
                    await ReelProcessingActivityManager.shared.failActivity(submissionId: submissionId, errorMessage: msg)
                }
                currentSubmissionId = nil
            }
            self.processingLink = nil
            self.processingThumbnailURL = nil
        } catch {
            var msg = "Failed to check fact: \(error.localizedDescription)"
            if let nsError = error as NSError?,
               let data = nsError.userInfo["data"] as? Data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorType = json["error_type"] as? String {
                msg = getUserFriendlyErrorMessage(errorType: errorType, fallbackMessage: msg)
            }
            self.errorMessage = msg
            if #available(iOS 16.1, *), let submissionId = currentSubmissionId {
                ReelProcessingActivityManager.removeFromAppGroupPendingSubmissions(submissionId: submissionId)
                Task { @MainActor in
                    await ReelProcessingActivityManager.shared.failActivity(submissionId: submissionId, errorMessage: msg)
                }
                currentSubmissionId = nil
            }
            self.processingLink = nil
            self.processingThumbnailURL = nil
        }
    }

    // MARK: - External Feed Update

    /// Called when a fact-check completes outside of HomeViewModel (e.g. Share Extension).
    /// Refreshes the personalized feed so the new item appears.
    func refreshFeedAfterExternalFactCheck() {
        Task { await loadPersonalizedFeed() }
    }

    // MARK: - Helper Methods

    func calculateCredibilityScore(from rating: String) -> Double {
        let numericString = rating.replacingOccurrences(of: "%", with: "")
        if let percentage = Double(numericString) {
            return percentage / 100.0
        }
        return 0.5
    }

    // MARK: - Static Category Fallback
    
    static let staticCategories: [CategoryItem] = [
        CategoryItem(name: "Current Events",              count: 0),
        CategoryItem(name: "Politics & Government",       count: 0),
        CategoryItem(name: "Geopolitics & International", count: 0),
        CategoryItem(name: "Health & Medicine",           count: 0),
        CategoryItem(name: "Science & Technology",        count: 0),
        CategoryItem(name: "Environment & Climate",       count: 0),
        CategoryItem(name: "Economy & Finance",           count: 0),
        CategoryItem(name: "Entertainment & Celebrities", count: 0),
        CategoryItem(name: "Sports",                      count: 0),
        CategoryItem(name: "Social Media & Viral",        count: 0),
        CategoryItem(name: "History",                     count: 0),
        CategoryItem(name: "Other",                       count: 0)
    ]
}
