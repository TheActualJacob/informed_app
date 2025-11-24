//
//  ShareViewController.swift
//  InformedShare
//
//  Created by Jacob Ryan on 11/24/25.
//

import UIKit
import Social
import UniformTypeIdentifiers
import UserNotifications

class ShareViewController: SLComposeServiceViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Customize the appearance
        title = "Share to Informed"
        placeholder = "Fact-check will start automatically after you tap Post"
        
        print("📱 Share Extension loaded")
    }

    override func isContentValid() -> Bool {
        // Always allow posting
        return true
    }

    override func didSelectPost() {
        print("📤 Share Extension: User tapped Post")
        
        // Extract and process the URL
        extractSharedURL { [weak self] url in
            guard let self = self else { return }
            
            if let url = url {
                print("🔗 Share Extension: Extracted URL: \(url)")
                
                // Start fact-check immediately in background
                self.startFactCheckInBackground(url: url)
                
            } else {
                print("❌ Share Extension: No URL found")
                self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            }
        }
    }

    override func configurationItems() -> [Any]! {
        // No additional configuration needed
        return []
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
                    if let url = item as? URL {
                        completion(url.absoluteString)
                    } else {
                        completion(nil)
                    }
                }
                return
            }
            
            // Check for plain text (Instagram sometimes shares as text)
            if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { (item, error) in
                    if let text = item as? String {
                        completion(text)
                    } else {
                        completion(nil)
                    }
                }
                return
            }
        }
        
        completion(nil)
    }
    
    // MARK: - Background Fact Check
    
    private func startFactCheckInBackground(url: String) {
        // Get user ID and device token from shared storage
        let appGroupName = "group.com.jacob.informed"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupName) else {
            print("⚠️ Could not access App Group: \(appGroupName)")
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            return
        }
        
        let userId = sharedDefaults.string(forKey: "stored_user_id") ?? "anonymous"
        let deviceToken = sharedDefaults.string(forKey: "stored_device_token") ?? "no_token"
        
        print("📤 Starting background fact-check...")
        print("   User ID: \(userId)")
        print("   Device Token: \(deviceToken)")
        
        // Create the API request
        guard let apiURL = URL(string: "http://192.168.1.238:5001/fact-check") else {
            print("❌ Invalid API URL")
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
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
            "source": "share_extension" // Track that this came from share extension
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("❌ Error encoding request: \(error)")
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            return
        }
        
        // Send the request and WAIT for complete response
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Network error: \(error.localizedDescription)")
                self.sendErrorNotification()
                self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response")
                self.sendErrorNotification()
                self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                return
            }
            
            if (200...299).contains(httpResponse.statusCode), let data = data {
                print("✅ Fact-check completed successfully!")
                
                // Parse the complete fact-check response
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("📦 Response data: \(json)")
                        
                        // Save the COMPLETE fact-check result to App Group
                        self.saveCompletedFactCheck(
                            submissionId: submissionId,
                            url: url,
                            factCheckData: json,
                            sharedDefaults: sharedDefaults
                        )
                        
                        // Send completion notification
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
            
            // Complete the extension
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
        
        task.resume()
        print("🚀 Fact-check request sent, waiting for response...")
    }
    
    // MARK: - Save Completed Fact-Check
    
    private func saveCompletedFactCheck(submissionId: String, url: String, factCheckData: [String: Any], sharedDefaults: UserDefaults) {
        // Get existing completed fact-checks or create new array
        var completedFactChecks = sharedDefaults.array(forKey: "completed_fact_checks") as? [[String: Any]] ?? []
        
        // Create completed fact-check entry with ALL the data
        var factCheck: [String: Any] = [
            "id": submissionId,
            "url": url,
            "submitted_at": Date().timeIntervalSince1970,
            "status": "completed"
        ]
        
        // Add all the fact-check data from backend
        factCheck.merge(factCheckData) { (_, new) in new }
        
        completedFactChecks.append(factCheck)
        sharedDefaults.set(completedFactChecks, forKey: "completed_fact_checks")
        
        print("💾 Saved completed fact-check to App Group")
    }
    
    // MARK: - Save Submission Info (DEPRECATED - keeping for compatibility)
    
    private func saveSubmissionInfo(submissionId: String, url: String, sharedDefaults: UserDefaults) {
        // Save the submission so main app can track it
        var submissions = sharedDefaults.array(forKey: "pending_submissions") as? [[String: Any]] ?? []
        
        let submission: [String: Any] = [
            "id": submissionId,
            "url": url,
            "submitted_at": Date().timeIntervalSince1970,
            "status": "processing"
        ]
        
        submissions.append(submission)
        sharedDefaults.set(submissions, forKey: "pending_submissions")
        
        print("💾 Saved submission to App Group for main app tracking")
    }
    
    // MARK: - Notifications
    
    private func sendCompletionNotification(url: String, title: String) {
        let center = UNUserNotificationCenter.current()
        
        let content = UNMutableNotificationContent()
        content.title = "Fact-Check Complete"
        content.body = "'\(title)' - Tap to view results"
        content.sound = .default
        content.badge = 1
        
        content.userInfo = [
            "instagram_url": url,
            "action": "fact_check_complete"
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "factcheck-complete-\(UUID().uuidString)",
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
    
    private func sendSuccessNotification(url: String) {
        // DEPRECATED - Use sendCompletionNotification instead
        sendCompletionNotification(url: url, title: "Your reel")
    }
    
    private func sendErrorNotification() {
        let center = UNUserNotificationCenter.current()
        
        let content = UNMutableNotificationContent()
        content.title = "Fact-Check Failed"
        content.body = "Unable to start fact-check. Please try again or paste the link in the app."
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
