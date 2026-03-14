//
//  informedApp.swift
//  informed
//
//  Created by Jacob Ryan on 11/22/25.
//

import SwiftUI
import ActivityKit
import RevenueCat

@main
struct informedApp: App {
    init() {
        // Configure RevenueCat unconditionally on every launch so the SDK
        // initialises and registers this device even before the user logs in.
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: SubscriptionManager.revenueCatAPIKey)
    }

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var userManager = UserManager.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var reelManager = SharedReelManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    // App-level ViewModels — kept alive across tab switches so cached data
    // is always available and never reset when the user navigates away.
    @StateObject private var homeViewModel = HomeViewModel()
    @StateObject private var feedViewModel = FeedViewModel()
    
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var alertMessage = ""
    @State private var checkTimer: Timer?
    
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            if userManager.isAuthenticated {
                ContentView()
                    .environmentObject(userManager)
                    .environmentObject(notificationManager)
                    .environmentObject(reelManager)
                    .environmentObject(homeViewModel)
                    .environmentObject(feedViewModel)
                    .environmentObject(subscriptionManager)
                    .fullScreenCover(isPresented: $userManager.isNewUser) {
                        WelcomeView {
                            userManager.markWelcomeSeen()
                        }
                        .environmentObject(subscriptionManager)
                    }
                    .fullScreenCover(isPresented: $userManager.needsTutorial) {
                        HowItWorksCarouselView(onComplete: {
                            userManager.markTutorialSeen()
                        }, allowSkip: false)
                    }
                    .onOpenURL { url in
                        handleIncomingURL(url)
                    }
                    .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                        // Universal Link handler: informed-app.com/share/{id}
                        // Fires when iOS opens the app from a shared link
                        // instead of loading it in Safari (requires associated-domains entitlement)
                        guard let url = activity.webpageURL,
                              url.host == "informed-app.com",
                              url.pathComponents.count >= 3,
                              url.pathComponents[1] == "share" else { return }
                        let uniqueId = url.pathComponents[2]
                        // Post to ContentView which will switch to Discover tab and
                        // present SharedFactCheckSheet with a loading skeleton
                        NotificationCenter.default.post(
                            name: NSNotification.Name("ShowSharedFactCheck"),
                            object: nil,
                            userInfo: ["uniqueId": uniqueId]
                        )
                    }
                    .onAppear {
                        // Check for pending shared URLs from Share Extension
                        checkForPendingSharedURL()
                        
                        // Set up observer for notification-triggered checks
                        NotificationCenter.default.addObserver(
                            forName: NSNotification.Name("CheckForPendingSharedURLs"),
                            object: nil,
                            queue: .main
                        ) { _ in
                            print("🔔 Received notification to check for pending shared URLs")
                            checkForPendingSharedURL()
                        }
                        
                        // Also observe for UNUserNotification being delivered
                        NotificationCenter.default.addObserver(
                            forName: NSNotification.Name("StartProcessingNotificationReceived"),
                            object: nil,
                            queue: .main
                        ) { _ in
                            print("🔔 Received start processing notification!")
                            checkForPendingSharedURL()
                        }
                    }
                    .onChange(of: scenePhase) { oldPhase, newPhase in
                        // CRITICAL: This is the fallback mechanism for free Apple Developer accounts
                        // When extensionContext?.open() fails in the Share Extension (no paid account),
                        // this observer detects when the user manually returns to the app and
                        // triggers checkForPendingSharedURL() to start the Dynamic Island.
                        
                        // Check for shared URLs whenever app becomes active
                        if newPhase == .active {
                            print("🔄 App became active - checking for pending shared URLs")
                            print("   (This works even with free Apple Developer account)")
                            
                            // Dismiss completed Live Activities FIRST, then check for new ones.
                            // Running these in sequence (not parallel) prevents a completed
                            // submission from being re-started by checkAndStartPendingLiveActivities.
                            Task {
                                if #available(iOS 16.1, *) {
                                    await dismissAllCompletedLiveActivities()
                                    // Show completed Dynamic Island badges for any fact-checks
                                    // that finished while the app was in the background.
                                    await ReelProcessingActivityManager.shared.drainPendingCompletedActivities()
                                    // Show error Dynamic Island badges for any fact-checks that
                                    // failed (limit_reached, timeout, etc.) in background.
                                    await ReelProcessingActivityManager.shared.drainPendingFailedActivities()
                                    // CRITICAL: Check any in-progress Live Activities against the
                                    // backend. If a fact-check completed while the app was
                                    // suspended (background polling frozen by iOS), this catches
                                    // it up — driving the Dynamic Island to its completed state.
                                    // Also flushes any pending activity push tokens.
                                    await reelManager.reconcileActiveActivitiesWithBackend()
                                }
                                // If the Share Extension hit the daily/weekly limit, show the
                                // upgrade paywall now that the user has foregrounded the app.
                                if let defaults = UserDefaults(suiteName: "group.rob"),
                                   let limitType = defaults.string(forKey: "pending_limit_reached_type") {
                                    defaults.removeObject(forKey: "pending_limit_reached_type")
                                    defaults.synchronize()
                                    print("💳 [App] Draining pending_limit_reached_type=\(limitType) — showing paywall")
                                    await MainActor.run { subscriptionManager.handleLimitReached(type: limitType) }
                                }
                                // Only check for new pending submissions after cleanup is done
                                checkForPendingSharedURL()
                                startPeriodicChecking()
                            }
                        } else if newPhase == .background {
                            print("📱 App went to background - continuing checks for Share Extension")
                            // DON'T stop checking - keep running to detect Share Extension submissions
                            // The timer will continue running in background for a short time
                        } else if newPhase == .inactive {
                            print("📱 App became inactive")
                            // Don't stop checking during inactive state either
                        }
                    }
                    .task {
                        // Identify the logged-in user in RevenueCat and sync
                        // subscription state. identify() awaits the RC logIn so
                        // syncCustomerInfo() runs on the correct subscriber.
                        if let userId = userManager.currentUserId {
                            await subscriptionManager.identify(userId: userId)
                        } else {
                            // Eagerly sync even for anonymous sessions so isPro
                            // is correct before the user gets to any paywalls.
                            await subscriptionManager.syncCustomerInfo()
                        }

                        // Request notification permissions on first launch
                        if notificationManager.authorizationStatus == .notDetermined {
                            _ = await notificationManager.requestNotificationPermissions()
                        }
                        // Background-preload both feeds in parallel so data is warm
                        // before the user even taps a tab.
                        if let userId = userManager.currentUserId,
                           let sessionId = userManager.currentSessionId {
                            homeViewModel.userId = userId
                            homeViewModel.sessionId = sessionId
                            SharedReelManager.shared.homeViewModel = homeViewModel
                        }
                        await withTaskGroup(of: Void.self) { group in
                            group.addTask { await homeViewModel.loadInitialData() }
                            group.addTask { await feedViewModel.loadFeedIfNeeded() }
                            group.addTask { await subscriptionManager.refreshUsage() }
                        }
                    }
                    .alert("Success", isPresented: $showSuccessAlert) {
                        Button("OK", role: .cancel) {}
                    } message: {
                        Text(alertMessage)
                    }
                    .alert("Error", isPresented: $showErrorAlert) {
                        Button("OK", role: .cancel) {}
                    } message: {
                        Text(alertMessage)
                    }
            } else {
                AuthenticationView()
                    .environmentObject(userManager)
            }
        }
    }
    
    // MARK: - Live Activity Dismissal

    @available(iOS 16.1, *)
    private func dismissAllCompletedLiveActivities() async {
        let allSys = Activity<ReelProcessingActivityAttributes>.activities
        print("🔬 [GHOST_DIAG] dismissAllCompletedLiveActivities called")
        print("🔬 [GHOST_DIAG]   System activities: \(allSys.count)")
        for a in allSys {
            print("🔬 [GHOST_DIAG]     • sid=\(a.attributes.submissionId.prefix(8)) state=\(a.activityState) progress=\(Int(a.content.state.progress*100))% status=\(a.content.state.status.rawValue)")
        }
        let trackedKeys = ReelProcessingActivityManager.shared.currentActivities.keys.map { $0.prefix(8) }
        print("🔬 [GHOST_DIAG]   currentActivities keys: \(trackedKeys)")
        let pendingReels  = reelManager.reels.filter { $0.status == .pending   || $0.status == .processing }
        print("🔬 [GHOST_DIAG]   Pending/processing reels: \(pendingReels.map { $0.id.prefix(8) })")

        // ── FIX: also read the App Group's pending_submissions so that in-flight
        // share-extension reels (whose placeholder SharedReel hasn't been inserted
        // into reelManager.reels yet) are NOT treated as orphans. ──
        let appGroupPendingIds: Set<String> = {
            guard let defaults = UserDefaults(suiteName: "group.rob"),
                  let subs = defaults.array(forKey: "pending_submissions") as? [[String: Any]] else {
                return []
            }
            let now = Date().timeIntervalSince1970
            return Set(subs.compactMap { sub -> String? in
                guard let id = sub["id"] as? String,
                      let ts = sub["submitted_at"] as? TimeInterval,
                      (now - ts) < 300,              // younger than 5 min
                      (sub["status"] as? String) == "processing" else { return nil }
                return id
            })
        }()
        print("🔬 [GHOST_DIAG]   App Group in-flight IDs: \(appGroupPendingIds.map { $0.prefix(8) })")

        // 1. End system activities that are already in an ended/dismissed state.
        //    These are truly dead — clean them up immediately.
        for activity in Activity<ReelProcessingActivityAttributes>.activities {
            if activity.activityState == .ended || activity.activityState == .dismissed {
                print("🔬 [GHOST_DIAG]   Ending already-ended system activity sid=\(activity.attributes.submissionId.prefix(8))")
                await activity.end(
                    ActivityContent(state: activity.content.state, staleDate: nil),
                    dismissalPolicy: .immediate
                )
            }
        }

        // 2. Orphan sweep: end any *active* system activity that is stuck IN-PROGRESS
        //    (not yet showing a completed/failed result) with no matching pending reel.
        //
        //    Completed/failed activities are intentionally LEFT ALIVE here — the user
        //    should see "Tap to view results" on the Dynamic Island until they open the
        //    app and navigate to My Reels.  ContentView and SharedReelsView dismiss them
        //    with .immediate once the user has actually seen their results.
        let activeProcessingIds = Set(pendingReels.map { $0.id }).union(appGroupPendingIds)
        for activity in Activity<ReelProcessingActivityAttributes>.activities
        where activity.activityState == .active {
            let sid = activity.attributes.submissionId
            let activityStatus = activity.content.state.status
            // Skip completed/failed states — these are valid result notifications.
            if activityStatus == .completed || activityStatus == .failed {
                print("🔬 [GHOST_DIAG]   ✅ Keeping completed/failed activity sid=\(sid.prefix(8)) — user hasn't seen result yet")
                continue
            }
            if !activeProcessingIds.contains(sid) {
                print("🔬 [GHOST_DIAG]   🧹 Orphan sweep: ending ghost in-progress sid=\(sid.prefix(8)) progress=\(Int(activity.content.state.progress*100))%")
                await ReelProcessingActivityManager.shared.endActivity(
                    submissionId: sid,
                    dismissalPolicy: .immediate
                )
            } else {
                print("🔬 [GHOST_DIAG]   ✅ Keeping active activity sid=\(sid.prefix(8)) — has matching pending reel or App Group entry")
            }
        }

        let remaining = Activity<ReelProcessingActivityAttributes>.activities
        print("🔬 [GHOST_DIAG] dismissAll complete. Remaining system activities: \(remaining.count)")
        for a in remaining {
            print("🔬 [GHOST_DIAG]   • sid=\(a.attributes.submissionId.prefix(8)) state=\(a.activityState) progress=\(Int(a.content.state.progress*100))%")
        }

        // Purge any stale currentActivities entries that have no matching system activity.
        // These accumulate when an activity is ended by iOS (e.g. push-to-start auto-dismiss)
        // without our endActivity() being called, or when a session ends without cleanup.
        if #available(iOS 16.1, *) {
            ReelProcessingActivityManager.shared.cleanupStaleTrackedActivities()
        }

        print("✅ [App] Dismissed completed/failed/orphan Live Activities on foreground")
    }

    // MARK: - Periodic Checking
    
    private func startPeriodicChecking() {
        // Cancel existing timer if any
        stopPeriodicChecking()
        
        print("⏰ Starting periodic check for new submissions (every 1s)")
        
        // Check immediately
        checkForPendingSharedURL()
        
        // Then check every 1 second, but auto-stop when nothing is pending
        checkTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak reelManager] _ in
            checkForPendingSharedURL()
            // Stop polling once there are no more pending share-extension submissions.
            // Dispatch to main actor explicitly to satisfy the Sendable requirement.
            Task { @MainActor in
                if reelManager?.activeProcessingURL == nil {
                    stopPeriodicChecking()
                }
            }
        }
    }
    
    private func stopPeriodicChecking() {
        checkTimer?.invalidate()
        checkTimer = nil
        print("⏹️ Stopped periodic checking")
    }
    
    // MARK: - Share Extension Support
    
    private func checkForPendingSharedURL() {
        print("🔄 Checking for pending and completed fact-checks from Share Extension...")
        
        Task { @MainActor in
            // Check if there's a new submission flag
            let appGroupName = "group.rob"
            if let sharedDefaults = UserDefaults(suiteName: appGroupName) {
                let timestamp = sharedDefaults.double(forKey: "new_submission_timestamp")
                if timestamp > 0 {
                    print("🚩 Found new submission flag (timestamp: \(timestamp))")
                    // Clear the flag
                    sharedDefaults.removeObject(forKey: "new_submission_timestamp")
                    sharedDefaults.synchronize()
                }
            }
            
            // Check for pending submissions and start Live Activities
            if #available(iOS 16.1, *) {
                print("🎬 Checking for pending Live Activities to start...")
                await reelManager.checkAndStartPendingLiveActivities()
            }
            
            // Then sync completed fact-checks from App Group to main app
            print("📥 Syncing completed fact-checks...")
            reelManager.syncCompletedFactChecksFromAppGroup()
        }
    }
    
    // MARK: - URL Handling
    
    private func handleIncomingURL(_ url: URL) {
        print("🔗 Received URL: \(url.absoluteString)")
        
        // Check if this is our app's URL scheme
        guard url.scheme == "factcheckapp" else {
            print("⚠️ Unknown URL scheme: \(url.scheme ?? "nil")")
            return
        }
        
        // Handle different URL hosts
        if url.host == "startActivity" {
            // 🚀 INSTANT TRIGGER (requires paid Apple Developer account)
            // This is called when Share Extension successfully opens the app via extensionContext?.open()
            // With a FREE account, this will never be called - the scenePhase observer handles it instead
            print("🚀 Share Extension triggered app via URL scheme!")
            print("   (This only works with paid Apple Developer account)")
            print("   Immediately checking for pending submissions...")
            checkForPendingSharedURL()
            return
        }
        
        if url.host == "share" {
            // Manual share URL with Instagram link in query parameters
            print("📤 Processing manual share URL")
            
            // Show loading state
            Task { @MainActor in
                // Handle the shared URL
                let success = await reelManager.handleSharedURL(url)
                
                if success {
                    alertMessage = "Instagram reel submitted successfully! You'll be notified when fact-checking is complete."
                    showSuccessAlert = true
                } else if let error = reelManager.uploadError {
                    alertMessage = error
                    showErrorAlert = true
                }
            }
            return
        }
        
        if url.host == "detail" {
            // Deep-link from Live Activity tap: factcheckapp://detail?id=<submissionId>
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let submissionId = components.queryItems?.first(where: { $0.name == "id" })?.value {
                print("🔗 Live Activity deep-link: opening fact check for submission \(submissionId)")
                Task { @MainActor in
                    openFactCheck(submissionId: submissionId)
                }
            }
            
            return
        }

        print("⚠️ Unknown URL host: \(url.host ?? "nil")")
    }

    // MARK: - Open Fact Check Deep Link

    @MainActor
    private func openFactCheck(submissionId: String) {
        // Determine the current activity/reel state up-front so we can handle
        // completed, failed, and in-progress submissions differently.
        var activityStatus: ProcessingStatus? = nil
        if #available(iOS 16.1, *) {
            activityStatus = Activity<ReelProcessingActivityAttributes>.activities
                .first { $0.attributes.submissionId == submissionId }
                .map { $0.content.state.status }
        }
        let localReel = reelManager.reels.first { $0.id == submissionId }
        let knownFailed = activityStatus == .failed
            || localReel?.status == .failed

        // 1. Dismiss the Live Activity for completed/failed states.
        //    Leave it running if still in-progress so the island stays visible.
        if #available(iOS 16.1, *) {
            let alreadyDone = activityStatus == .completed || activityStatus == .failed
            if alreadyDone {
                Task {
                    await ReelProcessingActivityManager.shared.endActivity(
                        submissionId: submissionId,
                        dismissalPolicy: .immediate
                    )
                }
            }
        }

        // 2. Switch to My Reels tab
        NotificationCenter.default.post(
            name: NSNotification.Name("NavigateToMyReels"),
            object: nil,
            userInfo: ["submissionId": submissionId]
        )

        // 3. For failed submissions there is no detail view to show — the user
        //    tapped the island to dismiss it and see the error card in My Reels.
        //    Skip the loading view entirely to avoid an infinite spinner.
        if knownFailed {
            print("ℹ️ [openFactCheck] Submission \(submissionId.prefix(8)) is failed — navigating to My Reels only")
            HapticManager.lightImpact()
            return
        }

        // 4. Signal the loading detail view to open immediately
        reelManager.deepLinkLoading = true

        // 5. Sync from backend then deliver the resolved item to the loading view.
        //    We retry up to 3 times with brief back-off so that:
        //      a) any concurrent sync already underway can finish first, and
        //      b) if the backend hasn't written the record yet we give it a moment.
        Task { @MainActor in
            let found = await resolveCompletedReel(submissionId: submissionId)
            if let item = found {
                reelManager.pendingDeepLinkItem = item
            } else {
                print("⚠️ [openFactCheck] Reel \(submissionId.prefix(8)) not found after retries — staying on My Reels list")
                reelManager.deepLinkLoading = false
            }
        }

        HapticManager.successImpact()
    }

    /// Tries up to 3 times to find a completed reel for `submissionId`.
    /// Each attempt waits for any in-progress sync to finish, then runs a
    /// fresh sync and looks up the reel. Delays between retries give the
    /// backend time to finish writing the fact-check record.
    ///
    /// For duplicate-URL submissions the server assigns a new `submissionId`
    /// but after sync the reel appears under the original `uniqueID`. We
    /// capture the submission's URL before the first sync so we can fall back
    /// to a URL-based lookup when the ID no longer matches.
    @MainActor
    private func resolveCompletedReel(submissionId: String) async -> FactCheckItem? {
        // Resolve the URL for this submission from most-reliable to least-reliable source:
        //
        // 1. Live Activity attributes — the original reelURL baked in at activity creation.
        //    This survives even after the placeholder reel is replaced by the backend's
        //    uniqueID-keyed reel during sync and after pending_submissions is cleared.
        //
        // 2. Local reels[] — works when the placeholder reel is still present (fast path
        //    before the first sync runs), but becomes nil once sync replaces it.
        let submissionURL: String? = {
            if #available(iOS 16.1, *) {
                if let activity = Activity<ReelProcessingActivityAttributes>.activities
                    .first(where: { $0.attributes.submissionId == submissionId }) {
                    let url = activity.attributes.reelURL
                    if !url.isEmpty { return url }
                }
            }
            return reelManager.reels.first(where: { $0.id == submissionId })?.url
        }()

        // Fast-path: the polling loop already synced the completed data when it
        // detected completion.  Check the live reels[] array first — no network
        // round-trip needed if the data is already there.
        if let item = findCompletedReel(submissionId: submissionId, submissionURL: submissionURL) {
            print("✅ [openFactCheck] Found completed reel in cache (no sync needed)")
            return item
        }

        let retryDelaysNs: [UInt64] = [0, 1_500_000_000, 3_000_000_000] // 0s, 1.5s, 3s

        for (attempt, delayNs) in retryDelaysNs.enumerated() {
            if delayNs > 0 {
                try? await Task.sleep(nanoseconds: delayNs)
            }

            // If another sync is already running, wait for it to finish before
            // triggering a new one — otherwise the guard in syncHistoryFromBackend
            // returns immediately and we'd query stale data.
            while reelManager.isSyncing {
                try? await Task.sleep(nanoseconds: 150_000_000) // poll every 150ms
            }

            await reelManager.syncHistoryFromBackend()

            if let item = findCompletedReel(submissionId: submissionId, submissionURL: submissionURL) {
                print("✅ [openFactCheck] Found completed reel on attempt \(attempt + 1)")
                return item
            }

            // If the reel is now known to be failed (post-sync), stop retrying.
            let localStatus = reelManager.reels.first { $0.id == submissionId }?.status
                ?? reelManager.reels.first(where: {
                    guard let url = submissionURL else { return false }
                    return reelURLPathsMatch($0.url, url)
                })?.status
            if localStatus == .failed {
                print("ℹ️ [openFactCheck] Reel \(submissionId.prefix(8)) is failed — stopping retries")
                return nil
            }

            print("⏳ [openFactCheck] Reel \(submissionId.prefix(8)) not ready on attempt \(attempt + 1) — will retry")
        }

        return nil
    }

    /// Searches `reelManager.reels` for a completed reel matching `submissionId` or
    /// `submissionURL`.  The ID lookup handles the normal (in-app) flow; the URL lookup
    /// handles the common case where the backend assigns a `uniqueID` that differs from
    /// the iOS-generated `submissionId`.  URL comparison strips query-string parameters
    /// (e.g. `?igsh=…`) that Instagram appends and the backend may normalise away.
    @MainActor
    private func findCompletedReel(submissionId: String, submissionURL: String?) -> FactCheckItem? {
        // Primary: exact backend ID or iOS submission ID match.
        if let reel = reelManager.reels.first(where: { $0.id == submissionId }),
           reel.status == .completed,
           let data = reel.factCheckData {
            return data.toFactCheckItem(originalLink: reel.url)
        }

        // Fallback: path-based URL match — ignores query params and www. prefix so
        // `https://www.instagram.com/reel/ABC/?igsh=xyz` matches
        // `https://instagram.com/reel/ABC/`.
        if let url = submissionURL,
           let reel = reelManager.reels.first(where: {
               reelURLPathsMatch($0.url, url) && $0.status == .completed && $0.factCheckData != nil
           }),
           let data = reel.factCheckData {
            return data.toFactCheckItem(originalLink: reel.url)
        }

        return nil
    }

    private func reelURLPathsMatch(_ a: String, _ b: String) -> Bool {
        guard a != b else { return true }
        guard let ua = URL(string: a), let ub = URL(string: b) else { return false }
        func host(_ u: URL) -> String {
            let h = (u.host ?? "").lowercased()
            return h.hasPrefix("www.") ? String(h.dropFirst(4)) : h
        }
        let pathA = ua.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let pathB = ub.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return ua.scheme?.lowercased() == ub.scheme?.lowercased()
            && host(ua) == host(ub)
            && pathA == pathB
    }
}
