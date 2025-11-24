//
//  SharedReelManager.swift
//  informed
//
//  Manages shared Instagram reels and their fact-checking status
//

import Foundation
import SwiftUI
internal import Combine

enum FactCheckStatus: String, Codable {
    case pending = "Pending"
    case processing = "Processing"
    case completed = "Completed"
    case failed = "Failed"
    
    var color: Color {
        switch self {
        case .pending: return .gray
        case .processing: return .brandBlue
        case .completed: return .brandGreen
        case .failed: return .brandRed
        }
    }
    
    var icon: String {
        switch self {
        case .pending: return "clock.fill"
        case .processing: return "gearshape.fill"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }
}

struct SharedReel: Identifiable, Codable {
    let id: String
    let url: String
    let submittedAt: Date
    var status: FactCheckStatus
    var resultId: String?
    var errorMessage: String?
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: submittedAt, relativeTo: Date())
    }
    
    var displayURL: String {
        if url.count > 50 {
            return String(url.prefix(47)) + "..."
        }
        return url
    }
}

@MainActor
class SharedReelManager: ObservableObject {
    static let shared = SharedReelManager()
    
    @Published var reels: [SharedReel] = []
    @Published var isUploading: Bool = false
    @Published var uploadError: String?
    @Published var lastUploadSuccess: Bool = false
    
    private let reelsKey = "stored_shared_reels"
    
    init() {
        loadStoredReels()
        setupNotificationObserver()
    }
    
    // MARK: - Storage
    
    private func loadStoredReels() {
        if let data = UserDefaults.standard.data(forKey: reelsKey),
           let decoded = try? JSONDecoder().decode([SharedReel].self, from: data) {
            self.reels = decoded
            print("📱 Loaded \(decoded.count) stored reels")
        }
    }
    
    private func saveReels() {
        if let encoded = try? JSONEncoder().encode(reels) {
            UserDefaults.standard.set(encoded, forKey: reelsKey)
            print("💾 Saved \(reels.count) reels")
        }
    }
    
    // MARK: - Handle Incoming URL
    
    func handleSharedURL(_ url: URL) async -> Bool {
        print("🔗 Handling shared URL: \(url.absoluteString)")
        
        // Parse the Instagram reel URL from query parameters
        guard let instagramURL = extractInstagramURL(from: url) else {
            await MainActor.run {
                uploadError = "Could not extract Instagram URL from shared content"
            }
            return false
        }
        
        print("📸 Extracted Instagram URL: \(instagramURL)")
        
        // Upload to backend
        return await uploadReelToBackend(instagramURL)
    }
    
    private func extractInstagramURL(from url: URL) -> String? {
        // Expected format: factcheckapp://share?url=INSTAGRAM_REEL_URL
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let queryItems = components.queryItems else {
            return nil
        }
        
        // Find the "url" parameter
        if let urlParam = queryItems.first(where: { $0.name == "url" })?.value {
            return urlParam
        }
        
        return nil
    }
    
    // MARK: - Backend Upload
    
    func uploadReelToBackend(_ instagramURL: String) async -> Bool {
        isUploading = true
        uploadError = nil
        lastUploadSuccess = false
        
        // Create a new reel record
        let newReel = SharedReel(
            id: UUID().uuidString,
            url: instagramURL,
            submittedAt: Date(),
            status: .pending
        )
        
        // Add to local storage immediately
        reels.insert(newReel, at: 0)
        saveReels()
        
        // Get device token
        let deviceToken = NotificationManager.shared.getDeviceToken() ?? "no_token"
        
        guard let url = URL(string: "https://my-backend.com/api/fact-check") else {
            await MainActor.run {
                uploadError = "Invalid backend URL"
                updateReelStatus(id: newReel.id, status: .failed, errorMessage: "Invalid backend URL")
                isUploading = false
            }
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer YOUR_AUTH_TOKEN", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "url": instagramURL,
            "device_token": deviceToken,
            "submission_id": newReel.id
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            
            if (200...299).contains(httpResponse.statusCode) {
                print("✅ Successfully uploaded reel to backend")
                
                // Parse response if needed
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let factCheckId = json["fact_check_id"] as? String {
                    updateReelStatus(id: newReel.id, status: .processing, resultId: factCheckId)
                } else {
                    updateReelStatus(id: newReel.id, status: .processing)
                }
                
                await MainActor.run {
                    lastUploadSuccess = true
                    isUploading = false
                }
                
                return true
            } else {
                let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw NSError(
                    domain: "FactCheckError",
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: errorText]
                )
            }
            
        } catch {
            print("❌ Error uploading reel: \(error)")
            
            await MainActor.run {
                uploadError = "Failed to upload: \(error.localizedDescription)"
                updateReelStatus(id: newReel.id, status: .failed, errorMessage: error.localizedDescription)
                isUploading = false
            }
            
            return false
        }
    }
    
    // MARK: - Status Updates
    
    func updateReelStatus(id: String, status: FactCheckStatus, resultId: String? = nil, errorMessage: String? = nil) {
        if let index = reels.firstIndex(where: { $0.id == id }) {
            reels[index].status = status
            if let resultId = resultId {
                reels[index].resultId = resultId
            }
            if let errorMessage = errorMessage {
                reels[index].errorMessage = errorMessage
            }
            saveReels()
        }
    }
    
    func markReelAsCompleted(factCheckId: String) {
        if let index = reels.firstIndex(where: { $0.resultId == factCheckId }) {
            reels[index].status = .completed
            saveReels()
            
            // Post notification to refresh UI
            NotificationCenter.default.post(name: NSNotification.Name("ReelFactCheckCompleted"), object: nil)
        }
    }
    
    // MARK: - Notification Observer
    
    private func setupNotificationObserver() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("FactCheckCompleted"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let factCheckId = notification.userInfo?["fact_check_id"] as? String {
                self?.markReelAsCompleted(factCheckId: factCheckId)
            }
        }
    }
    
    // MARK: - Clear Data
    
    func clearAllReels() {
        reels.removeAll()
        saveReels()
    }
    
    func deleteReel(id: String) {
        reels.removeAll { $0.id == id }
        saveReels()
    }
}
