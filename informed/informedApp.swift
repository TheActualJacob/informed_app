//
//  informedApp.swift
//  informed
//
//  Created by Jacob Ryan on 11/22/25.
//

import SwiftUI
import ActivityKit

@main
struct informedApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var userManager = UserManager.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var reelManager = SharedReelManager.shared

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
                    .onOpenURL { url in
                        handleIncomingURL(url)
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
        let terminalReels = reelManager.reels.filter { $0.status == .completed || $0.status == .failed }
        let pendingReels  = reelManager.reels.filter { $0.status == .pending   || $0.status == .processing }
        print("🔬 [GHOST_DIAG]   Terminal reels: \(terminalReels.map { $0.id.prefix(8) })")
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

        // 1. End activities whose matching reel is already in a terminal state.
        //    Use .default so the Lock Screen card lingers for up to 4 hours — the
        //    user can glance at the result even after leaving the app.
        let terminalIds = terminalReels.map { $0.id }
        for submissionId in terminalIds {
            // Don't end if it's also listed as in-flight in the App Group — that would
            // mean it was completed locally from a prior sync but a new submission with
            // the same UUID is now in flight (extremely unlikely, but safe to guard).
            if appGroupPendingIds.contains(submissionId) { continue }
            print("🔬 [GHOST_DIAG]   Ending terminal reel activity sid=\(submissionId.prefix(8))")
            await ReelProcessingActivityManager.shared.endActivity(
                submissionId: submissionId,
                dismissalPolicy: .default
            )
        }

        // 2. End system activities that are already in an ended/dismissed state.
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

        // 3. Orphan sweep: end any *active* system activity whose submissionId has no
        //    matching pending/processing reel AND is not in the App Group's pending list.
        let activeProcessingIds = Set(pendingReels.map { $0.id }).union(appGroupPendingIds)
        for activity in Activity<ReelProcessingActivityAttributes>.activities
        where activity.activityState == .active {
            let sid = activity.attributes.submissionId
            if !activeProcessingIds.contains(sid) {
                print("🔬 [GHOST_DIAG]   🧹 Orphan sweep: ending ghost sid=\(sid.prefix(8)) progress=\(Int(activity.content.state.progress*100))%")
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
        // 1. Dismiss the Live Activity right away
        if #available(iOS 16.1, *) {
            Task {
                await ReelProcessingActivityManager.shared.endActivity(
                    submissionId: submissionId,
                    dismissalPolicy: .immediate
                )
            }
        }

        // 2. Switch to My Reels tab
        NotificationCenter.default.post(
            name: NSNotification.Name("NavigateToMyReels"),
            object: nil,
            userInfo: ["submissionId": submissionId]
        )

        // 3. Sync from backend then open the detail view.
        //    We always sync first because the reel may still be a processing
        //    placeholder locally (the Share Extension path completes asynchronously).
        //    After the sync, SharedReelsView's onChange(pendingDeepLinkId) will fire
        //    and navigate to the detail if factCheckData is available.
        Task { @MainActor in
            // Run a quick sync so the completed reel data appears in reels[].
            await reelManager.syncHistoryFromBackend()

            // Try to find the completed reel now that we have fresh data.
            if let reel = reelManager.reels.first(where: { $0.id == submissionId }),
               reel.status == .completed,
               let factCheckData = reel.factCheckData {
                // Signal SharedReelsView to open the detail view.
                let item = factCheckData.toFactCheckItem(originalLink: reel.url)
                reelManager.pendingDeepLinkItem = item
            } else {
                // Reel is still not complete or has no factCheckData — just land
                // on My Reels so the user can see its status.
                print("⚠️ [openFactCheck] Reel \(submissionId.prefix(8)) not completed after sync — staying on My Reels list")
            }
        }

        HapticManager.successImpact()
    }
}
