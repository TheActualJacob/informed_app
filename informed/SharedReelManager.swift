//
//  SharedReelManager.swift
//  informed
//
//  Manages shared Instagram reels and their fact-checking status
//

import Foundation
import SwiftUI
import Combine
import ActivityKit

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
    var platform: String?  // "instagram" or "tiktok"
    
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
    
    // Detect platform from URL if not explicitly set
    var detectedPlatform: String {
        if let platform = platform {
            return platform
        }
        // Detect from URL
        if url.contains("tiktok.com") || url.contains("vm.tiktok.com") {
            return "tiktok"
        } else if url.contains("instagram.com") {
            return "instagram"
        }
        return "instagram" // Default fallback
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
    let platform: String?  // "instagram" or "tiktok"
    
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
        
        // Determine platform-specific display
        let platformName: String
        let platformIcon: String
        if let platform = platform {
            if platform.lowercased() == "tiktok" {
                platformName = "TikTok"
                platformIcon = "music.note"  // TikTok-like icon
            } else {
                platformName = "Instagram"
                platformIcon = "camera.fill"
            }
        } else {
            // Fallback detection from URL
            if originalLink.contains("tiktok") {
                platformName = "TikTok"
                platformIcon = "music.note"
            } else {
                platformName = "Instagram"
                platformIcon = "camera.fill"
            }
        }
        
        return FactCheckItem(
            sourceName: platformName,
            sourceIcon: platformIcon,
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

    // Deep-link state: set by ContentView when user taps a completed Live Activity
    @Published var pendingDeepLinkId: String? = nil
    @Published var pendingDeepLinkItem: FactCheckItem? = nil

    /// URL of the share-extension submission currently being processed.
    /// Drives the ProcessingBanner in HomeView when a fact check was started outside the app.
    @Published var activeProcessingURL: String? = nil

    private var currentUserId: String?
    private var lastActivityCheckTime: Date? // For debouncing Live Activity checks
    
    // Reference to HomeViewModel to integrate with main feed
    weak var homeViewModel: HomeViewModel?
    
    init() {
        currentUserId = UserManager.shared.currentUserId
        loadStoredReels()
        setupNotificationObserver()
        setupUserChangeObserver()
        
        // Clean up stale submissions from App Group on init
        cleanupStaleAppGroupSubmissions()
        
        // Check for pending submissions and start Live Activities
        if #available(iOS 16.1, *) {
            Task {
                await checkAndStartPendingLiveActivities()
            }
        }
    }
    
    // MARK: - Cleanup Stale App Group Submissions
    
    private func cleanupStaleAppGroupSubmissions() {
        let appGroupName = "group.com.jacob.informed"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupName) else {
            return
        }
        
        guard let submissions = sharedDefaults.array(forKey: "pending_submissions") as? [[String: Any]] else {
            return
        }
        
        let now = Date().timeIntervalSince1970
        let twoMinutesAgo = now - 120 // 2 minutes
        
        // Keep only submissions from the last 2 minutes
        let recentSubmissions = submissions.filter { submission in
            guard let submittedAt = submission["submitted_at"] as? TimeInterval else {
                return false
            }
            return submittedAt > twoMinutesAgo
        }
        
        if recentSubmissions.count < submissions.count {
            print("🧹 Cleaned up \(submissions.count - recentSubmissions.count) stale submissions from App Group")
            sharedDefaults.set(recentSubmissions, forKey: "pending_submissions")
            sharedDefaults.synchronize()
        }
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
                datePosted: factCheckData.date,
                platform: factCheckData.platform
            )
            
            // Update the reel status with complete data
            updateReelStatus(id: newReel.id, status: .completed, resultId: factCheckData.title, factCheckData: storedData)
            
            // If we have a homeViewModel, refresh the personalized feed
            if let viewModel = homeViewModel {
                // Refresh the personalized feed so the new result appears
                viewModel.refreshFeedAfterExternalFactCheck()
                
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
    
    // MARK: - Real-Time Progress Polling
    
    /// Polls backend for submission progress and updates Live Activity
    /// - Parameter submissionId: The unique submission ID from backend
    func startProgressPolling(submissionId: String) {
        guard #available(iOS 16.1, *) else { return }
        
        print("🔄 [ProgressPolling] Starting progress polling for: \(submissionId)")
        
        Task {
            var isCompleted = false
            var pollCount = 0
            let maxPolls = 60 // 60 polls * 3s = 3 minutes max
            
            while !isCompleted && pollCount < maxPolls {
                pollCount += 1
                
                do {
                    // Fetch current status from backend
                    let statusResponse = try await fetchSubmissionStatus(submissionId: submissionId)
                    
                    print("📊 [ProgressPolling] Poll \(pollCount): \(statusResponse.status) - \(statusResponse.progressPercentage)%")
                    
                    // Derive the ProcessingStatus from the backend response
                    let processingStatus = statusResponse.toProcessingStatus()
                    
                    // Update Live Activity with real backend data including status and time estimate
                    await ReelProcessingActivityManager.shared.updateProgress(
                        submissionId: submissionId,
                        status: processingStatus,
                        progress: statusResponse.normalizedProgress,
                        message: statusResponse.currentStage,
                        estimatedSecondsRemaining: statusResponse.estimatedSecondsRemaining
                    )
                    
                    // Check if completed or failed
                    if statusResponse.status.lowercased() == "completed" {
                        print("✅ [ProgressPolling] Submission completed!")
                        isCompleted = true
                        
                        // Sync completed fact-checks from App Group
                        syncCompletedFactChecksFromAppGroup()
                        break
                    } else if statusResponse.status.lowercased() == "failed" {
                        print("❌ [ProgressPolling] Submission failed")
                        await ReelProcessingActivityManager.shared.failActivity(
                            submissionId: submissionId,
                            errorMessage: statusResponse.currentStage
                        )
                        isCompleted = true
                        break
                    }
                    
                    // Wait 3 seconds before next poll
                    try await Task.sleep(nanoseconds: 3_000_000_000)
                    
                } catch {
                    print("⚠️ [ProgressPolling] Error fetching status: \(error.localizedDescription)")
                    
                    // On error, wait and retry (don't fail immediately)
                    try? await Task.sleep(nanoseconds: 5_000_000_000) // 5s on error
                }
            }
            
            if !isCompleted && pollCount >= maxPolls {
                print("⏱️ [ProgressPolling] Timeout after \(maxPolls) polls (3 minutes)")
                await ReelProcessingActivityManager.shared.failActivity(
                    submissionId: submissionId,
                    errorMessage: "Processing timeout"
                )
            }
        }
    }
    
    /// Fetches current submission status from backend
    private func fetchSubmissionStatus(submissionId: String) async throws -> SubmissionStatusResponse {
        guard let userId = UserManager.shared.currentUserId,
              let sessionId = UserManager.shared.currentSessionId else {
            throw URLError(.userAuthenticationRequired)
        }
        
        // Construct URL: GET /api/submission-status/:id
        let urlString = "\(Config.Endpoints.submissionStatus)/\(submissionId)"
        guard var urlComponents = URLComponents(string: urlString) else {
            throw URLError(.badURL)
        }
        
        // Add authentication query parameters
        urlComponents.queryItems = [
            URLQueryItem(name: "userId", value: userId),
            URLQueryItem(name: "sessionId", value: sessionId)
        ]
        
        guard let url = urlComponents.url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10 // Short timeout for polling
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(SubmissionStatusResponse.self, from: data)
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
                
                // End Live Activity immediately if user is viewing the app
                // (they don't need to see it anymore since they're in the app)
                if #available(iOS 16.1, *) {
                    Task {
                        print("🎬 Ending Live Activity for completed reel (user is in app)")
                        await ReelProcessingActivityManager.shared.endActivity(
                            submissionId: id,
                            dismissalPolicy: .immediate
                        )
                    }
                }
                continue
            }
            
            // Extract fact-check data for StoredFactCheckData
            let storedData: StoredFactCheckData?
            if let title = factCheckData["title"] as? String,
               let summary = factCheckData["summary"] as? String,
               let claim = factCheckData["claim"] as? String,
               let verdict = factCheckData["verdict"] as? String,
               let claimAccuracyRating = factCheckData["claim_accuracy_rating"] as? String,
               let explanation = factCheckData["explanation"] as? String,
               let sources = factCheckData["sources"] as? [String],
               let datePosted = factCheckData["date"] as? String {
                
                let thumbnailURL = factCheckData["thumbnail_url"] as? String
                let platform = factCheckData["platform"] as? String
                
                storedData = StoredFactCheckData(
                    title: title,
                    summary: summary,
                    thumbnailURL: thumbnailURL,
                    claim: claim,
                    verdict: verdict,
                    claimAccuracyRating: claimAccuracyRating,
                    explanation: explanation,
                    sources: sources,
                    datePosted: datePosted,
                    platform: platform
                )
            } else {
                print("⚠️ Missing some fact-check fields, creating without stored data")
                storedData = nil
            }
            
            // Add as completed to SharedReelManager with fact-check data
            let sharedReel = SharedReel(
                id: id,
                url: url,
                submittedAt: Date(timeIntervalSince1970: submittedAt),
                status: .completed,
                resultId: factCheckData["title"] as? String,
                errorMessage: nil,
                factCheckData: storedData
            )
            
            reels.insert(sharedReel, at: 0)
            print("✅ Synced completed fact-check \(id) to SharedReelManager with full data")
            
            // Complete Live Activity for iOS 16.1+ - show completion briefly then dismiss
            if #available(iOS 16.1, *) {
                Task {
                    let title = factCheckData["title"] as? String ?? "Fact-Check Complete"
                    let verdict = factCheckData["verdict"] as? String ?? "View Results"
                    
                    // Update to completion state
                    await ReelProcessingActivityManager.shared.completeActivity(
                        submissionId: id,
                        title: title,
                        verdict: verdict
                    )
                    
                    // Then dismiss after 3 seconds (reduced from 8 for faster cleanup)
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    await ReelProcessingActivityManager.shared.endActivity(
                        submissionId: id,
                        dismissalPolicy: .default
                    )
                }
            }
            
            // Add to HomeViewModel feed if available
            if let homeViewModel = homeViewModel {
                addFactCheckToFeed(factCheckData: factCheckData, homeViewModel: homeViewModel)
            }
        }
        
        saveReels()
        
        // Clear processed fact-checks from App Group
        sharedDefaults.removeObject(forKey: "completed_fact_checks")
        print("🧹 Cleared completed_fact_checks from App Group")

        // Hide the processing banner if nothing is pending anymore
        let pendingCount = (sharedDefaults.array(forKey: "pending_submissions") as? [[String: Any]])?.count ?? 0
        if pendingCount == 0 {
            activeProcessingURL = nil
        }
    }
    
    // MARK: - Add Fact-Check to Feed
    
    private func addFactCheckToFeed(factCheckData: [String: Any], homeViewModel: HomeViewModel) {
        guard let url = factCheckData["url"] as? String else { return }
        
        // Skip if already present in the computed feed
        if homeViewModel.items.contains(where: { $0.originalLink == url }) {
            print("ℹ️ Fact-check already in feed, skipping")
            return
        }
        
        // Refresh the personalized feed so the new item appears
        homeViewModel.refreshFeedAfterExternalFactCheck()
        print("✅ Triggered feed refresh after completed fact-check")
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
                            datePosted: nil,
                            platform: userReel.platform
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
    
    // MARK: - Live Activity Management
    
    @available(iOS 16.1, *)
    func checkAndStartPendingLiveActivities() async {
        print("🔍 [LiveActivity] checkAndStartPendingLiveActivities called")
        
        // Debounce: Skip if we checked within the last 2 seconds
        let now = Date()
        if let lastCheck = lastActivityCheckTime {
            let timeSinceLastCheck = now.timeIntervalSince(lastCheck)
            if timeSinceLastCheck < 2.0 {
                print("⏭️ [LiveActivity] Skipping check - last check was \(String(format: "%.1f", timeSinceLastCheck))s ago (debouncing)")
                return
            }
        }
        lastActivityCheckTime = now
        
        // Check App Group for pending submissions that need Live Activities
        let appGroupName = "group.com.jacob.informed"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupName) else {
            print("❌ [LiveActivity] Could not access App Group: \(appGroupName)")
            return
        }
        
        print("📂 [LiveActivity] Accessing App Group: \(appGroupName)")
        
        // Force sync to get latest data
        sharedDefaults.synchronize()
        
        // Check and clear the hasPendingReel flag from Share Extension
        let hasPendingReel = sharedDefaults.bool(forKey: "hasPendingReel")
        if hasPendingReel {
            print("🚀 [LiveActivity] Share Extension flag detected - new reel submitted!")
            sharedDefaults.removeObject(forKey: "hasPendingReel")
            sharedDefaults.synchronize()
        }
        
        // Check for polling flag from backend response
        if let submissionIdForPolling = sharedDefaults.string(forKey: "latest_submission_id_for_polling") {
            print("🔄 [LiveActivity] Found submission ID for progress polling: \(submissionIdForPolling)")
            sharedDefaults.removeObject(forKey: "latest_submission_id_for_polling")
            sharedDefaults.synchronize()
            
            // Start progress polling for this submission
            startProgressPolling(submissionId: submissionIdForPolling)
        }
        
        guard let submissions = sharedDefaults.array(forKey: "pending_submissions") as? [[String: Any]] else {
            print("📭 [LiveActivity] No pending_submissions array found in App Group")
            print("   Raw value: \(String(describing: sharedDefaults.object(forKey: "pending_submissions")))")
            activeProcessingURL = nil   // no pending submissions → hide banner
            return
        }
        
        print("📦 [LiveActivity] Found \(submissions.count) total submissions in App Group")
        
        // Clean up old submissions (older than 5 minutes)
        let currentTimestamp = Date().timeIntervalSince1970
        var freshSubmissions: [[String: Any]] = []
        var startedCount = 0 // Count how many activities we started
        let maxToStart = 3 // Only start 3 new activities at a time to avoid hitting limit
        
        print("🔍 [LiveActivity] Processing submissions (current time: \(currentTimestamp))...")
        
        for (index, submission) in submissions.enumerated() {
            print("   Submission #\(index + 1):")
            print("     ID: \(submission["id"] as? String ?? "nil")")
            print("     URL: \((submission["url"] as? String ?? "nil").prefix(50))...")
            print("     Status: \(submission["status"] as? String ?? "nil")")
            print("     Submitted: \(submission["submitted_at"] as? TimeInterval ?? 0)")
            
            guard let submittedAt = submission["submitted_at"] as? TimeInterval else {
                print("     ✗ Missing submitted_at timestamp, skipping")
                continue
            }
            
            let age = currentTimestamp - submittedAt
            print("     Age: \(Int(age))s")
            
            // Remove submissions older than 5 minutes (300 seconds)
            if age > 300 {
                print("     ✗ Too old (\(Int(age))s > 300s), removing")
                continue
            }
            
            guard let submissionId = submission["id"] as? String else {
                print("⚠️ [LiveActivity] Submission missing ID, skipping")
                continue
            }
            
            guard let url = submission["url"] as? String else {
                print("⚠️ [LiveActivity] Submission missing URL, skipping")
                continue
            }
            
            let status = submission["status"] as? String
            print("   Status in App Group: '\(status ?? "nil")'")
            
            // If the local reels store already marks this as completed or failed,
            // drop it from pending_submissions entirely — do NOT add to freshSubmissions.
            let localReel = reels.first(where: { $0.id == submissionId })
            if localReel?.status == .completed || localReel?.status == .failed {
                print("   ✗ Submission \(submissionId) already \(localReel!.status.rawValue) locally — dropping from App Group")
                continue
            }
            
            // Only keep submissions that are actively processing
            guard status == "processing" else {
                print("   ✗ Status is '\(status ?? "nil")' (not 'processing') — dropping from App Group")
                continue
            }
            
            // All checks passed — this is a genuinely live submission, keep it
            print("     ✓ Fresh submission, keeping: \(submissionId)")
            print("   ✓ Has URL: \(url.prefix(50))...")
            freshSubmissions.append(submission)
            
            print("   ✓ Status is 'processing'")

            // Check if a system Live Activity already exists for this submission
            let existingActivity = Activity<ReelProcessingActivityAttributes>.activities.first {
                $0.attributes.submissionId == submissionId
            }
            
            if let existing = existingActivity {
                let age = Date().timeIntervalSince(existing.attributes.startTime)
                print("✅ [LiveActivity] Active Live Activity found for \(submissionId)")
                print("     State: \(existing.activityState)")
                print("     Age: \(Int(age))s")
                print("     ✅ Keeping existing activity - it's already visible!")
                
                // Track it in our manager
                ReelProcessingActivityManager.shared.currentActivities[submissionId] = existing
                startedCount += 1 // Count as started
                continue // Skip creating a duplicate
            }
            
            // Limit how many we start at once to avoid hitting the system limit
            if startedCount >= maxToStart {
                print("⏸️ [LiveActivity] Reached max new activities (\(maxToStart)), stopping for now")
                break
            }
            
            print("🎬 [LiveActivity] Starting Live Activity for submission: \(submissionId)")
            print("   URL: \(url)")
            print("   Age: \(Int(age))s")
            
            // Start Live Activity for this pending submission
            await ReelProcessingActivityManager.shared.startActivity(
                submissionId: submissionId,
                reelURL: url,
                thumbnailURL: nil
            )
            
            startedCount += 1
        }
        
        // Save cleaned up submissions back to App Group
        sharedDefaults.set(freshSubmissions, forKey: "pending_submissions")
        sharedDefaults.synchronize()

        // Drive the in-app processing banner for share-extension fact checks.
        // Pick the URL of the first submission still in flight, or nil when all are done.
        let firstPendingURL = freshSubmissions.compactMap { $0["url"] as? String }.first
        if activeProcessingURL != firstPendingURL {
            activeProcessingURL = firstPendingURL
        }

        print("✅ [LiveActivity] checkAndStartPendingLiveActivities complete")
        print("   - Cleaned up: \(submissions.count - freshSubmissions.count) stale submissions")
        print("   - Remaining: \(freshSubmissions.count) fresh submissions")
        print("   - Started: \(startedCount) new Live Activities")
    }
}
