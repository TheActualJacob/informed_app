//
//  informedApp.swift
//  informed
//
//  Created by Jacob Ryan on 11/22/25.
//

import SwiftUI

@main
struct informedApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var userManager = UserManager()
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var reelManager = SharedReelManager.shared
    
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var alertMessage = ""
    
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        // 🧪 TEMPORARY: Clear stored credentials to test sign-up
        // Remove this after testing!
        UserDefaults.standard.removeObject(forKey: "stored_user_id")
        UserDefaults.standard.removeObject(forKey: "stored_username")
    }
    
    var body: some Scene {
        WindowGroup {
            if userManager.isAuthenticated {
                ContentView()
                    .environmentObject(userManager)
                    .environmentObject(notificationManager)
                    .environmentObject(reelManager)
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
                    }
                    .onChange(of: scenePhase) { oldPhase, newPhase in
                        // Check for shared URLs whenever app becomes active
                        if newPhase == .active {
                            print("🔄 App became active - checking for pending shared URLs")
                            checkForPendingSharedURL()
                        }
                    }
                    .task {
                        // Request notification permissions on first launch
                        if notificationManager.authorizationStatus == .notDetermined {
                            _ = await notificationManager.requestNotificationPermissions()
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
    
    // MARK: - Share Extension Support
    
    private func checkForPendingSharedURL() {
        // IMPORTANT: Replace with your actual App Group identifier
        // Same one used in ShareViewController.swift
        let appGroupName = "group.com.jacob.informed"
        
        guard let sharedDefaults = UserDefaults(suiteName: appGroupName) else {
            print("⚠️ Could not access App Group: \(appGroupName)")
            return
        }
        
        // Check if there's a pending URL from Share Extension
        if let urlString = sharedDefaults.string(forKey: "pendingSharedURL") {
            print("🔗 Found pending shared URL from Share Extension: \(urlString)")
            
            // Optional: Check timestamp to avoid processing very old URLs
            if let timestampObject = sharedDefaults.object(forKey: "pendingSharedURLDate") as? Double {
                let submittedDate = Date(timeIntervalSince1970: timestampObject)
                let age = Date().timeIntervalSince(submittedDate)
                
                print("⏱️ Shared URL is \(Int(age)) seconds old")
                
                // If URL is older than 1 hour, skip it (optional safeguard)
                if age > 3600 {
                    print("⏭️ Skipping old shared URL (older than 1 hour)")
                    sharedDefaults.removeObject(forKey: "pendingSharedURL")
                    sharedDefaults.removeObject(forKey: "pendingSharedURLDate")
                    return
                }
            }
            
            // Create a URL in the format your app expects
            if let encodedURL = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let deepLink = URL(string: "factcheckapp://share?url=\(encodedURL)") {
                
                // Clear the pending URL BEFORE processing to avoid re-processing
                sharedDefaults.removeObject(forKey: "pendingSharedURL")
                sharedDefaults.removeObject(forKey: "pendingSharedURLDate")
                // Note: synchronize() is deprecated - UserDefaults saves automatically
                
                print("✅ Cleared pending shared URL from App Group")
                
                // Now process the URL
                handleIncomingURL(deepLink)
            } else {
                print("❌ Failed to encode URL for processing")
            }
        } else {
            print("ℹ️ No pending shared URLs found")
        }
    }
    
    // MARK: - URL Handling
    
    private func handleIncomingURL(_ url: URL) {
        print("🔗 Received URL: \(url.absoluteString)")
        
        // Check if this is a share URL
        guard url.scheme == "factcheckapp",
              url.host == "share" else {
            print("⚠️ Unknown URL scheme or host")
            return
        }
        
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
    }
}
