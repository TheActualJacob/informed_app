//
//  ShareViewController.swift
//  InformedShare
//
//  Created by Jacob Ryan on 11/24/25.
//

import UIKit
import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

class ShareViewController: UIViewController {
    
    private var hostingController: UIHostingController<ShareView>?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("📱 Share Extension loaded")
        
        // Make the view controller background transparent
        view.backgroundColor = .clear
        
        // Create SwiftUI view
        let shareView = ShareView(
            onShare: { [weak self] in
                self?.handleShare()
            },
            onCancel: { [weak self] in
                self?.handleCancel()
            }
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
            let processingView = ShareView(
                onShare: {},
                onCancel: {},
                isProcessing: true
            )
            hosting.rootView = processingView
        }
        
        // Extract and process the URL
        extractSharedURL { [weak self] url in
            guard let self = self else { return }
            
            if let url = url {
                print("🔗 Share Extension: Extracted URL: \(url)")
                
                // Start fact-check in background and close IMMEDIATELY
                self.startFactCheckInBackground(url: url)
                
                // Close after brief success animation (reduced from 0.5s to 0.3s)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.closeExtension()
                }
                
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
        let appGroupName = "group.com.jacob.informed"
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
        
        // Get backend URL from shared config
        let backendURL = sharedDefaults.string(forKey: "backend_url") ?? "http://172.20.10.2:5001"
        
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
        
        let submissionId = UUID().uuidString
        let body: [String: Any] = [
            "link": url,
            "user_id": userId,
            "device_token": deviceToken,
            "submission_id": submissionId,
            "source": "share_extension"
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("❌ Error encoding request: \(error)")
            return
        }
        
        // Save pending submission immediately
        savePendingSubmission(submissionId: submissionId, url: url, sharedDefaults: sharedDefaults)
        
        // Send the request in background (fire and forget)
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Network error: \(error.localizedDescription)")
                self.sendErrorNotification()
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response")
                self.sendErrorNotification()
                return
            }
            
            if (200...299).contains(httpResponse.statusCode), let data = data {
                print("✅ Fact-check completed successfully!")
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("📦 Response data: \(json)")
                        
                        self.saveCompletedFactCheck(
                            submissionId: submissionId,
                            url: url,
                            factCheckData: json,
                            sharedDefaults: sharedDefaults
                        )
                        
                        let title = json["title"] as? String ?? "Fact-Check Complete"
                        self.sendCompletionNotification(url: url, title: title)
                        
                        print("✅ Fact-check saved and user notified")
                    }
                } catch {
                    print("❌ Error parsing response: \(error)")
                    self.sendErrorNotification()
                }
            } else {
                print("❌ Server error: \(httpResponse.statusCode)")
                if let data = data, let errorText = String(data: data, encoding: .utf8) {
                    print("   Error details: \(errorText)")
                }
                self.sendErrorNotification()
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
        
        print("💾 Saved pending submission to App Group")
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
    
    // MARK: - Notifications
    
    private func sendCompletionNotification(url: String, title: String) {
        let center = UNUserNotificationCenter.current()
        
        let content = UNMutableNotificationContent()
        content.title = "✅ Fact-Check Complete"
        content.body = "Tap to view results for: \(title)"
        content.sound = .default
        content.badge = 1
        
        // Generate a unique ID for this reel
        let reelId = UUID().uuidString
        
        content.userInfo = [
            "instagram_url": url,
            "action": "fact_check_complete",
            "reel_id": reelId,
            "reel_title": title
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "factcheck-complete-\(reelId)",
            content: content,
            trigger: trigger
        )
        
        center.add(request) { error in
            if let error = error {
                print("❌ Failed to send completion notification: \(error)")
            } else {
                print("✅ Completion notification sent!")
            }
        }
    }
    
    private func sendErrorNotification() {
        let center = UNUserNotificationCenter.current()
        
        let content = UNMutableNotificationContent()
        content.title = "❌ Fact-Check Failed"
        content.body = "Unable to process this reel. Please try again."
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "factcheck-error-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        center.add(request) { error in
            if let error = error {
                print("❌ Failed to send error notification: \(error)")
            }
        }
    }
}

// MARK: - SwiftUI Share View

struct ShareView: View {
    let onShare: () -> Void
    let onCancel: () -> Void
    var isProcessing: Bool = false
    
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
                    if isProcessing {
                        // Processing state
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(.white)
                            
                            Text("Starting fact-check...")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.white)
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
                                            colors: [
                                                Color(red: 0, green: 0.75, blue: 0.85),
                                                Color(red: 0.15, green: 0.35, blue: 0.95)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 64, height: 64)
                                
                                Image(systemName: "checkmark.shield.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.white)
                            }
                            
                            // Title and description
                            VStack(spacing: 8) {
                                Text("Fact-Check This Reel")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text("We'll analyze this content and notify you when it's ready")
                                    .font(.system(size: 15))
                                    .foregroundColor(.white.opacity(0.8))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 8)
                            }
                            
                            // Buttons
                            VStack(spacing: 12) {
                                Button(action: onShare) {
                                    HStack {
                                        Image(systemName: "paperplane.fill")
                                        Text("Start Fact-Check")
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.white)
                                    .foregroundColor(Color(red: 0.15, green: 0.35, blue: 0.95))
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
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.15, green: 0.35, blue: 0.95).opacity(0.95),
                                    Color(red: 0, green: 0.75, blue: 0.85).opacity(0.95)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 15)
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
