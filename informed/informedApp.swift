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
        print("🔄 Checking for completed fact-checks from Share Extension...")
        
        // Sync completed fact-checks from App Group to main app
        Task { @MainActor in
            reelManager.syncCompletedFactChecksFromAppGroup()
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
