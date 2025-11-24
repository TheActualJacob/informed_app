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
        placeholder = "Tap Post to queue this reel for fact-checking"
        
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
                
                // Save to App Group for main app to process
                self.saveSharedURL(url)
                
                // Send notification to user
                self.sendLocalNotification(for: url)
                
                print("✅ URL saved and notification sent!")
            } else {
                print("❌ Share Extension: No URL found")
            }
            
            // Complete the extension
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
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
    
    // MARK: - Save to App Group
    
    private func saveSharedURL(_ url: String) {
        // IMPORTANT: Replace "group.com.yourcompany.informed" with your ACTUAL App Group
        // Check: Xcode → Target → Signing & Capabilities → App Groups
        let appGroupName = "group.com.jacob.informed"
        
        guard let sharedDefaults = UserDefaults(suiteName: appGroupName) else {
            print("⚠️ Could not access App Group: \(appGroupName)")
            print("   Make sure App Group is configured in Xcode!")
            return
        }
        
        // Save the URL and timestamp
        // Use TimeInterval (Double) instead of Date object for better compatibility
        sharedDefaults.set(url, forKey: "pendingSharedURL")
        sharedDefaults.set(Date().timeIntervalSince1970, forKey: "pendingSharedURLDate")
        
        // Note: synchronize() is deprecated and can cause issues with App Groups
        // UserDefaults saves automatically to disk
        
        print("💾 Saved URL to App Group: \(appGroupName)")
        
        // Verify the save worked
        if let savedURL = sharedDefaults.string(forKey: "pendingSharedURL") {
            print("✅ Verified saved URL: \(savedURL)")
        } else {
            print("⚠️ Warning: Could not immediately verify saved URL")
        }
    }
    
    // MARK: - Send Local Notification
    
    private func sendLocalNotification(for url: String) {
        let center = UNUserNotificationCenter.current()
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "Instagram Reel Ready"
        content.body = "Tap to fact-check your Instagram reel"
        content.sound = .default
        content.badge = 1
        
        // Add URL to notification so we can process it when tapped
        content.userInfo = [
            "instagram_url": url,
            "action": "process_reel"
        ]
        
        // Create trigger (immediate)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        
        // Create request
        let request = UNNotificationRequest(
            identifier: "reel-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        // Schedule notification
        center.add(request) { error in
            if let error = error {
                print("❌ Failed to send notification: \(error)")
            } else {
                print("✅ Notification scheduled!")
            }
        }
    }
}
