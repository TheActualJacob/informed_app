//
//  ShareViewController.swift
//  InformedShare
//
//  Created by Jacob Ryan on 11/24/25.
//

import UIKit
import SwiftUI
import UniformTypeIdentifiers
import ActivityKit

class ShareViewController: UIViewController {
    
    private var hostingController: UIHostingController<ShareView>?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("📱 Share Extension loaded")
        
        // Make the view controller background transparent
        view.backgroundColor = .clear
        
        // Create SwiftUI view
        let isProUser = UserDefaults(suiteName: "group.rob")?.bool(forKey: "is_pro_user") ?? false
        let shareView = ShareView(
            onShare: { [weak self] in
                self?.handleShare()
            },
            onCancel: { [weak self] in
                self?.handleCancel()
            },
            currentTier: isProUser ? "pro" : "free"
        )
        
        // Embed SwiftUI view
        let hosting = UIHostingController(rootView: shareView)
        hosting.view.backgroundColor = .clear // Make hosting controller transparent too
        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.view.frame = view.bounds
        hosting.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hosting.didMove(toParent: self)
        hostingController = hosting
    }
    
    private func handleShare() {
        print("📤 Share Extension: User tapped Share")
        
        // Show processing state
        if let hosting = hostingController {
            let isProUser = UserDefaults(suiteName: "group.rob")?.bool(forKey: "is_pro_user") ?? false
            let processingView = ShareView(
                onShare: {},
                onCancel: {},
                isProcessing: true,
                currentTier: isProUser ? "pro" : "free"
            )
            hosting.rootView = processingView
        }
        
        // Extract and process the URL
        extractSharedURL { [weak self] url in
            guard let self = self else { return }
            
            if let url = url {
                print("🔗 Share Extension: Extracted URL: \(url)")
                
                // Pre-check usage limits before submitting
                self.checkUsageThenSubmit(url: url)
                
            } else {
                print("❌ Share Extension: No URL found")
                self.closeExtension()
            }
        }
    }
    
    private func handleCancel() {
        print("❌ Share Extension: User cancelled")
        closeExtension()
    }
    
    private func closeExtension() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
    
    // MARK: - Usage Pre-Check

    /// Checks /api/usage-status before firing the fact-check request.
    /// If the user has hit their daily or weekly limit, shows a "limit reached"
    /// screen in the share sheet instead of silently submitting and failing.
    private func checkUsageThenSubmit(url: String) {
        let appGroupName = "group.rob"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupName) else {
            // Can't read credentials — fall through to fire-and-forget (backend will reject if needed).
            submitAndClose(url: url)
            return
        }

        let userId = sharedDefaults.string(forKey: "stored_user_id") ?? "anonymous"
        let sessionId = sharedDefaults.string(forKey: "stored_session_id") ?? ""
        let backendURL = sharedDefaults.string(forKey: "backend_url") ?? "https://informed-production.up.railway.app"

        guard var components = URLComponents(string: "\(backendURL)/api/usage-status") else {
            submitAndClose(url: url)
            return
        }
        components.queryItems = [
            URLQueryItem(name: "userId", value: userId),
            URLQueryItem(name: "sessionId", value: sessionId)
        ]
        guard let statusURL = components.url else {
            submitAndClose(url: url)
            return
        }

        var request = URLRequest(url: statusURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 5 // Quick timeout — don't block the share sheet

        print("📊 [ShareExt] Checking usage before submit…")
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            // On any error (network, timeout, bad JSON) — optimistically submit.
            guard let data = data,
                  let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("⚠️ [ShareExt] Usage check failed — proceeding optimistically")
                DispatchQueue.main.async { self.submitAndClose(url: url) }
                return
            }

            let dailyUsed  = json["daily_used"]  as? Int ?? 0
            let dailyLimit = json["daily_limit"] as? Int ?? Int.max
            let weeklyUsed = json["weekly_used"] as? Int ?? 0
            let weeklyLimit = json["weekly_limit"] as? Int  // nil for pro
            let tier = json["tier"] as? String ?? "free"

            print("📊 [ShareExt] Usage: daily \(dailyUsed)/\(dailyLimit), weekly \(weeklyUsed)/\(weeklyLimit ?? -1), tier=\(tier)")

            let dailyExceeded = dailyUsed >= dailyLimit
            let weeklyExceeded: Bool = {
                guard let wl = weeklyLimit else { return false }
                return weeklyUsed >= wl
            }()

            if dailyExceeded || weeklyExceeded {
                let limitType = dailyExceeded ? "daily" : "weekly"
                print("🚫 [ShareExt] Limit reached (\(limitType)) — showing notification in share sheet")
                // Signal main app to show paywall on next foreground
                sharedDefaults.set(limitType, forKey: "pending_limit_reached_type")
                sharedDefaults.synchronize()
                DispatchQueue.main.async {
                    self.showLimitReached(limitType: limitType, tier: tier)
                }
            } else {
                DispatchQueue.main.async { self.submitAndClose(url: url) }
            }
        }.resume()
    }

    /// Normal path: fire the fact-check and close the extension.
    private func submitAndClose(url: String) {
        startFactCheckInBackground(url: url)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.closeExtension()
        }
    }

    /// Shows a limit-reached screen in the share sheet for a few seconds, then closes.
    private func showLimitReached(limitType: String, tier: String) {
        if let hosting = hostingController {
            let limitView = ShareView(
                onShare: {},
                onCancel: { [weak self] in self?.closeExtension() },
                limitReachedType: limitType,
                currentTier: tier
            )
            hosting.rootView = limitView
        }
    }

    // MARK: - Extract Shared URL
    
    private func extractSharedURL(completion: @escaping (String?) -> Void) {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = extensionItem.attachments else {
            completion(nil)
            return
        }
        
        // Look for URL attachment
        for attachment in attachments {
            if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { (item, error) in
                    DispatchQueue.main.async {
                        if let url = item as? URL {
                            completion(url.absoluteString)
                        } else {
                            completion(nil)
                        }
                    }
                }
                return
            }
            
            // Check for plain text (Instagram sometimes shares as text)
            if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { (item, error) in
                    DispatchQueue.main.async {
                        if let text = item as? String {
                            completion(text)
                        } else {
                            completion(nil)
                        }
                    }
                }
                return
            }
        }
        
        completion(nil)
    }
    
    // MARK: - Background Fact Check
    
    private func startFactCheckInBackground(url: String) {
        // Get user ID, session ID, and device token from shared storage
        let appGroupName = "group.rob"

        // ── App Group diagnostic ──────────────────────────────────────
        print("🔑 [ShareExt] Testing App Group access: \(appGroupName)")
        if let testDefaults = UserDefaults(suiteName: appGroupName) {
            testDefaults.set(Date().timeIntervalSince1970, forKey: "_share_ext_diag_ts")
            testDefaults.synchronize()
            let readBack = testDefaults.double(forKey: "_share_ext_diag_ts")
            print("✅ [ShareExt] App Group accessible, write+read test: \(readBack > 0 ? "PASSED" : "FAILED")")
        } else {
            print("❌ [ShareExt] App Group returned nil — NOT PROVISIONED for this extension")
        }
        // ─────────────────────────────────────────────────────────────

        guard let sharedDefaults = UserDefaults(suiteName: appGroupName) else {
            print("⚠️ Could not access App Group: \(appGroupName)")
            return
        }
    
        
        let userId = sharedDefaults.string(forKey: "stored_user_id") ?? "anonymous"
        let sessionId = sharedDefaults.string(forKey: "stored_session_id") ?? ""
        let deviceToken = sharedDefaults.string(forKey: "stored_device_token") ?? "no_token"
        
        print("📤 Starting background fact-check...")
        print("   User ID: \(userId)")
        print("   Session ID: \(sessionId)")
        print("   Device Token: \(deviceToken)")
        
        // Get backend URL from shared config (main app syncs this on launch via Config.syncBackendURLToSharedStorage)
        let backendURL = sharedDefaults.string(forKey: "backend_url") ?? "https://informed-production.up.railway.app"
        print("🌐 [ShareExt] Backend URL: \(backendURL)")

        // Create the API URL with query parameters
        guard var urlComponents = URLComponents(string: "\(backendURL)/fact-check") else {
            print("❌ Invalid API URL")
            return
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "userId", value: userId),
            URLQueryItem(name: "sessionId", value: sessionId)
        ]
        
        guard let apiURL = urlComponents.url else {
            print("❌ Failed to construct API URL with query parameters")
            return
        }
        
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300 // 5 minutes
        
        let liveActivityToken = sharedDefaults.string(forKey: "live_activity_push_to_start_token")
        
        let submissionId = UUID().uuidString
        var body: [String: Any] = [
            "link": url,
            "user_id": userId,
            "device_token": deviceToken,
            "submission_id": submissionId,
            "source": "share_extension"
        ]
        
        // Include the push-to-start token if available!
        if let laToken = liveActivityToken {
            body["push_to_start_token"] = laToken
            print("🔑 Including Push-To-Start Token in request: \(laToken.prefix(8))...")
        } else {
            print("⚠️ No push-to-start token in App Group — Dynamic Island will appear when app is foregrounded")
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("❌ Error encoding request: \(error)")
            return
        }
        
        // Save pending submission immediately
        savePendingSubmission(submissionId: submissionId, url: url, sharedDefaults: sharedDefaults)
        
        // 🚀 START LIVE ACTIVITY RIGHT NOW (requires paid developer account)
        // This shows the Dynamic Island immediately, before the main app is opened.
        if #available(iOS 16.1, *) {
            startLiveActivity(submissionId: submissionId, url: url)
        }
        
        // Set a flag to trigger the main app to check immediately
        sharedDefaults.set(Date().timeIntervalSince1970, forKey: "new_submission_timestamp")
        sharedDefaults.set(true, forKey: "hasPendingReel")
        sharedDefaults.synchronize()
        print("🚩 Set new_submission_timestamp flag for main app")
        
        // ⚠️ IMPORTANT: extensionContext?.open() requires a PAID Apple Developer Account
        //
        // This feature allows the Share Extension to automatically open the main app,
        // triggering the Dynamic Island immediately. However, it requires:
        // 1. Paid Apple Developer Program membership ($99/year)
        // 2. Proper App Group provisioning and code signing
        // 3. Valid provisioning profiles for both app and extension
        //
        // With a FREE account, this call will SILENTLY FAIL (success = false).
        // The app will still work - users just need to manually switch back to the app
        // after sharing, and the Dynamic Island will appear then.
        //
        // FALLBACK: The scenePhase observer in informedApp.swift will detect when
        // the user manually returns to the app and trigger checkForPendingSharedURL().
        
        if let appURL = URL(string: "factcheckapp://") {
            // extensionContext?.open is the only supported path for Share Extensions on modern iOS.
            extensionContext?.open(appURL, completionHandler: { success in
                if success {
                    print("✅ Successfully opened main app via extensionContext!")
                } else {
                    print("⚠️ Could not auto-open main app. User must manually open it.")
                }
            })
        }
        
        // Send Darwin notification as backup (works across app boundaries)
        let notificationName = "com.jacob.informed.newSubmission" as CFString
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(center, CFNotificationName(notificationName), nil, nil, true)
        print("📡 Sent Darwin notification: \(notificationName)")
        
        // Send the request in background (fire and forget)
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Network error: \(error.localizedDescription)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response")
                return
            }
            
            if (200...299).contains(httpResponse.statusCode), let data = data {
                print("✅ Fact-check request accepted by backend!")
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("📦 Response data: \(json)")
                        
                        // Check if backend returned a submission_id for progress tracking
                        if let backendSubmissionId = json["submission_id"] as? String {
                            print("🆔 Backend returned submission_id: \(backendSubmissionId)")
                            
                            // Update the pending submission with backend's ID
                            self.updatePendingSubmissionId(
                                localId: submissionId,
                                backendId: backendSubmissionId,
                                sharedDefaults: sharedDefaults
                            )
                            
                            // Store flag to trigger main app to start progress polling
                            sharedDefaults.set(backendSubmissionId, forKey: "latest_submission_id_for_polling")
                            sharedDefaults.synchronize()
                            print("🚩 Set polling flag for main app")
                        }
                        
                        // If fact-check is already completed (synchronous response), save it
                        if let status = json["status"] as? String, status == "completed" {
                            self.saveCompletedFactCheck(
                                submissionId: submissionId,
                                url: url,
                                factCheckData: json,
                                sharedDefaults: sharedDefaults
                            )
                            print("✅ Fact-check completed synchronously and saved")
                        } else {
                            print("⏳ Fact-check is processing asynchronously")
                        }
                    }
                } catch {
                    print("❌ Error parsing response: \(error)")
                }
            } else {
                print("❌ Server error: \(httpResponse.statusCode)")
                if let data = data {
                    if let errorText = String(data: data, encoding: .utf8) {
                        print("   Error details: \(errorText)")
                    }
                    // Detect terminal errors immediately from the extension's own POST response.
                    // Update the island to show the error right away instead of leaving it
                    // stuck at 10% until the main app's polling fallback discovers it.
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        let errorKey = json["error"] as? String ?? ""
                        let errorType = json["error_type"] as? String ?? ""
                        
                        if errorKey == "limit_reached" {
                            let limitType = json["type"] as? String ?? "daily"
                            print("⚠️ [ShareExtension] limit_reached (\(limitType)) — failing island for \(submissionId.prefix(8))")
                            if #available(iOS 16.1, *) {
                                self.failLiveActivity(submissionId: submissionId, message: "Daily limit reached")
                            }
                            // Remove from pending so the main app doesn't start polling a 404 forever.
                            if let defaults = UserDefaults(suiteName: "group.rob") {
                                if var subs = defaults.array(forKey: "pending_submissions") as? [[String: Any]] {
                                    subs.removeAll { ($0["id"] as? String) == submissionId }
                                    defaults.set(subs, forKey: "pending_submissions")
                                }
                                // Signal the main app to show the upgrade paywall on next foreground.
                                defaults.set(limitType, forKey: "pending_limit_reached_type")
                                defaults.synchronize()
                                print("🗑️ [ShareExtension] Removed \(submissionId.prefix(8)) from pending_submissions (limit_reached)")
                                print("💾 [ShareExtension] Wrote pending_limit_reached_type=\(limitType) — main app will show paywall on foreground")
                            }
                        } else if errorType == "invalid_url" || errorType == "unsupported_platform" {
                            print("⚠️ [ShareExtension] \(errorType) — failing island for \(submissionId.prefix(8))")
                            if #available(iOS 16.1, *) {
                                self.failLiveActivity(submissionId: submissionId, message: "Unsupported URL format")
                            }
                            if let defaults = UserDefaults(suiteName: "group.rob") {
                                if var subs = defaults.array(forKey: "pending_submissions") as? [[String: Any]] {
                                    subs.removeAll { ($0["id"] as? String) == submissionId }
                                    defaults.set(subs, forKey: "pending_submissions")
                                }
                                defaults.synchronize()
                                print("🗑️ [ShareExtension] Removed \(submissionId.prefix(8)) from pending_submissions (\(errorType))")
                            }
                        }
                    }
                }
            }
        }
        
        task.resume()
        print("🚀 Fact-check request sent in background")
    }
    
    // MARK: - Save Pending Submission
    
    private func savePendingSubmission(submissionId: String, url: String, sharedDefaults: UserDefaults) {
        var submissions = sharedDefaults.array(forKey: "pending_submissions") as? [[String: Any]] ?? []
        
        let submission: [String: Any] = [
            "id": submissionId,
            "url": url,
            "submitted_at": Date().timeIntervalSince1970,
            "status": "processing"
        ]
        
        submissions.append(submission)
        sharedDefaults.set(submissions, forKey: "pending_submissions")
        sharedDefaults.synchronize() // Force immediate write
        
        print("💾 Saved pending submission to App Group")
        print("   Total submissions now: \(submissions.count)")
        print("   Submission ID: \(submissionId)")
        print("   URL: \(url)")
    }
    
    /// Updates a pending submission with backend's submission_id for progress tracking
    private func updatePendingSubmissionId(localId: String, backendId: String, sharedDefaults: UserDefaults) {
        guard var submissions = sharedDefaults.array(forKey: "pending_submissions") as? [[String: Any]] else {
            return
        }
        
        // Find and update the submission with matching local ID
        for (index, var submission) in submissions.enumerated() {
            if submission["id"] as? String == localId {
                submission["backend_id"] = backendId
                submissions[index] = submission
                sharedDefaults.set(submissions, forKey: "pending_submissions")
                sharedDefaults.synchronize()
                print("✅ Updated submission \(localId) with backend ID: \(backendId)")
                return
            }
        }
        
        print("⚠️ Could not find submission \(localId) to update with backend ID")
    }
    
    // MARK: - Save Completed Fact-Check
    
    private func saveCompletedFactCheck(submissionId: String, url: String, factCheckData: [String: Any], sharedDefaults: UserDefaults) {
        var completedFactChecks = sharedDefaults.array(forKey: "completed_fact_checks") as? [[String: Any]] ?? []
        
        var factCheck: [String: Any] = [
            "id": submissionId,
            "url": url,
            "submitted_at": Date().timeIntervalSince1970,
            "status": "completed"
        ]
        
        // Clean the fact check data to remove NSNull and other non-property-list objects
        let cleanedFactCheckData = cleanDictionaryForUserDefaults(factCheckData)
        
        factCheck.merge(cleanedFactCheckData) { (_, new) in new }
        completedFactChecks.append(factCheck)
        sharedDefaults.set(completedFactChecks, forKey: "completed_fact_checks")
        
        // Remove from pending
        if var pending = sharedDefaults.array(forKey: "pending_submissions") as? [[String: Any]] {
            pending.removeAll { ($0["id"] as? String) == submissionId }
            sharedDefaults.set(pending, forKey: "pending_submissions")
        }
        
        // Set completion flag to trigger main app to update Live Activity
        sharedDefaults.set(Date().timeIntervalSince1970, forKey: "fact_check_completed_timestamp")
        sharedDefaults.synchronize()
        print("🚩 Set fact_check_completed_timestamp flag for main app")
        
        // Send Darwin notification to wake main app and update Live Activity
        let notificationName = "com.jacob.informed.factCheckComplete" as CFString
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(center, CFNotificationName(notificationName), nil, nil, true)
        print("📡 Sent Darwin notification: \(notificationName) for completed fact-check")
        
        print("💾 Saved completed fact-check to App Group")
    }
    
    // MARK: - Clean Dictionary for UserDefaults
    
    /// Recursively cleans a dictionary to remove NSNull values and ensure all values are property-list compatible
    private func cleanDictionaryForUserDefaults(_ dict: [String: Any]) -> [String: Any] {
        var cleaned: [String: Any] = [:]
        
        for (key, value) in dict {
            if value is NSNull {
                // Convert NSNull to empty string or skip entirely
                cleaned[key] = ""
            } else if let nestedDict = value as? [String: Any] {
                // Recursively clean nested dictionaries
                cleaned[key] = cleanDictionaryForUserDefaults(nestedDict)
            } else if let array = value as? [Any] {
                // Clean arrays
                cleaned[key] = cleanArrayForUserDefaults(array)
            } else if isPropertyListCompatible(value) {
                // Keep property-list compatible values
                cleaned[key] = value
            } else {
                // Convert non-compatible values to string representation
                cleaned[key] = String(describing: value)
            }
        }
        
        return cleaned
    }
    
    /// Recursively cleans an array to ensure all elements are property-list compatible
    private func cleanArrayForUserDefaults(_ array: [Any]) -> [Any] {
        return array.compactMap { element -> Any? in
            if element is NSNull {
                return ""
            } else if let dict = element as? [String: Any] {
                return cleanDictionaryForUserDefaults(dict)
            } else if let nestedArray = element as? [Any] {
                return cleanArrayForUserDefaults(nestedArray)
            } else if isPropertyListCompatible(element) {
                return element
            } else {
                return String(describing: element)
            }
        }
    }
    
    /// Checks if a value is property-list compatible
    private func isPropertyListCompatible(_ value: Any) -> Bool {
        return value is String ||
               value is Int ||
               value is Double ||
               value is Float ||
               value is Bool ||
               value is Date ||
               value is Data
    }
    
    // MARK: - Live Activity
    
    /// Starts a Live Activity (and therefore Dynamic Island) directly from the
    /// Share Extension.  This requires a PAID Apple Developer account so that
    /// the extension shares the same App Group entitlement as the main app.
    /// The activity is visible immediately – no need to open the main app first.
    @available(iOS 16.1, *)
    /// Looks up the Live Activity for `submissionId` and transitions it to the `.failed` error
    /// state. Auto-dismisses after 8 seconds so the island doesn't linger.
    @available(iOS 16.1, *)
    private func failLiveActivity(submissionId: String, message: String) {
        guard let activity = Activity<ReelProcessingActivityAttributes>.activities.first(where: {
            $0.attributes.submissionId == submissionId
        }) else {
            print("⚠️ [ShareExtension] failLiveActivity: no activity found for \(submissionId.prefix(8))")
            return
        }
        let failedState = ReelProcessingActivityAttributes.ContentState(
            status: .failed,
            progress: activity.content.state.progress,
            statusMessage: message,
            title: nil, verdict: nil,
            thumbnailURL: nil, estimatedSecondsRemaining: 0
        )
        Task {
            await activity.update(ActivityContent(state: failedState, staleDate: nil))
            print("✅ [ShareExtension] Updated island to failed state: \(message)")
            // Auto-dismiss after 8 seconds so it doesn't linger.
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            await activity.end(ActivityContent(state: failedState, staleDate: nil), dismissalPolicy: .immediate)
        }
    }

    private func startLiveActivity(submissionId: String, url: String) {
        print("🚀 [ShareExtension] Starting Live Activity for: \(submissionId)")
        
        let authInfo = ActivityAuthorizationInfo()
        guard authInfo.areActivitiesEnabled else {
            print("⚠️ [ShareExtension] Live Activities not enabled – skipping")
            return
        }
        
        // End any existing activity for the same submission to avoid duplicates.
        for existing in Activity<ReelProcessingActivityAttributes>.activities
            where existing.attributes.submissionId == submissionId {
            Task { await existing.end(existing.content, dismissalPolicy: .immediate) }
        }
        
        let attributes = ReelProcessingActivityAttributes(
            reelURL: url,
            submissionId: submissionId,
            startTime: Date(),
            isPro: UserDefaults(suiteName: "group.rob")?.bool(forKey: "is_pro_user") ?? false
        )
        
        let initialState = ReelProcessingActivityAttributes.ContentState(
            status: .submitting,
            progress: 0.1,
            statusMessage: "Starting fact-check…",
            title: nil,
            verdict: nil,
            thumbnailURL: nil,
            estimatedSecondsRemaining: 90
        )
        
        // Attempt 1: pushType: .token so we get a push token for server-side updates.
        // This requires aps-environment in the extension entitlements. If that's missing,
        // ActivityKit throws and we fall back to pushType: nil so the Dynamic Island at
        // least appears. The main app will "upgrade" to a token-backed activity on first
        // foreground (see startActivity in ReelProcessingActivity.swift).
        let activity: Activity<ReelProcessingActivityAttributes>?
        do {
            activity = try Activity<ReelProcessingActivityAttributes>.request(
                attributes: attributes,
                content: ActivityContent(state: initialState, staleDate: nil),
                pushType: .token
            )
            print("✅ [ShareExtension] Live Activity started with push token support! id=\(activity!.id)")
        } catch {
            print("⚠️ [ShareExtension] pushType:.token failed (\(error.localizedDescription)) — retrying with pushType:nil")
            do {
                activity = try Activity<ReelProcessingActivityAttributes>.request(
                    attributes: attributes,
                    content: ActivityContent(state: initialState, staleDate: nil),
                    pushType: nil
                )
                print("✅ [ShareExtension] Live Activity started (no push token) id=\(activity!.id)")
                print("   ℹ️ Dynamic Island visible — push updates will activate when user opens app")
            } catch {
                print("❌ [ShareExtension] Could not start Live Activity at all: \(error.localizedDescription)")
                return
            }
        }

        guard let activity else { return }

        // Fast path: read the synchronous pushToken property immediately after creation.
        // On some iOS versions the token is already populated on the Activity object the
        // moment request() returns. If available, store and send it right away — this
        // avoids losing the token if the extension process is killed before the async
        // pushTokenUpdates sequence has a chance to emit.
        if let immediateToken = activity.pushToken {
            let immediateTokenString = immediateToken.map { String(format: "%02x", $0) }.joined()
            print("🔑 [ShareExtension] Immediate push token for \(submissionId.prefix(8)): \(immediateTokenString)")
            if let sharedDefaults = UserDefaults(suiteName: "group.rob") {
                sharedDefaults.set(immediateTokenString, forKey: "activity_push_token_\(submissionId)")
                print("💾 [ShareExtension] Saved immediate push token to App Group")
            }
            Task {
                await sendActivityPushTokenToBackend(immediateTokenString, submissionId: submissionId)
            }
        }

        // Observe push token updates and persist them to App Group so the main app
        // can register the token with the backend when it next becomes active.
        Task {
            for await pushToken in activity.pushTokenUpdates {
                let tokenString = pushToken.map { String(format: "%02x", $0) }.joined()
                print("🔑 [ShareExtension] Activity push token for \(submissionId.prefix(8)): \(tokenString)")
                if let sharedDefaults = UserDefaults(suiteName: "group.rob") {
                    sharedDefaults.set(tokenString, forKey: "activity_push_token_\(submissionId)")
                    print("💾 [ShareExtension] Saved activity push token to App Group")
                }
                await sendActivityPushTokenToBackend(tokenString, submissionId: submissionId)
            }
        }
    }
    
    /// Sends the per-activity APNs push token to the backend directly from the Share Extension.
    private func sendActivityPushTokenToBackend(_ token: String, submissionId: String) async {
        let appGroupName = "group.rob"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupName),
              let userId = sharedDefaults.string(forKey: "stored_user_id"),
              let sessionId = sharedDefaults.string(forKey: "stored_session_id") else {
            print("⚠️ [ShareExtension] No credentials — activity push token will be sent by main app on next launch")
            return
        }
        
        let backendURL = sharedDefaults.string(forKey: "backend_url") ?? "https://informed-production.up.railway.app"
        guard let url = URL(string: "\(backendURL)/api/register-activity-token") else { return }
        
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
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                print("✅ [ShareExtension] Activity push token registered with backend for \(submissionId.prefix(8))")
            } else {
                print("⚠️ [ShareExtension] Backend rejected activity push token")
            }
        } catch {
            print("❌ [ShareExtension] Error sending activity push token: \(error)")
        }
    }
}

// MARK: - SwiftUI Share View

struct ShareView: View {
    let onShare: () -> Void
    let onCancel: () -> Void
    var isProcessing: Bool = false
    var limitReachedType: String? = nil   // "daily" or "weekly" when at limit
    var currentTier: String = "free"
    
    private var isPro: Bool { currentTier == "pro" }
    
    @State private var scale: CGFloat = 0.95  // Start closer to full size
    @State private var opacity: Double = 0
    
    var body: some View {
        ZStack {
            // Blur background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Main card
                VStack(spacing: 24) {
                    if let limitType = limitReachedType {
                        // Limit reached state
                        VStack(spacing: 20) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.orange,
                                                Color.red.opacity(0.85)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 64, height: 64)
                                
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(spacing: 8) {
                                Text(limitType == "daily" ? "Daily Limit Reached" : "Weekly Limit Reached")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text(currentTier == "pro"
                                     ? "You've used all your fact-checks for \(limitType == "daily" ? "today" : "this week"). Check back \(limitType == "daily" ? "tomorrow" : "next week")!"
                                     : "You've used all your free fact-checks for \(limitType == "daily" ? "today" : "this week"). Upgrade to Pro for more!")
                                    .font(.system(size: 15))
                                    .foregroundColor(.white.opacity(0.8))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 8)
                            }
                            
                            VStack(spacing: 12) {
                                if currentTier != "pro" {
                                    Button(action: onCancel) {
                                        HStack {
                                            Image(systemName: "star.fill")
                                            Text("Upgrade to Pro")
                                                .fontWeight(.semibold)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(Color.white)
                                        .foregroundColor(.orange)
                                        .cornerRadius(14)
                                    }
                                }
                                
                                Button(action: onCancel) {
                                    Text("Dismiss")
                                        .fontWeight(.medium)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 32)
                        
                    } else if isProcessing {
                        // Processing state
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(isPro ? Color(red: 0.85, green: 0.68, blue: 0.20) : .white)
                            
                            HStack(spacing: 4) {
                                Text("Starting fact-check...")
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundColor(.white)
                                if isPro {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(Color(red: 0.85, green: 0.68, blue: 0.20))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                        
                    } else {
                        // Ready state
                        VStack(spacing: 20) {
                            // Icon
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: isPro
                                                ? [Color(red: 0.85, green: 0.68, blue: 0.20),
                                                   Color(red: 0.72, green: 0.53, blue: 0.10)]
                                                : [Color(red: 0, green: 0.75, blue: 0.85),
                                                   Color(red: 0.15, green: 0.35, blue: 0.95)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 64, height: 64)
                                
                                Image(systemName: isPro ? "star.circle.fill" : "checkmark.shield.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.white)
                            }
                            
                            // Title and description
                            VStack(spacing: 8) {
                                HStack(spacing: 6) {
                                    Text(isPro ? "+informed Pro" : "Fact-Check This Reel")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(.white)
                                    if isPro {
                                        Text("PRO")
                                            .font(.system(size: 10, weight: .heavy))
                                            .foregroundColor(Color(red: 0.85, green: 0.68, blue: 0.20))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.white.opacity(0.2))
                                            .clipShape(Capsule())
                                    }
                                }
                                
                                Text(isPro
                                     ? "Priority fact-checking with your Pro account"
                                     : "We'll analyze this content and notify you when it's ready")
                                    .font(.system(size: 15))
                                    .foregroundColor(.white.opacity(0.8))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 8)
                            }
                            
                            // Buttons
                            VStack(spacing: 12) {
                                Button(action: onShare) {
                                    HStack {
                                        Image(systemName: isPro ? "star.fill" : "paperplane.fill")
                                        Text("Start Fact-Check")
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.white)
                                    .foregroundColor(isPro
                                        ? Color(red: 0.72, green: 0.53, blue: 0.10)
                                        : Color(red: 0.15, green: 0.35, blue: 0.95))
                                    .cornerRadius(14)
                                }
                                
                                Button(action: onCancel) {
                                    Text("Cancel")
                                        .fontWeight(.medium)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 32)
                    }
                }
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: limitReachedType != nil
                                        ? [Color.orange.opacity(0.95), Color.red.opacity(0.85)]
                                        : isPro
                                            ? [Color(red: 0.12, green: 0.12, blue: 0.14).opacity(0.97),
                                               Color(red: 0.08, green: 0.08, blue: 0.10).opacity(0.97)]
                                            : [Color(red: 0.15, green: 0.35, blue: 0.95).opacity(0.95),
                                               Color(red: 0, green: 0.75, blue: 0.85).opacity(0.95)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        // Gold border for pro users
                        if isPro && limitReachedType == nil {
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color(red: 0.85, green: 0.68, blue: 0.20),
                                                 Color(red: 0.72, green: 0.53, blue: 0.10),
                                                 Color(red: 0.85, green: 0.68, blue: 0.20)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        }
                    }
                    .shadow(color: isPro && limitReachedType == nil
                            ? Color(red: 0.85, green: 0.68, blue: 0.20).opacity(0.25)
                            : .black.opacity(0.3),
                            radius: 30, x: 0, y: 15)
                )
                .padding(.horizontal, 20)
                .scaleEffect(scale)
                .opacity(opacity)
                
                Spacer()
                    .frame(height: 40)
            }
        }
        .onAppear {
            // Faster, snappier entrance animation
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}

#Preview {
    ShareView(
        onShare: {},
        onCancel: {}
    )
}
