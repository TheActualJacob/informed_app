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
    
    // Signals HomeView to dismiss the keyboard (set true, HomeView resets it)
    @Published var dismissKeyboard: Bool = false
    
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
                // Dismiss the keyboard as soon as a valid link is detected
                dismissKeyboard = true
                // If this exact link is already being processed, don't restart the request
                if processingLink == trimmed { return }
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
        // ── Fast-path: local duplicate detection ─────────────────────────────────
        // If we already have a completed fact-check for this URL locally, navigate
        // to it immediately — no Live Activity, no network call needed.
        if let localReel = SharedReelManager.shared.reels.first(where: {
            urlsMatch($0.url, link) && $0.status == .completed
        }), let localData = localReel.factCheckData {
            print("♻️ [Pre-check] Locally-completed reel found — navigating directly (no network/activity needed)")
            self.searchText = ""
            self.errorMessage = nil
            HapticManager.selection()
            let navItem = localData.toFactCheckItem(originalLink: link)
            // ShowFactCheckDetail atomically sets selectedTab=2 AND pendingDeepLinkItem
            // in one DispatchQueue.main.async block, so SharedReelsView always sees the
            // item in .onChange or .onAppear regardless of whether it was already mounted.
            NotificationCenter.default.post(
                name: NSNotification.Name("ShowFactCheckDetail"),
                object: nil,
                userInfo: ["factCheckItem": navItem]
            )
            Task { await SharedReelManager.shared.syncHistoryFromBackend() }
            return
        }

        self.processingLink = link
        // Detach the debounce task reference BEFORE clearing searchText.
        // Setting searchText = "" triggers handleSearchTextChange("") which calls
        // debounceTask?.cancel() — and debounceTask IS this running task.
        // Cancelling it causes URLSession to throw URLError.cancelled, silently
        // aborting the entire fact-check with no error shown and no navigation.
        debounceTask = nil
        self.searchText = ""  // Clear immediately so user cannot re-submit
        self.errorMessage = nil
        if let url = URL(string: link) { self.processingThumbnailURL = url }
        HapticManager.selection()  // Single subtle "submission received" — synced with processing banner
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

            // Refresh usage counter in background so the pill badge updates
            Task { await SubscriptionManager.shared.refreshUsage() }

            if factCheckData.isAsyncSubmission || factCheckData.isAlreadyCompleted {
                // ── Async 202 flow (processing) OR duplicate-URL fast-complete flow ──

                // Resolve the final submission ID before inserting into reels[] so the
                // placeholder is inserted exactly once with the confirmed backend ID.
                if let backendSid = factCheckData.submissionId, !backendSid.isEmpty, backendSid != submissionId {
                    if #available(iOS 16.1, *) {
                        ReelProcessingActivityManager.shared.reRegisterActivity(
                            oldSubmissionId: submissionId, newSubmissionId: backendSid
                        )
                        currentSubmissionId = backendSid
                    }
                    submissionId = backendSid
                }

                // If the reel is already completed, navigate to the result.
                // Three-tier resolution (fastest-to-slowest):
                //
                //  1. Embedded response data  — backend now ships the full fact-check in
                //     the duplicate 202 response; works for ANY reel ever processed, with
                //     no local cache dependency.
                //
                //  2. Local cache lookup      — instant, no network needed, works when the
                //     reel was recently synced into SharedReelManager.reels[].
                //
                //  3. Polling                 — last resort for edge cases where neither
                //     the embedded data nor the local cache is available.

                if factCheckData.isAlreadyCompleted {
                    // ── Tier 1: embedded data in the 202 response ───────────────────────
                    // Guard: only use embedded data when the backend actually sent claims
                    // (factCheckData.claims != nil and non-empty). Using resolvedClaims
                    // here would be wrong because it synthesises a default fallback entry
                    // even when no real data is present.
                    let embeddedClaims = factCheckData.claims ?? []
                    if !embeddedClaims.isEmpty {
                        print("♻️ [Duplicate] Navigating from embedded response data (no cache/poll needed)")
                        let resolvedPlatform = factCheckData.platform ?? detectedPlatformFromURL(link)
                        let (platformName, platformIcon) = platformInfo(for: resolvedPlatform)
                        let thumbnailURL: URL? = factCheckData.thumbnailUrl.flatMap { URL(string: $0) }
                        let primaryClaim = embeddedClaims[0]
                        let navItem = FactCheckItem(
                            reelID: nil,
                            sourceName: platformName, sourceIcon: platformIcon,
                            timeAgo: "Just now", title: factCheckData.title ?? "",
                            summary: primaryClaim.summary,
                            thumbnailURL: thumbnailURL,
                            credibilityScore: calculateCredibilityScore(from: primaryClaim.claimAccuracyRating),
                            sources: primaryClaim.sources.joined(separator: ", "),
                            verdict: primaryClaim.verdict, claims: embeddedClaims,
                            originalLink: link, datePosted: factCheckData.date,
                            aiGenerated: factCheckData.aiGenerated,
                            aiProbability: factCheckData.aiProbability
                        )
                        self.processingLink = nil; self.processingThumbnailURL = nil
                        if #available(iOS 16.1, *) {
                            ReelProcessingActivityManager.removeFromAppGroupPendingSubmissions(submissionId: submissionId)
                            Task { @MainActor in
                                // Duplicate resolved instantly — dismiss immediately so the island
                                // doesn't linger at 10%.
                                await ReelProcessingActivityManager.shared.endActivity(
                                    submissionId: submissionId, dismissalPolicy: .immediate
                                )
                            }
                            currentSubmissionId = nil
                        }
                        NotificationCenter.default.post(
                            name: NSNotification.Name("ShowFactCheckDetail"),
                            object: nil,
                            userInfo: ["factCheckItem": navItem]
                        )
                        Task { await SharedReelManager.shared.syncHistoryFromBackend() }
                        return
                    }

                    // ── Tier 2: local cache lookup ───────────────────────────────────────
                    let existingReel = SharedReelManager.shared.reels.first(where: {
                        (urlsMatch($0.url, link) || $0.id == submissionId) && $0.status == .completed
                    })
                    if let existingReel, let data = existingReel.factCheckData {
                        print("♻️ [Duplicate] Navigating from local cache")
                        self.processingLink = nil; self.processingThumbnailURL = nil
                        if #available(iOS 16.1, *) {
                            ReelProcessingActivityManager.removeFromAppGroupPendingSubmissions(submissionId: submissionId)
                            Task { @MainActor in
                                // Duplicate resolved instantly — dismiss immediately.
                                await ReelProcessingActivityManager.shared.endActivity(
                                    submissionId: submissionId, dismissalPolicy: .immediate
                                )
                            }
                            currentSubmissionId = nil
                        }
                        let navItem = data.toFactCheckItem(originalLink: link)
                        NotificationCenter.default.post(
                            name: NSNotification.Name("ShowFactCheckDetail"),
                            object: nil,
                            userInfo: ["factCheckItem": navItem]
                        )
                        Task { await SharedReelManager.shared.syncHistoryFromBackend() }
                        return
                    }
                    // ── Tier 3: fall through to poll ─────────────────────────────────────
                    // (skipInitialWait=true so the first poll fires immediately)
                }

                // Insert the placeholder into reels[] now that we have the confirmed ID.
                let placeholderReel = SharedReel(
                    id: submissionId, url: link, submittedAt: placeholderSubmittedAt,
                    status: .processing, resultId: nil, errorMessage: nil, factCheckData: nil
                )
                SharedReelManager.shared.reels.insert(placeholderReel, at: 0)
                SharedReelManager.shared.saveReels()

                // For already-completed duplicates skip the 5-second initial wait;
                // the first poll will return "completed" immediately.
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
                    // Do NOT call endActivity here — the island stays visible ("Tap to view results")
                    // until the user opens FactDetailView, which dismisses it via .onAppear.
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
            if case .requestCancelled = networkError {
                // Request was cancelled (e.g. debounce reset) — silently clean up, no error toast
                SharedReelManager.shared.reels.removeAll { $0.id == submissionId }
                SharedReelManager.shared.saveReels()
                if #available(iOS 16.1, *) {
                    ReelProcessingActivityManager.removeFromAppGroupPendingSubmissions(submissionId: submissionId)
                    Task { @MainActor in await ReelProcessingActivityManager.shared.endActivity(submissionId: submissionId, dismissalPolicy: .default) }
                    currentSubmissionId = nil
                }
                self.processingLink = nil; self.processingThumbnailURL = nil
                return
            }
            if case .limitReached(let type, _, _) = networkError {
                // Limit reached — show paywall, silently clean up (no error toast)
                SharedReelManager.shared.reels.removeAll { $0.id == submissionId }
                SharedReelManager.shared.saveReels()
                if #available(iOS 16.1, *) {
                    ReelProcessingActivityManager.removeFromAppGroupPendingSubmissions(submissionId: submissionId)
                    Task { @MainActor in await ReelProcessingActivityManager.shared.endActivity(submissionId: submissionId, dismissalPolicy: .immediate) }
                    currentSubmissionId = nil
                }
                self.processingLink = nil; self.processingThumbnailURL = nil
                await MainActor.run { SubscriptionManager.shared.handleLimitReached(type: type) }
                return
            }
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
        } catch is CancellationError {
            // Swift structured concurrency cancellation — silently clean up
            SharedReelManager.shared.reels.removeAll { $0.id == submissionId }
            SharedReelManager.shared.saveReels()
            if #available(iOS 16.1, *) {
                ReelProcessingActivityManager.removeFromAppGroupPendingSubmissions(submissionId: submissionId)
                Task { @MainActor in await ReelProcessingActivityManager.shared.endActivity(submissionId: submissionId, dismissalPolicy: .default) }
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

    /// Returns true when two social-media URLs refer to the same piece of content,
    /// ignoring tracking query parameters (igsh, igshid, is_from_webapp, etc.),
    /// `www.` prefixes (www.tiktok.com == tiktok.com), and trailing slashes.
    private func urlsMatch(_ a: String, _ b: String) -> Bool {
        guard a != b else { return true }          // exact match fast-path
        guard let ua = URL(string: a),
              let ub = URL(string: b) else { return false }
        // Strip www. so www.tiktok.com and tiktok.com resolve to the same host.
        func normalizedHost(_ u: URL) -> String {
            let h = (u.host ?? "").lowercased()
            return h.hasPrefix("www.") ? String(h.dropFirst(4)) : h
        }
        let pathA = ua.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let pathB = ub.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return ua.scheme?.lowercased() == ub.scheme?.lowercased() &&
               normalizedHost(ua)      == normalizedHost(ub)      &&
               pathA                   == pathB
    }

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
