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
        let terminalIds = reelManager.reels
            .filter { $0.status == .completed || $0.status == .failed }
            .map { $0.id }
        for submissionId in terminalIds {
            await ReelProcessingActivityManager.shared.endActivity(
                submissionId: submissionId,
                dismissalPolicy: .immediate
            )
        }
        // Also end any system activities we've lost track of that are in a terminal state
        for activity in Activity<ReelProcessingActivityAttributes>.activities {
            if activity.activityState == .ended || activity.activityState == .dismissed {
                await activity.end(
                    ActivityContent(state: activity.content.state, staleDate: nil),
                    dismissalPolicy: .immediate
                )
            }
        }
        print("✅ [App] Dismissed completed/failed Live Activities on foreground")
    }

    // MARK: - Periodic Checking
    
    private func startPeriodicChecking() {
        // Cancel existing timer if any
        stopPeriodicChecking()
        
        print("⏰ Starting periodic check for new submissions (every 1s)")
        
        // Check immediately
        checkForPendingSharedURL()
        
        // Then check every 1 second, but auto-stop when nothing is pending
        checkTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            checkForPendingSharedURL()
            // Stop polling once there are no more pending share-extension submissions
            if reelManager.activeProcessingURL == nil {
                stopPeriodicChecking()
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

        // 3. If the reel is completed, fire ShowFactCheckDetail after a brief delay
        //    so SharedReelsView has time to mount before being asked to navigate
        if let reel = reelManager.reels.first(where: { $0.id == submissionId }),
           reel.status == .completed,
           let factCheckData = reel.factCheckData {
            let item = factCheckData.toFactCheckItem(originalLink: reel.url)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NotificationCenter.default.post(
                    name: NSNotification.Name("ShowFactCheckDetail"),
                    object: nil,
                    userInfo: ["factCheckItem": item]
                )
            }
        }

        HapticManager.successImpact()
    }
}
