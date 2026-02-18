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
    @State private var checkTimer: Timer?
    
    @Environment(\.scenePhase) private var scenePhase
    
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
                            
                            // Check IMMEDIATELY when becoming active (don't wait for timer)
                            checkForPendingSharedURL()
                            
                            // Then start periodic checking every 1 second while app is active
                            startPeriodicChecking()
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
    
    // MARK: - Periodic Checking
    
    private func startPeriodicChecking() {
        // Cancel existing timer if any
        stopPeriodicChecking()
        
        print("⏰ Starting periodic check for new submissions (every 1s)")
        
        // Check immediately
        checkForPendingSharedURL()
        
        // Then check every 1 second
        checkTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            checkForPendingSharedURL()
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
            let appGroupName = "group.com.jacob.informed"
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
        
        print("⚠️ Unknown URL host: \(url.host ?? "nil")")
    }
}
