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
    /// True for the entire duration of the in-flight network request (not cleared early
    /// when cache is present). Used to prevent concurrent loadPersonalizedFeed() calls.
    private var isFeedFetching: Bool = false
    
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
    private var feedRefreshDebounceTask: Task<Void, Never>?
    var userId: String = "default-user"
    var sessionId: String = ""
    
    // MARK: - Initialization
    
    init() {
        // Pre-populate from cache so the UI shows content instantly on first render.
        // The real network load happens when loadInitialData() is called.
        let cache = AppDataCache.shared
        if !cache.personalizedFeed.isEmpty {
            personalizedFeed = cache.personalizedFeed
            feedSource       = cache.feedSource
        }
        if !cache.categories.isEmpty {
            categories = cache.categories
        }
    }
    
    // MARK: - Initial Load
    
    /// Called from HomeView.onAppear. Only performs a network fetch if the cache is stale.
    func loadInitialData() {
        let cache = AppDataCache.shared
        Task {
            await withTaskGroup(of: Void.self) { group in
                // Always refresh categories (lightweight) if they are empty
                if cache.categories.isEmpty {
                    group.addTask { await self.loadCategories() }
                }
                // Only hit the network for the feed if cache is stale
                if cache.isFeedStale || self.personalizedFeed.isEmpty {
                    group.addTask { await self.loadPersonalizedFeed() }
                }
                group.addTask { await PersistenceService.shared.resolveStaleThumbnails() }
            }
        }
    }

    // Convenience called from informedApp background preload —
    // returns immediately so the await in the TaskGroup doesn't block.
    func loadInitialData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadCategories() }
            group.addTask { await self.loadPersonalizedFeed() }
            group.addTask { await PersistenceService.shared.resolveStaleThumbnails() }
        }
    }
    
    // MARK: - Categories
    
    func loadCategories() async {
        guard !isCategoriesLoading else { return }
        isCategoriesLoading = true
        do {
            let cats = try await NetworkService.shared.fetchCategories()
            categories = cats
            AppDataCache.shared.categories = cats
        } catch {
            print("⚠️ Could not load categories: \(error)")
            // Populate with static fallback so UI still shows
            if categories.isEmpty { categories = Self.staticCategories }
        }
        isCategoriesLoading = false
    }
    
    // MARK: - Personalized Feed
    
    func loadPersonalizedFeed() async {
        // isFeedFetching stays true for the full duration of the request so concurrent
        // calls can't slip through when cached data causes isFeedLoading to clear early.
        guard !isFeedFetching else { return }
        isFeedFetching = true
        defer { isFeedFetching = false }

        // Only show the loading spinner when there is nothing cached to display yet.
        let hasCache = !personalizedFeed.isEmpty
        if !hasCache { isFeedLoading = true }
        defer { isFeedLoading = false }

        do {
            let response = try await NetworkService.shared.fetchPersonalizedFeed(
                userId: userId,
                sessionId: sessionId,
                limit: 20
            )
            withAnimation(.easeInOut(duration: 0.25)) {
                personalizedFeed = response.reels
                feedSource       = response.source
            }
            let cache = AppDataCache.shared
            cache.personalizedFeed  = response.reels
            cache.feedSource        = response.source
            cache.lastFeedRefresh   = Date()
        } catch {
            print("⚠️ Could not load personalized feed: \(error)")
            if personalizedFeed.isEmpty { personalizedFeed = [] }
        }
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
            // exit search mode when there is no active category browse
            if isSearchMode && selectedCategory == nil {
                isSearchMode = false
                searchResults = []
                isSearching = false
            }
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
                               lower.contains("vm.tiktok.com") ||
                               lower.contains("youtube.com/shorts") ||
                               lower.contains("youtu.be") ||
                               lower.contains("threads.net") ||
                               lower.contains("threads.com") ||
                               lower.contains("twitter.com") ||
                               lower.contains("x.com")
            if isSocialLink {
                // It's a URL — debounce and fact-check
                if isSearchMode { isSearchMode = false; searchResults = []; isSearching = false }
                debounceTask = Task {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    guard !Task.isCancelled else { return }
                    await performFactCheck(for: trimmed, userId: userId, sessionId: sessionId)
                }
                return
            }
        }

        // It's a text search query.
        // Only flip isSearchMode once — avoids a double re-render on every keystroke.
        if !isSearchMode { isSearchMode = true }
        // Show skeleton immediately so there is no blank flash while the debounce waits
        searchDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            await performSearch(query: trimmed)
        }
    }
    
    // MARK: - Search
    
    func selectCategory(_ categoryName: String) {
        // Enter search mode with only a category filter (no search text)
        searchText = ""
        selectedCategory = categoryName
        isSearchMode = true
        Task { await performSearch(query: "*", category: categoryName) }
    }

    func performSearch(query: String, category: String? = nil) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        // Allow wildcard queries used by category browsing
        guard !trimmed.isEmpty else { return }
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
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        // If we're in category-only browse mode (no text query) and the user taps
        // "All", reset back to the normal feed entirely.
        if query.isEmpty {
            if category == nil {
                clearSearch()
            } else {
                selectedCategory = category
                Task { await performSearch(query: "*", category: category) }
            }
            return
        }
        selectedCategory = category
        if isSearchMode {
            Task { await performSearch(query: query, category: category) }
        }
    }
    
    // MARK: - Fact Checking
    
    func performFactCheck(for link: String, userId: String, sessionId: String) async {
        self.processingLink = link
        self.searchText = ""  // Clear immediately so user cannot re-submit
        self.errorMessage = nil
        if let url = URL(string: link) { self.processingThumbnailURL = url }
        print("🔍 Starting fact check for: \(link)")

        // Start Live Activity first, capture its submissionId
        var submissionId: String = UUID().uuidString
        if #available(iOS 16.1, *) {
            currentSubmissionId = submissionId
            print("🔬 [GHOST_DIAG] Calling startActivity for sid=\(submissionId.prefix(8))…")
            await ReelProcessingActivityManager.shared.startActivity(
                submissionId: submissionId, reelURL: link, thumbnailURL: nil
            )
        }

        // Capture the placeholder submission date before the request so all paths use the same value.
        let placeholderSubmittedAt = Date()

        do {
            // POST /fact-check — now returns 202 with submission_id immediately
            let factCheckData = try await NetworkService.shared.performFactCheck(
                link: link, userId: userId, sessionId: sessionId,
                submissionId: submissionId
            )

            if factCheckData.isAsyncSubmission || factCheckData.isAlreadyCompleted {
                // ── Async 202 flow (processing) OR duplicate-URL fast-complete flow ──
                // Resolve the final submission ID before inserting into reels[] so the
                // placeholder is inserted exactly once with the confirmed backend ID.
                // This eliminates the SwiftUI identity rebind that caused cell re-animation.
                if let backendSid = factCheckData.submissionId, !backendSid.isEmpty, backendSid != submissionId {
                    // Re-register the Live Activity under the backend's submission ID
                    // so progress polling (which uses backendSid) can find and update it.
                    if #available(iOS 16.1, *) {
                        ReelProcessingActivityManager.shared.reRegisterActivity(
                            oldSubmissionId: submissionId, newSubmissionId: backendSid
                        )
                        currentSubmissionId = backendSid
                    }
                    submissionId = backendSid
                }

                // Insert the placeholder into reels[] now that we have the confirmed ID.
                let placeholderReel = SharedReel(
                    id: submissionId, url: link, submittedAt: placeholderSubmittedAt,
                    status: .processing, resultId: nil, errorMessage: nil, factCheckData: nil
                )
                SharedReelManager.shared.reels.insert(placeholderReel, at: 0)
                SharedReelManager.shared.saveReels()

                // For already-completed duplicates skip the 5-second initial wait;
                // the first poll will return "completed" immediately and trigger
                // completeActivity + syncHistoryFromBackend.
                let skipWait = factCheckData.isAlreadyCompleted
                SharedReelManager.shared.startProgressPolling(submissionId: submissionId,
                                                              skipInitialWait: skipWait)
                print("✅ Submission accepted (202). Polling for sid=\(submissionId.prefix(8))… (skipWait=\(skipWait))")
                return
            }

            // ── Legacy sync flow (backend returned full result immediately) ────
            let resolvedClaims = factCheckData.resolvedClaims
            let primaryClaim   = resolvedClaims[0]
            let resolvedPlatform = factCheckData.platform ?? detectedPlatformFromURL(link)
            let (platformName, platformIcon) = platformInfo(for: resolvedPlatform)
            let thumbnailURL: URL? = factCheckData.thumbnailUrl.flatMap { URL(string: $0) }

            let newItem = FactCheckItem(
                reelID: nil,
                sourceName: platformName, sourceIcon: platformIcon,
                timeAgo: "Just now", title: factCheckData.title ?? "",
                summary: primaryClaim.summary,
                thumbnailURL: thumbnailURL,
                credibilityScore: calculateCredibilityScore(from: primaryClaim.claimAccuracyRating),
                sources: primaryClaim.sources.joined(separator: ", "),
                verdict: primaryClaim.verdict, claims: resolvedClaims,
                originalLink: link, datePosted: factCheckData.date,
                aiGenerated: factCheckData.aiGenerated, aiProbability: factCheckData.aiProbability
            )
            PersistenceService.shared.saveFactCheck(newItem)

            let storedData = StoredFactCheckData(
                title: factCheckData.title ?? "", summary: primaryClaim.summary,
                thumbnailURL: factCheckData.thumbnailUrl, claims: resolvedClaims,
                datePosted: factCheckData.date, platform: factCheckData.platform,
                aiGenerated: factCheckData.aiGenerated, aiProbability: factCheckData.aiProbability
            )
            let completedReel = SharedReel(
                id: submissionId, url: link, submittedAt: Date(),
                status: .completed, resultId: factCheckData.title ?? "",
                errorMessage: nil, factCheckData: storedData
            )
            // Replace placeholder with completed reel
            if let idx = SharedReelManager.shared.reels.firstIndex(where: { $0.id == submissionId }) {
                SharedReelManager.shared.reels[idx] = completedReel
            } else {
                SharedReelManager.shared.reels.insert(completedReel, at: 0)
            }
            SharedReelManager.shared.saveReels()

            if #available(iOS 16.1, *) {
                ReelProcessingActivityManager.removeFromAppGroupPendingSubmissions(submissionId: submissionId)
                let sid = submissionId
                currentSubmissionId = nil
                Task { @MainActor in
                    await ReelProcessingActivityManager.shared.completeActivity(
                        submissionId: sid, title: factCheckData.title ?? "", verdict: primaryClaim.verdict
                    )
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    await ReelProcessingActivityManager.shared.endActivity(submissionId: sid, dismissalPolicy: .default)
                }
            } else {
                currentSubmissionId = nil
            }

            self.searchText = ""
            self.processingLink = nil
            self.processingThumbnailURL = nil
            await loadPersonalizedFeed()
            SharedReelManager.shared.scheduleThumbnailRefresh()

        } catch let fcErr as FactCheckError {
            let msg = getUserFriendlyErrorMessage(errorType: fcErr.errorType ?? "", fallbackMessage: fcErr.localizedDescription)
            self.errorMessage = msg
            SharedReelManager.shared.reels.removeAll { $0.id == submissionId }
            SharedReelManager.shared.saveReels()
            if #available(iOS 16.1, *) {
                ReelProcessingActivityManager.removeFromAppGroupPendingSubmissions(submissionId: submissionId)
                Task { @MainActor in await ReelProcessingActivityManager.shared.failActivity(submissionId: submissionId, errorMessage: msg) }
                currentSubmissionId = nil
            }
            self.processingLink = nil; self.processingThumbnailURL = nil
        } catch let networkError as NetworkError {
            let msg = networkError.errorDescription ?? "An error occurred"
            self.errorMessage = msg
            SharedReelManager.shared.reels.removeAll { $0.id == submissionId }
            SharedReelManager.shared.saveReels()
            if #available(iOS 16.1, *) {
                ReelProcessingActivityManager.removeFromAppGroupPendingSubmissions(submissionId: submissionId)
                Task { @MainActor in await ReelProcessingActivityManager.shared.failActivity(submissionId: submissionId, errorMessage: msg) }
                currentSubmissionId = nil
            }
            self.processingLink = nil; self.processingThumbnailURL = nil
        } catch {
            let msg = "Failed to check fact: \(error.localizedDescription)"
            self.errorMessage = msg
            SharedReelManager.shared.reels.removeAll { $0.id == submissionId }
            SharedReelManager.shared.saveReels()
            if #available(iOS 16.1, *) {
                ReelProcessingActivityManager.removeFromAppGroupPendingSubmissions(submissionId: submissionId)
                Task { @MainActor in await ReelProcessingActivityManager.shared.failActivity(submissionId: submissionId, errorMessage: msg) }
                currentSubmissionId = nil
            }
            self.processingLink = nil; self.processingThumbnailURL = nil
        }
    }

    // MARK: - External Feed Update

    /// Called when a fact-check completes outside of HomeViewModel (e.g. Share Extension).
    /// Coalesces rapid back-to-back calls (e.g. from syncHistoryFromBackend + syncCompletedFactChecksFromAppGroup
    /// firing simultaneously) into a single feed reload after a short idle window.
    func refreshFeedAfterExternalFactCheck() {
        feedRefreshDebounceTask?.cancel()
        feedRefreshDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 s idle window
            guard !Task.isCancelled else { return }
            await loadPersonalizedFeed()
        }
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
