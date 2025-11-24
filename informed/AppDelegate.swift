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
        
        // Handle the notification tap
        Task { @MainActor in
            NotificationManager.shared.handleNotification(userInfo: userInfo)
            
            // Navigate to the appropriate screen
            if let factCheckId = userInfo["fact_check_id"] as? String {
                // Post notification to navigate to fact check results
                NotificationCenter.default.post(
                    name: NSNotification.Name("NavigateToFactCheck"),
                    object: nil,
                    userInfo: ["fact_check_id": factCheckId]
                )
            }
        }
        
        completionHandler()
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
