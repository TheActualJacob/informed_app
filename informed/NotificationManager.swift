//
//  NotificationManager.swift
//  informed
//
//  Manages notification permissions and device token registration
//

import Foundation
import UserNotifications
import Combine
import UIKit

@MainActor
class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    @Published var deviceToken: String?
    @Published var notificationPermissionGranted: Bool = false
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    
    private let deviceTokenKey = "stored_device_token"
    private let pendingPushToStartTokenKey = "pending_push_to_start_token"
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        loadStoredDeviceToken()
        Task {
            await checkAuthorizationStatus()
        }
        observeLoginForPendingToken()
    }
    
    // MARK: - Pending Token Retry
    
    /// Observes UserManager login state and flushes any queued push-to-start token
    /// that arrived before the user was authenticated.
    private func observeLoginForPendingToken() {
        UserManager.shared.$currentUserId
            .compactMap { $0 }
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.flushPendingPushToStartToken() }
            }
            .store(in: &cancellables)
    }
    
    private func flushPendingPushToStartToken() async {
        guard let token = UserDefaults.standard.string(forKey: pendingPushToStartTokenKey) else { return }
        print("🔄 Retrying queued push-to-start token registration after login...")
        UserDefaults.standard.removeObject(forKey: pendingPushToStartTokenKey)
        await sendPushToStartTokenToBackend(token)
    }
    
    // MARK: - Permission Handling
    
    func requestNotificationPermissions() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            
            notificationPermissionGranted = granted
            
            if granted {
                print("✅ Notification permission granted")
                registerForRemoteNotifications()
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
    
    private func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }
    
    // MARK: - Device Token Management
    
    func saveDeviceToken(_ token: String) {
        self.deviceToken = token
        UserDefaults.standard.set(token, forKey: deviceTokenKey)
        
        // Also save to App Group for Share Extension access
        let appGroupName = "group.rob"
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
        guard let url = URL(string: Config.Endpoints.registerDevice) else {
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
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
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
    
    func sendPushToStartTokenToBackend(_ token: String) async {
        guard let userId = UserManager.shared.currentUserId,
              let sessionId = UserManager.shared.currentSessionId else {
            print("⚠️ No user/session — queuing push-to-start token for retry after login")
            UserDefaults.standard.set(token, forKey: pendingPushToStartTokenKey)
            return
        }
        
        var components = URLComponents(string: Config.Endpoints.updatePushToken)
        components?.queryItems = [
            URLQueryItem(name: "userId", value: userId),
            URLQueryItem(name: "sessionId", value: sessionId)
        ]
        
        guard let url = components?.url else {
            print("❌ Invalid update token URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "pushToStartToken": token
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) {
                print("✅ Push-to-Start token registered with backend")
            } else {
                print("⚠️ Failed to register push-to-start token with backend")
            }
        } catch {
            print("❌ Error sending push-to-start token to backend: \(error)")
        }
    }
    
    // MARK: - Activity Push Token
    
    /// Sends the per-activity APNs update token to the backend so the server can
    /// push Live Activity updates directly to this specific activity.
    func sendActivityPushTokenToBackend(_ token: String, submissionId: String) async {
        guard let userId = UserManager.shared.currentUserId,
              let sessionId = UserManager.shared.currentSessionId else {
            print("⚠️ No user/session — cannot send activity push token for \(submissionId.prefix(8))")
            return
        }
        
        guard let url = URL(string: Config.Endpoints.registerActivityToken) else {
            print("❌ Invalid activity token URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "activityPushToken": token,
            "submissionId": submissionId,
            "userId": userId,
            "sessionId": sessionId
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) {
                print("✅ Activity push token registered for \(submissionId.prefix(8))")
            } else {
                print("⚠️ Failed to register activity push token for \(submissionId.prefix(8))")
            }
        } catch {
            print("❌ Error sending activity push token: \(error)")
        }
    }
    
    // MARK: - Handle Received Notifications
    
    func handleNotification(userInfo: [AnyHashable: Any]) {
        print("📬 Handling notification: \(userInfo)")
        
        // Handle start_processing from background APNs push (mirrors foreground path in AppDelegate)
        if let action = userInfo["action"] as? String, action == "start_processing" {
            print("🎬 Background start_processing notification — checking pending Live Activities")
            Task { @MainActor in
                if #available(iOS 16.1, *) {
                    await SharedReelManager.shared.checkAndStartPendingLiveActivities()
                }
            }
            return
        }
        
        if let factCheckId = userInfo["fact_check_id"] as? String {
            print("🔍 Fact check completed for ID: \(factCheckId)")
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
