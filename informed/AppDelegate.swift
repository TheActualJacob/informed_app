//
//  AppDelegate.swift
//  informed
//
//  Handles push notification registration and receipt
//

import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        // Set the notification delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Sync backend URL to shared storage for Share Extension
        Config.syncBackendURLToSharedStorage()
        
        print("✅ AppDelegate initialized")
        return true
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
        
        // Handle the notification
        Task { @MainActor in
            NotificationManager.shared.handleNotification(userInfo: userInfo)
        }
        
        // Show notification banner even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    // Called when user taps on notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        print("👆 User tapped notification: \(userInfo)")
        
        // Handle completion notification from Share Extension (fact-check complete)
        if let action = userInfo["action"] as? String, action == "fact_check_complete" {
            print("✅ User tapped fact-check completion notification")
            
            Task { @MainActor in
                // Sync completed fact-checks from App Group and add to feed
                SharedReelManager.shared.syncCompletedFactChecksFromAppGroup()
                
                // Also trigger the notification for informedApp to check
                NotificationCenter.default.post(
                    name: NSNotification.Name("CheckForPendingSharedURLs"),
                    object: nil
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
                if let instagramURL = userInfo["instagram_url"] as? String {
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
            let request = FactCheckRequest(link: instagramURL, userId: userId, sessionId: sessionId)
            let factCheckData = try await sendFactCheck(request)
            
            print("✅ Fetched fact-check data")
            
            // Add to HomeViewModel if it's set up
            if let homeViewModel = SharedReelManager.shared.homeViewModel {
                // Convert to FactCheck model
                let factCheck = FactCheck(
                    claim: factCheckData.claim,
                    verdict: factCheckData.verdict,
                    claimAccuracyRating: factCheckData.claimAccuracyRating,
                    explanation: factCheckData.explanation,
                    summary: factCheckData.summary,
                    sources: factCheckData.sources
                )
                
                // Create FactCheckItem
                let newItem = FactCheckItem(
                    sourceName: "Instagram",
                    sourceIcon: "camera.fill",
                    timeAgo: "Just now",
                    title: factCheckData.title,
                    summary: factCheckData.summary,
                    thumbnailURL: URL(string: factCheckData.videoLink),
                    credibilityScore: homeViewModel.calculateCredibilityScore(from: factCheckData.claimAccuracyRating),
                    sources: factCheckData.sources.joined(separator: ", "),
                    verdict: factCheckData.verdict,
                    factCheck: factCheck,
                    originalLink: instagramURL,
                    datePosted: factCheckData.date
                )
                
                // Add to main feed
                homeViewModel.items.insert(newItem, at: 0)
                
                print("✅ Added fact-check to feed")
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
        print("📬 Remote notification received: \(userInfo)")
        
        // Handle the notification
        Task { @MainActor in
            NotificationManager.shared.handleNotification(userInfo: userInfo)
        }
        
        completionHandler(.newData)
    }
}
