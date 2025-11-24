//
//  ShareViewController.swift
//  InformedShare
//
//  Created by Jacob Ryan on 11/24/25.
//

import UIKit
import Social
import UniformTypeIdentifiers

class ShareViewController: SLComposeServiceViewController {
    
    private var sharedURL: String?

    override func isContentValid() -> Bool {
        // Always return true - we'll validate the URL when processing
        return true
    }

    override func didSelectPost() {
        // This is called after the user selects Post
        print("📤 Share Extension: User tapped Post")
        
        // Extract the URL from the shared content
        extractSharedURL { [weak self] url in
            guard let self = self, let url = url else {
                print("❌ Share Extension: No URL found")
                self?.showError("No URL found in shared content")
                return
            }
            
            print("🔗 Share Extension: Extracted URL: \(url)")
            
            // Store the URL in shared UserDefaults (App Group)
            self.saveSharedURL(url)
            
            // Open the main app to process it
            self.openMainApp(with: url)
            
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
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem else {
            completion(nil)
            return
        }
        
        guard let attachments = extensionItem.attachments else {
            completion(nil)
            return
        }
        
        // Look through all attachments for a URL
        for attachment in attachments {
            // Check for URL type
            if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { (item, error) in
                    if let error = error {
                        print("❌ Error loading URL: \(error)")
                        completion(nil)
                        return
                    }
                    
                    if let url = item as? URL {
                        completion(url.absoluteString)
                    } else if let data = item as? Data, let urlString = String(data: data, encoding: .utf8) {
                        completion(urlString)
                    } else {
                        completion(nil)
                    }
                }
                return
            }
            
            // Check for plain text (sometimes Instagram shares as text)
            if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { (item, error) in
                    if let error = error {
                        print("❌ Error loading text: \(error)")
                        completion(nil)
                        return
                    }
                    
                    if let text = item as? String {
                        // Check if the text contains a URL
                        if let url = self.extractURLFromText(text) {
                            completion(url)
                        } else {
                            completion(text)
                        }
                    } else {
                        completion(nil)
                    }
                }
                return
            }
        }
        
        completion(nil)
    }
    
    private func extractURLFromText(_ text: String) -> String? {
        // Try to find a URL in the text
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        
        if let match = matches?.first, let range = Range(match.range, in: text) {
            return String(text[range])
        }
        
        return nil
    }
    
    // MARK: - Save to App Group
    
    private func saveSharedURL(_ url: String) {
        // Save to UserDefaults with App Group
        // You need to create an App Group in your project: group.com.yourcompany.informed
        if let sharedDefaults = UserDefaults(suiteName: "group.com.yourcompany.informed") {
            sharedDefaults.set(url, forKey: "pendingSharedURL")
            sharedDefaults.set(Date(), forKey: "pendingSharedURLDate")
            sharedDefaults.synchronize()
            print("💾 Saved URL to App Group")
        } else {
            print("⚠️ Could not access App Group")
        }
    }
    
    // MARK: - Open Main App
    
    private func openMainApp(with url: String) {
        // URL encode the Instagram URL
        guard let encodedURL = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            print("❌ Failed to encode URL")
            return
        }
        
        // Create deep link to main app
        let deepLink = "factcheckapp://share?url=\(encodedURL)"
        
        guard let deepLinkURL = URL(string: deepLink) else {
            print("❌ Failed to create deep link")
            return
        }
        
        // Open the main app with the deep link
        var responder: UIResponder? = self as UIResponder
        let selector = #selector(openURL(_:))
        
        while responder != nil {
            if responder!.responds(to: selector) && responder != self {
                responder!.perform(selector, with: deepLinkURL)
                print("✅ Opened main app with URL")
                return
            }
            responder = responder?.next
        }
        
        print("⚠️ Could not open main app")
    }
    
    @objc private func openURL(_ url: URL) {
        // This method is called via responder chain
    }
    
    // MARK: - Error Handling
    
    private func showError(_ message: String) {
        let alert = UIAlertController(
            title: "Error",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        })
        present(alert, animated: true)
    }
    
    // MARK: - View Customization
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Customize the share sheet appearance
        title = "Share to Informed"
        placeholder = "Fact-checking this Instagram reel..."
        
        // Set initial text
        textView.text = "Processing Instagram reel..."
        
        print("📱 Share Extension loaded")
    }
}

