//
//  NotificationManager.swift
//  informed
//
//  Manages notification permissions and device token registration
//

import Foundation
import UserNotifications
internal import Combine
import UIKit

@MainActor
class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    @Published var deviceToken: String?
    @Published var notificationPermissionGranted: Bool = false
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    
    private let deviceTokenKey = "stored_device_token"
    
    override init() {
        super.init()
        loadStoredDeviceToken()
        Task {
            await checkAuthorizationStatus()
        }
    }
    
    // MARK: - Permission Handling
    
    func requestNotificationPermissions() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            
            notificationPermissionGranted = granted
            
            if granted {
                print("✅ Notification permission granted")
                await registerForRemoteNotifications()
            } else {
                print("❌ Notification permission denied")
            }
            
            await checkAuthorizationStatus()
            return granted
        } catch {
            print("❌ Error requesting notification permissions: \(error)")
            return false
        }
    }
    
    func checkAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
        notificationPermissionGranted = settings.authorizationStatus == .authorized
    }
    
    private func registerForRemoteNotifications() async {
        await UIApplication.shared.registerForRemoteNotifications()
    }
    
    // MARK: - Device Token Management
    
    func saveDeviceToken(_ token: String) {
        self.deviceToken = token
        UserDefaults.standard.set(token, forKey: deviceTokenKey)
        
        // Also save to App Group for Share Extension access
        let appGroupName = "group.com.jacob.informed"
        if let sharedDefaults = UserDefaults(suiteName: appGroupName) {
            sharedDefaults.set(token, forKey: deviceTokenKey)
            print("💾 Device token also saved to App Group for Share Extension")
        }
        
        print("💾 Device token saved: \(token)")
        
        // Send token to backend
        Task {
            await sendDeviceTokenToBackend(token)
        }
    }
    
    private func loadStoredDeviceToken() {
        if let token = UserDefaults.standard.string(forKey: deviceTokenKey) {
            self.deviceToken = token
            print("📱 Loaded device token: \(token)")
        }
    }
    
    func getDeviceToken() -> String? {
        return deviceToken
    }
    
    // MARK: - Backend Communication
    
    private func sendDeviceTokenToBackend(_ token: String) async {
        guard let url = URL(string: "https://my-backend.com/api/register-device") else {
            print("❌ Invalid backend URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authorization header if needed
        // request.setValue("Bearer YOUR_TOKEN", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "device_token": token,
            "platform": "ios"
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) {
                print("✅ Device token registered with backend")
            } else {
                print("⚠️ Failed to register device token with backend")
            }
        } catch {
            print("❌ Error sending device token to backend: \(error)")
        }
    }
    
    // MARK: - Handle Received Notifications
    
    func handleNotification(userInfo: [AnyHashable: Any]) {
        print("📬 Handling notification: \(userInfo)")
        
        // Extract data from notification
        if let factCheckId = userInfo["fact_check_id"] as? String {
            print("🔍 Fact check completed for ID: \(factCheckId)")
            
            // Post notification to update UI
            NotificationCenter.default.post(
                name: NSNotification.Name("FactCheckCompleted"),
                object: nil,
                userInfo: ["fact_check_id": factCheckId]
            )
        }
    }
    
    // MARK: - Open Settings
    
    func openNotificationSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
