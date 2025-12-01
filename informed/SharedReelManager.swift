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
    
    // Reference to HomeViewModel to integrate with main feed
    weak var homeViewModel: HomeViewModel?
    
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
    
    func saveReels() {
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
        
        // Get user ID and session ID
        let userId = UserManager.shared.currentUserId ?? "anonymous"
        let sessionId = UserManager.shared.currentSessionId ?? ""
        
        // If we have a homeViewModel reference, trigger the same UI flow as pasting a link
        if let viewModel = homeViewModel {
            // Set the processing state to show the loading banner
            viewModel.processingLink = instagramURL
            if let url = URL(string: instagramURL) {
                viewModel.processingThumbnailURL = url
            }
        }
        
        do {
            // Use the existing sendFactCheck function from Requests.swift
            let request = FactCheckRequest(link: instagramURL, userId: userId, sessionId: sessionId)
            print("📤 Sending fact check request for shared reel...")
            
            let factCheckData = try await sendFactCheck(request)
            print("✅ Successfully received fact check for shared reel")
            
            // Update the reel status
            updateReelStatus(id: newReel.id, status: .completed, resultId: factCheckData.title)
            
            // If we have a homeViewModel, add the result to the main feed (same as paste flow)
            if let viewModel = homeViewModel {
                // Convert to FactCheck model
                let factCheck = FactCheck(
                    claim: factCheckData.claim,
                    verdict: factCheckData.verdict,
                    claimAccuracyRating: factCheckData.claimAccuracyRating,
                    explanation: factCheckData.explanation,
                    summary: factCheckData.summary,
                    sources: factCheckData.sources
                )
                
                // Create FactCheckItem
                let newItem = FactCheckItem(
                    sourceName: "Instagram",
                    sourceIcon: "camera.fill",
                    timeAgo: "Just now",
                    title: factCheckData.title,
                    summary: factCheckData.summary,
                    thumbnailURL: URL(string: factCheckData.videoLink),
                    credibilityScore: viewModel.calculateCredibilityScore(from: factCheckData.claimAccuracyRating),
                    sources: factCheckData.sources.joined(separator: ", "),
                    verdict: factCheckData.verdict,
                    factCheck: factCheck,
                    originalLink: instagramURL,
                    datePosted: factCheckData.date
                )
                
                // Add to main feed
                viewModel.items.insert(newItem, at: 0)
                
                // Clear processing state
                viewModel.processingLink = nil
                viewModel.processingThumbnailURL = nil
            }
            
            await MainActor.run {
                lastUploadSuccess = true
                isUploading = false
            }
            
            return true
            
        } catch {
            print("❌ Error fact-checking shared reel: \(error)")
            
            await MainActor.run {
                uploadError = "Failed to fact-check: \(error.localizedDescription)"
                updateReelStatus(id: newReel.id, status: .failed, errorMessage: error.localizedDescription)
                isUploading = false
                
                // Clear processing state on error
                if let viewModel = homeViewModel {
                    viewModel.processingLink = nil
                    viewModel.processingThumbnailURL = nil
                    viewModel.errorMessage = error.localizedDescription
                }
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
    
    // MARK: - Sync Completed Fact-Checks from Share Extension
    
    func syncCompletedFactChecksFromAppGroup() {
        let appGroupName = "group.com.jacob.informed"
        
        guard let sharedDefaults = UserDefaults(suiteName: appGroupName) else {
            print("⚠️ Could not access App Group: \(appGroupName)")
            return
        }
        
        // Check for COMPLETED fact-checks from Share Extension
        guard let completedFactChecks = sharedDefaults.array(forKey: "completed_fact_checks") as? [[String: Any]],
              !completedFactChecks.isEmpty else {
            print("📭 No completed fact-checks found in App Group")
            return
        }
        
        print("📥 Found \(completedFactChecks.count) completed fact-checks from Share Extension")
        
        for factCheckData in completedFactChecks {
            guard let id = factCheckData["id"] as? String,
                  let url = factCheckData["url"] as? String,
                  let submittedAt = factCheckData["submitted_at"] as? TimeInterval else {
                print("⚠️ Invalid fact-check data, skipping")
                continue
            }
            
            // Check if we already have this fact-check
            if reels.contains(where: { $0.id == id }) {
                print("ℹ️ Fact-check \(id) already exists, skipping")
                continue
            }
            
            // Add as completed to SharedReelManager
            let sharedReel = SharedReel(
                id: id,
                url: url,
                submittedAt: Date(timeIntervalSince1970: submittedAt),
                status: .completed,
                resultId: factCheckData["title"] as? String,
                errorMessage: nil
            )
            
            reels.insert(sharedReel, at: 0)
            print("✅ Synced completed fact-check \(id) to SharedReelManager")
            
            // Add to HomeViewModel feed if available
            if let homeViewModel = homeViewModel {
                addFactCheckToFeed(factCheckData: factCheckData, homeViewModel: homeViewModel)
            }
        }
        
        saveReels()
        
        // Clear processed fact-checks from App Group
        sharedDefaults.removeObject(forKey: "completed_fact_checks")
        print("🧹 Cleared completed_fact_checks from App Group")
    }
    
    // MARK: - Add Fact-Check to Feed
    
    private func addFactCheckToFeed(factCheckData: [String: Any], homeViewModel: HomeViewModel) {
        // Extract fact-check data from dictionary
        guard let title = factCheckData["title"] as? String,
              let claim = factCheckData["claim"] as? String,
              let verdict = factCheckData["verdict"] as? String,
              let claimAccuracyRating = factCheckData["claim_accuracy_rating"] as? String,
              let explanation = factCheckData["explanation"] as? String,
              let summary = factCheckData["summary"] as? String,
              let sources = factCheckData["sources"] as? [String],
              let videoLink = factCheckData["videoLink"] as? String,
              let datePosted = factCheckData["date"] as? String,
              let url = factCheckData["url"] as? String else {
            print("⚠️ Missing required fields in fact-check data")
            return
        }
        
        // Check if this fact-check is already in the feed
        if homeViewModel.items.contains(where: { $0.originalLink == url }) {
            print("ℹ️ Fact-check already in feed, skipping")
            return
        }
        
        // Convert to FactCheck model
        let factCheck = FactCheck(
            claim: claim,
            verdict: verdict,
            claimAccuracyRating: claimAccuracyRating,
            explanation: explanation,
            summary: summary,
            sources: sources
        )
        
        // Create FactCheckItem
        let newItem = FactCheckItem(
            sourceName: "Instagram",
            sourceIcon: "camera.fill",
            timeAgo: "Just now",
            title: title,
            summary: summary,
            thumbnailURL: URL(string: videoLink),
            credibilityScore: homeViewModel.calculateCredibilityScore(from: claimAccuracyRating),
            sources: sources.joined(separator: ", "),
            verdict: verdict,
            factCheck: factCheck,
            originalLink: url,
            datePosted: datePosted
        )
        
        // Add to main feed at the top
        homeViewModel.items.insert(newItem, at: 0)
        print("✅ Added completed fact-check to feed: \(title)")
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
