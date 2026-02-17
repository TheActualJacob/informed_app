//
//  SharedReelManager.swift
//  informed
//
//  Manages shared Instagram reels and their fact-checking status
//

import Foundation
import SwiftUI
import Combine

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
    
    // Store complete fact check data
    var factCheckData: StoredFactCheckData?
    
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

// Store complete fact check data with the reel
struct StoredFactCheckData: Codable {
    let title: String
    let summary: String
    let thumbnailURL: String?
    let claim: String
    let verdict: String
    let claimAccuracyRating: String
    let explanation: String
    let sources: [String]
    let datePosted: String?
    
    // Convert to FactCheckItem for display
    func toFactCheckItem(originalLink: String) -> FactCheckItem {
        let factCheck = FactCheck(
            claim: claim,
            verdict: verdict,
            claimAccuracyRating: claimAccuracyRating,
            explanation: explanation,
            summary: summary,
            sources: sources
        )
        
        return FactCheckItem(
            sourceName: "Instagram",
            sourceIcon: "camera.fill",
            timeAgo: "Recently",
            title: title,
            summary: summary,
            thumbnailURL: thumbnailURL != nil ? URL(string: thumbnailURL!) : nil,
            credibilityScore: calculateCredibilityScore(from: claimAccuracyRating),
            sources: sources.joined(separator: ", "),
            verdict: verdict,
            factCheck: factCheck,
            originalLink: originalLink,
            datePosted: datePosted
        )
    }
}

@MainActor
class SharedReelManager: ObservableObject {
    static let shared = SharedReelManager()
    
    @Published var reels: [SharedReel] = []
    @Published var isUploading: Bool = false
    @Published var uploadError: String?
    @Published var lastUploadSuccess: Bool = false
    @Published var isSyncing: Bool = false
    @Published var lastSyncDate: Date?
    
    private var currentUserId: String?
    
    // Reference to HomeViewModel to integrate with main feed
    weak var homeViewModel: HomeViewModel?
    
    init() {
        currentUserId = UserManager.shared.currentUserId
        loadStoredReels()
        setupNotificationObserver()
        setupUserChangeObserver()
    }
    
    // MARK: - Storage
    
    /// Get user-specific storage key
    private func getStorageKey() -> String {
        if let userId = UserManager.shared.currentUserId {
            return "stored_shared_reels_\(userId)"
        }
        return "stored_shared_reels_anonymous"
    }
    
    private func loadStoredReels() {
        let storageKey = getStorageKey()
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([SharedReel].self, from: data) {
            self.reels = decoded
            print("📱 Loaded \(decoded.count) stored reels for user \(UserManager.shared.currentUserId ?? "anonymous")")
        } else {
            self.reels = []
            print("📱 No stored reels found for current user")
        }
    }
    
    func saveReels() {
        let storageKey = getStorageKey()
        if let encoded = try? JSONEncoder().encode(reels) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
            print("💾 Saved \(reels.count) reels for user \(UserManager.shared.currentUserId ?? "anonymous")")
        }
    }
    
    /// Clear reels for current user (called when switching users)
    func clearReelsForCurrentUser() {
        reels.removeAll()
        saveReels()
        lastSyncDate = nil
        print("🗑️ Cleared reels for user")
    }
    
    /// Setup observer to detect user changes
    private func setupUserChangeObserver() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("UserDidChange"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            
            // Check if user actually changed
            let newUserId = UserManager.shared.currentUserId
            if self.currentUserId != newUserId {
                print("👤 User changed from \(self.currentUserId ?? "nil") to \(newUserId ?? "nil")")
                self.currentUserId = newUserId
                
                // Load reels for new user
                self.loadStoredReels()
            }
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
            
            // Create stored fact check data
            let storedData = StoredFactCheckData(
                title: factCheckData.title,
                summary: factCheckData.summary,
                thumbnailURL: factCheckData.thumbnailUrl,
                claim: factCheckData.claim,
                verdict: factCheckData.verdict,
                claimAccuracyRating: factCheckData.claimAccuracyRating,
                explanation: factCheckData.explanation,
                sources: factCheckData.sources,
                datePosted: factCheckData.date
            )
            
            // Update the reel status with complete data
            updateReelStatus(id: newReel.id, status: .completed, resultId: factCheckData.title, factCheckData: storedData)
            
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
                    thumbnailURL: URL(string: factCheckData.thumbnailUrl ?? factCheckData.videoLink),
                    credibilityScore: calculateCredibilityScore(from: factCheckData.claimAccuracyRating),
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
    
    func updateReelStatus(id: String, status: FactCheckStatus, resultId: String? = nil, errorMessage: String? = nil, factCheckData: StoredFactCheckData? = nil) {
        if let index = reels.firstIndex(where: { $0.id == id }) {
            reels[index].status = status
            if let resultId = resultId {
                reels[index].resultId = resultId
            }
            if let errorMessage = errorMessage {
                reels[index].errorMessage = errorMessage
            }
            if let factCheckData = factCheckData {
                reels[index].factCheckData = factCheckData
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
        
        // Get thumbnail URL if available, fallback to videoLink
        let thumbnailUrl = factCheckData["thumbnail_url"] as? String
        
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
            thumbnailURL: URL(string: thumbnailUrl ?? videoLink),
            credibilityScore: calculateCredibilityScore(from: claimAccuracyRating),
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
    
    // MARK: - Sync History from Backend
    
    /// Syncs user's complete reel history from the backend
    func syncHistoryFromBackend() async {
        guard let userId = UserManager.shared.currentUserId,
              let sessionId = UserManager.shared.currentSessionId else {
            print("⚠️ Cannot sync: No user credentials")
            return
        }
        
        await MainActor.run {
            isSyncing = true
        }
        
        do {
            let userReels = try await fetchUserReels(userId: userId, sessionId: sessionId)
            
            await MainActor.run {
                // Convert UserReel objects to SharedReel objects
                let syncedReels = userReels.map { userReel -> SharedReel in
                    // Map status string to FactCheckStatus
                    let status: FactCheckStatus
                    switch userReel.status.lowercased() {
                    case "completed":
                        status = .completed
                    case "processing":
                        status = .processing
                    case "pending":
                        status = .pending
                    case "failed":
                        status = .failed
                    default:
                        status = .pending
                    }
                    
                    // Parse submittedAt date
                    let formatter = ISO8601DateFormatter()
                    let submittedDate = formatter.date(from: userReel.submittedAt) ?? Date()
                    
                    // Create stored fact check data if available
                    var storedData: StoredFactCheckData? = nil
                    if status == .completed,
                       let claim = userReel.claim,
                       let verdict = userReel.verdict,
                       let rating = userReel.claimAccuracyRating,
                       let summary = userReel.summary {
                        
                        storedData = StoredFactCheckData(
                            title: userReel.title,
                            summary: summary,
                            thumbnailURL: userReel.thumbnailUrl,
                            claim: claim,
                            verdict: verdict,
                            claimAccuracyRating: rating,
                            explanation: userReel.explanation ?? "",
                            sources: userReel.sources ?? [],
                            datePosted: nil
                        )
                    }
                    
                    return SharedReel(
                        id: userReel.id,
                        url: userReel.link,
                        submittedAt: submittedDate,
                        status: status,
                        resultId: userReel.title,
                        errorMessage: userReel.errorMessage,
                        factCheckData: storedData
                    )
                }
                
                // Update reels, keeping any local pending uploads
                let localPendingReels = reels.filter { $0.status == .pending || $0.status == .processing }
                let remoteIds = Set(syncedReels.map { $0.id })
                let uniqueLocalReels = localPendingReels.filter { !remoteIds.contains($0.id) }
                
                reels = uniqueLocalReels + syncedReels
                saveReels()
                
                lastSyncDate = Date()
                isSyncing = false
                
                print("✅ Synced \(syncedReels.count) reels from backend")
            }
            
        } catch {
            await MainActor.run {
                isSyncing = false
                uploadError = "Failed to sync: \(error.localizedDescription)"
            }
            print("❌ Error syncing history: \(error)")
        }
    }
    
    /// Fetches user's reels from the backend
    private func fetchUserReels(userId: String, sessionId: String) async throws -> [UserReel] {
        guard var urlComponents = URLComponents(string: Config.Endpoints.userReels) else {
            throw URLError(.badURL)
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "userId", value: userId),
            URLQueryItem(name: "sessionId", value: sessionId),
            URLQueryItem(name: "limit", value: "50")
        ]
        
        guard let url = urlComponents.url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        let userReelsResponse = try decoder.decode(UserReelsResponse.self, from: data)
        return userReelsResponse.reels
    }
}
