//
//  AppDelegate.swift
//  informed
//
//  Handles push notification registration and receipt
//

import UIKit
import UserNotifications
import ActivityKit

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        // Set the notification delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Register notification categories for reel processing
        registerNotificationCategories()
        
        // Sync backend URL to shared storage for Share Extension
        Config.syncBackendURLToSharedStorage()
        
        // Setup Live Activity tap handling for iOS 16.1+
        if #available(iOS 16.1, *) {
            // Inject the push token handler so ReelProcessingActivityManager can register
            // per-activity APNs tokens without importing NotificationManager (which is
            // main-app-only and not available to the Share/Widget extensions).
            ReelProcessingActivityManager.shared.onActivityPushToken = { token, submissionId in
                await NotificationManager.shared.sendActivityPushTokenToBackend(token, submissionId: submissionId)
            }
            // Inject the background-state check so startActivity can guard against
            // ActivityKit Error 7 without referencing UIApplication.shared directly
            // (which is unavailable in Share/Widget extension targets).
            ReelProcessingActivityManager.shared.isAppInBackground = {
                UIApplication.shared.applicationState == .background
            }
            // Inject the URL lookup so ReelProcessingActivity can resolve a reel URL
            // without referencing SharedReelManager directly (unavailable in extensions).
            ReelProcessingActivityManager.shared.reelURLForSubmissionId = { submissionId in
                SharedReelManager.shared.reels.first(where: { $0.id == submissionId })?.url ?? ""
            }
            setupLiveActivityHandling()
        }
        
        // Setup Darwin notification observer for Share Extension communication
        setupDarwinNotificationObserver()
        
        print("✅ AppDelegate initialized")
        return true
    }
    
    // MARK: - Notification Categories
    
    private func registerNotificationCategories() {
        let processingCategory = UNNotificationCategory(
            identifier: "REEL_PROCESSING",
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([processingCategory])
        print("✅ Registered notification categories")
    }
    
    // MARK: - Darwin Notification Observer
    
    private func setupDarwinNotificationObserver() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let observer = Unmanaged.passUnretained(self).toOpaque()
        
        // Observer 1: New submission notification
        let newSubmissionName = "com.jacob.informed.newSubmission" as CFString
        print("🔧 Setting up Darwin notification observer for: \(newSubmissionName)")
        
        CFNotificationCenterAddObserver(
            center,
            observer,
            { (center, observer, name, object, userInfo) in
                print("============================================================")
                print("📡 *** NEW SUBMISSION DARWIN NOTIFICATION RECEIVED *** ")
                print("   Notification name: \(String(describing: name))")
                print("   Time: \(Date())")
                print("============================================================")
                
                // Trigger check immediately on main thread
                DispatchQueue.main.async {
                    print("🔄 Triggering immediate check from Darwin notification...")
                    Task { @MainActor in
                        if #available(iOS 16.1, *) {
                            await SharedReelManager.shared.checkAndStartPendingLiveActivities()
                        }
                        
                        // Also sync completed fact-checks
                        SharedReelManager.shared.syncCompletedFactChecksFromAppGroup()
                    }
                }
            },
            newSubmissionName,
            nil,
            .deliverImmediately
        )
        
        // Observer 2: Fact-check completion notification
        let completionName = "com.jacob.informed.factCheckComplete" as CFString
        print("🔧 Setting up Darwin notification observer for: \(completionName)")
        
        CFNotificationCenterAddObserver(
            center,
            observer,
            { (center, observer, name, object, userInfo) in
                print("============================================================")
                print("📡 *** FACT-CHECK COMPLETE DARWIN NOTIFICATION RECEIVED *** ")
                print("   Notification name: \(String(describing: name))")
                print("   Time: \(Date())")
                print("============================================================")
                
                // Sync completed fact-checks and update Live Activity immediately
                DispatchQueue.main.async {
                    print("🔄 Triggering Live Activity update from completion notification...")
                    Task { @MainActor in
                        // Sync completed fact-checks (this will update the Live Activity)
                        SharedReelManager.shared.syncCompletedFactChecksFromAppGroup()
                    }
                }
            },
            completionName,
            nil,
            .deliverImmediately
        )
        
        print("✅ Darwin notification observers set up successfully (new submission + completion)")
    }
    
    // MARK: - Remote Notification Registration
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("📱 Device token received: \(tokenString)")
        
        // Save the device token
        Task { @MainActor in
            NotificationManager.shared.saveDeviceToken(tokenString)
        }
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ Failed to register for remote notifications: \(error)")
    }
    
    // MARK: - Handle Received Notifications
    
    // Called when notification is received while app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        
        print("📬 Notification received in foreground: \(userInfo)")
        
        // Handle start processing notification immediately
        if let action = userInfo["action"] as? String, action == "start_processing" {
            print("🎬 START PROCESSING notification received - starting Live Activity NOW!")
            
            // Post to NotificationCenter for immediate response
            NotificationCenter.default.post(
                name: NSNotification.Name("StartProcessingNotificationReceived"),
                object: nil
            )
            
            Task { @MainActor in
                // Check for pending submissions and start Live Activities IMMEDIATELY
                if #available(iOS 16.1, *) {
                    print("🚀 Calling checkAndStartPendingLiveActivities from foreground notification...")
                    await SharedReelManager.shared.checkAndStartPendingLiveActivities()
                }
            }
        }
        
        // Handle other notifications
        Task { @MainActor in
            NotificationManager.shared.handleNotification(userInfo: userInfo)
        }
        
        // Show notification banner even when app is in foreground (but not for start_processing)
        if let action = userInfo["action"] as? String, action == "start_processing" {
            completionHandler([]) // Silent - Live Activity will show instead
        } else {
            completionHandler([.banner, .sound, .badge])
        }
    }
    
    // Called when user taps on notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        print("👆 User tapped notification: \(userInfo)")
        
        // Handle start processing notification (from Share Extension)
        if let action = userInfo["action"] as? String, action == "start_processing" {
            print("🎬 Starting Live Activity for new submission")
            
            Task { @MainActor in
                // Check for pending submissions and start Live Activities
                if #available(iOS 16.1, *) {
                    await SharedReelManager.shared.checkAndStartPendingLiveActivities()
                }
                
                // Also sync completed fact-checks
                SharedReelManager.shared.syncCompletedFactChecksFromAppGroup()
            }
        }
        // Handle completion notification from Share Extension (fact-check complete)
        else if let action = userInfo["action"] as? String, action == "fact_check_complete" {
            print("✅ User tapped fact-check completion notification")
            
            Task { @MainActor in
                // Sync completed fact-checks from App Group and add to feed
                SharedReelManager.shared.syncCompletedFactChecksFromAppGroup()
                
                // Also trigger the notification for informedApp to check
                NotificationCenter.default.post(
                    name: NSNotification.Name("CheckForPendingSharedURLs"),
                    object: nil
                )
                
                // Navigate to My Reels tab
                NotificationCenter.default.post(
                    name: NSNotification.Name("NavigateToMyReels"),
                    object: nil,
                    userInfo: userInfo
                )
            }
        }
        // Handle push notification from backend (if you implement APNs later)
        else if let factCheckId = userInfo["fact_check_id"] as? String {
            print("🔍 Fact-check complete for ID: \(factCheckId)")
            
            Task { @MainActor in
                // Mark this reel as completed in SharedReelManager
                SharedReelManager.shared.markReelAsCompleted(factCheckId: factCheckId)
                
                // Fetch the fact-check data from backend and add to feed
                if userInfo["instagram_url"] as? String != nil {
                    await fetchAndDisplayFactCheck(factCheckId: factCheckId, userInfo: userInfo)
                }
            }
        }
        
        completionHandler()
    }
    
    // MARK: - Fetch Fact-Check Data
    
    @MainActor
    private func fetchAndDisplayFactCheck(factCheckId: String, userInfo: [AnyHashable: Any]) async {
        print("📥 Fetching fact-check data for ID: \(factCheckId)")
        
        // Try to get the Instagram URL from the notification payload
        guard let instagramURL = userInfo["instagram_url"] as? String else {
            print("⚠️ No Instagram URL in notification payload")
            return
        }
        
        // Get user ID and session ID
        let userId = UserManager.shared.currentUserId ?? "anonymous"
        let sessionId = UserManager.shared.currentSessionId ?? ""
        
        do {
            // Fetch the fact-check data from backend using the same endpoint
            let request = FactCheckRequest(link: instagramURL, userId: userId, sessionId: sessionId, deviceId: DeviceManager.deviceId)
            let _ = try await sendFactCheck(request)
            
            print("✅ Fetched fact-check data")
            
            // Refresh the personalized feed so the new item appears
            if let homeViewModel = SharedReelManager.shared.homeViewModel {
                homeViewModel.refreshFeedAfterExternalFactCheck()
                print("✅ Triggered feed refresh after fact-check")
            }
        } catch {
            print("❌ Error fetching fact-check: \(error)")
        }
    }
    
    // MARK: - Handle Remote Notifications
    
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable : Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        print("📬 Remote notification received (background): \(userInfo)")
        
        Task { @MainActor in
            // Mirror the foreground start_processing path so background APNs pushes
            // also trigger Live Activity creation when the Share Extension has queued work.
            if let action = userInfo["action"] as? String, action == "start_processing" {
                print("🎬 Background start_processing push — checking pending Live Activities")
                if #available(iOS 16.1, *) {
                    await SharedReelManager.shared.checkAndStartPendingLiveActivities()
                }
            } else if let action = userInfo["action"] as? String, action == "fact_check_completed",
                      let submissionId = userInfo["submission_id"] as? String,
                      let title = userInfo["title"] as? String,
                      let verdict = userInfo["verdict"] as? String {
                // ── Regular push fallback for Live Activity completion ──
                // The backend sends this when no per-activity push token was available.
                // Update the existing Live Activity to the completed state so the
                // Dynamic Island shows the result even when the app was suspended.
                print("✅ [APNs] Background completion push for \(submissionId.prefix(8)) — updating Live Activity")
                if #available(iOS 16.1, *) {
                    await ReelProcessingActivityManager.shared.completeActivity(
                        submissionId: submissionId,
                        title: title,
                        verdict: verdict
                    )
                }
            } else {
                NotificationManager.shared.handleNotification(userInfo: userInfo)
            }
        }
        
        completionHandler(.newData)
    }
    
    // MARK: - Live Activity Handling
    
    @available(iOS 16.1, *)
    private func setupLiveActivityHandling() {
        Task { @MainActor in
            // 1. Observe Push-to-Start Live Activity tokens (iOS 17.2+)
            if #available(iOS 17.2, *) {
                Task {
                    for await pushToStartToken in Activity<ReelProcessingActivityAttributes>.pushToStartTokenUpdates {
                        let tokenString = pushToStartToken.map { String(format: "%02x", $0) }.joined()
                        print("🔑 APNs Push-To-Start Token (LIVE ACTIVITY): \(tokenString)")
                        
                        // Save this locally explicitly for the Share Extension or Backend to securely transmit.
                        if let sharedDefaults = UserDefaults(suiteName: "group.rob") {
                            sharedDefaults.set(tokenString, forKey: "live_activity_push_to_start_token")
                            print("💾 Saved Push-To-Start token to App Group")
                        }
                        
                        // Auto-register with backend right now
                        Task {
                            await NotificationManager.shared.sendPushToStartTokenToBackend(tokenString)
                        }                    }
                }
            }
            
            // 2. Monitor all active Live Activities (e.g. ones started by Share Extension
            //    before the main app launched this session)
            for activity in Activity<ReelProcessingActivityAttributes>.activities {
                let submissionId = activity.attributes.submissionId
                
                Task {
                    for await activityState in activity.activityStateUpdates {
                        if activityState == .dismissed {
                            print("🔄 Live Activity dismissed: \(submissionId)")
                        }
                    }
                }
                
                // Register this activity's push token with the backend.
                ReelProcessingActivityManager.shared.observePushToken(
                    for: activity,
                    submissionId: submissionId
                )
                // Also flush any token the Share Extension already stored in App Group —
                // covers the case where the main app was launched fresh after the Share
                // Extension ran and the token was never forwarded.
                ReelProcessingActivityManager.shared.flushAppGroupPushToken(submissionId: submissionId)
            }
        }
    }
    
    @available(iOS 16.1, *)
    @MainActor
    func handleLiveActivityTap(submissionId: String) {
        print("👆 User tapped Live Activity for submission: \(submissionId)")
        
        // Find the reel in SharedReelManager
        if let reel = SharedReelManager.shared.reels.first(where: { $0.id == submissionId }) {
            if reel.status == .completed {
                // Navigate to My Reels tab and show the completed reel
                NotificationCenter.default.post(
                    name: NSNotification.Name("NavigateToMyReels"),
                    object: nil,
                    userInfo: ["submissionId": submissionId]
                )
                
                // If we have fact check data, optionally navigate directly to detail view
                if let factCheckData = reel.factCheckData {
                    let factCheckItem = factCheckData.toFactCheckItem(originalLink: reel.url)
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ShowFactCheckDetail"),
                        object: nil,
                        userInfo: ["factCheckItem": factCheckItem]
                    )
                }
                
                HapticManager.successImpact()
            } else {
                // Still processing, just navigate to My Reels
                NotificationCenter.default.post(
                    name: NSNotification.Name("NavigateToMyReels"),
                    object: nil
                )
                HapticManager.lightImpact()
            }
        } else {
            print("⚠️ Could not find reel for submission: \(submissionId)")
            // Still navigate to My Reels tab
            NotificationCenter.default.post(
                name: NSNotification.Name("NavigateToMyReels"),
                object: nil
            )
        }
    }
}
