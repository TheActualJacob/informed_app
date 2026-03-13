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

// MARK: - StatusClaimEntry → ClaimEntry bridge
// StatusClaimEntry is defined in ReelProcessingActivity.swift (compiled into ALL
// targets). ClaimEntry lives only in the main-app target, so the conversion
// extension must live here rather than in the shared file.
extension StatusClaimEntry {
    func toClaimEntry() -> ClaimEntry {
        ClaimEntry(
            claim: claim,
            verdict: verdict,
            claimAccuracyRating: claimAccuracyRating,
            explanation: explanation,
            summary: summary,
            sources: sources,
            category: category
        )
    }
}

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
    var platform: String?  // "instagram", "tiktok", "youtube_shorts", "threads", "twitter"
    
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
        if let platform = platform { return platform }
        return detectedPlatformFromURL(url)
    }
}

// Store complete fact check data with the reel
struct StoredFactCheckData: Codable {
    /// The backend uniqueID — used to build the shareable web preview URL.
    let reelID: String?
    let title: String
    let summary: String
    var thumbnailURL: String?
    /// 1–3 claims. Old persisted records migrate via custom init(from:).
    let claims: [ClaimEntry]
    let datePosted: String?
    let platform: String?
    let aiGenerated: String?
    let aiProbability: Double?

    // Primary-claim shortcuts (backward compat)
    var claim: String               { claims.first?.claim ?? "" }
    var verdict: String             { claims.first?.verdict ?? "" }
    var claimAccuracyRating: String { claims.first?.claimAccuracyRating ?? "50%" }
    var explanation: String         { claims.first?.explanation ?? "" }
    var sources: [String]           { claims.first?.sources ?? [] }

    // Flat-field init (used by old code paths / Share Extension)
    init(title: String, summary: String, thumbnailURL: String?,
         claim: String, verdict: String, claimAccuracyRating: String,
         explanation: String, sources: [String],
         datePosted: String?, platform: String?,
         aiGenerated: String? = nil, aiProbability: Double? = nil,
         reelID: String? = nil) {
        self.reelID = reelID
        self.title = title; self.summary = summary; self.thumbnailURL = thumbnailURL
        self.claims = [ClaimEntry(claim: claim, verdict: verdict,
                                  claimAccuracyRating: claimAccuracyRating,
                                  explanation: explanation, summary: summary, sources: sources)]
        self.datePosted = datePosted; self.platform = platform
        self.aiGenerated = aiGenerated; self.aiProbability = aiProbability
    }

    // Multi-claim init
    init(title: String, summary: String, thumbnailURL: String?,
         claims: [ClaimEntry], datePosted: String?, platform: String?,
         aiGenerated: String? = nil, aiProbability: Double? = nil,
         reelID: String? = nil) {
        self.reelID = reelID
        self.title = title; self.summary = summary; self.thumbnailURL = thumbnailURL
        self.claims = claims.isEmpty
            ? [ClaimEntry(claim: "", verdict: "", claimAccuracyRating: "50%",
                          explanation: "", summary: summary, sources: [])]
            : claims
        self.datePosted = datePosted; self.platform = platform
        self.aiGenerated = aiGenerated; self.aiProbability = aiProbability
    }

    // MARK: Custom Codable — migrates old flat JSON on disk to claims array

    enum CodingKeys: String, CodingKey {
        case reelID, title, summary, thumbnailURL, claims, datePosted, platform
        case aiGenerated, aiProbability
        // Legacy flat keys written by old app versions
        case claim, verdict, explanation, sources
        case claimAccuracyRating   // was stored camelCase by old app
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        reelID        = try? c.decodeIfPresent(String.self, forKey: .reelID)
        title         = try c.decode(String.self, forKey: .title)
        summary       = (try? c.decodeIfPresent(String.self, forKey: .summary)) ?? ""
        thumbnailURL  = try c.decodeIfPresent(String.self, forKey: .thumbnailURL)
        datePosted    = try c.decodeIfPresent(String.self, forKey: .datePosted)
        platform      = try c.decodeIfPresent(String.self, forKey: .platform)
        aiGenerated   = try c.decodeIfPresent(String.self, forKey: .aiGenerated)
        aiProbability = try c.decodeIfPresent(Double.self, forKey: .aiProbability)
        // Prefer new claims array; fall back to flat fields from old stored JSON
        if let arr = try? c.decodeIfPresent([ClaimEntry].self, forKey: .claims), !arr.isEmpty {
            claims = arr
        } else {
            let cl  = (try? c.decodeIfPresent(String.self,   forKey: .claim))               ?? ""
            let v   = (try? c.decodeIfPresent(String.self,   forKey: .verdict))             ?? ""
            let car = (try? c.decodeIfPresent(String.self,   forKey: .claimAccuracyRating)) ?? "50%"
            let exp = (try? c.decodeIfPresent(String.self,   forKey: .explanation))         ?? ""
            let src = (try? c.decodeIfPresent([String].self, forKey: .sources))             ?? []
            claims  = [ClaimEntry(claim: cl, verdict: v, claimAccuracyRating: car,
                                  explanation: exp, summary: summary, sources: src)]
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(reelID,        forKey: .reelID)
        try c.encode(title,                  forKey: .title)
        try c.encode(summary,                forKey: .summary)
        try c.encodeIfPresent(thumbnailURL,  forKey: .thumbnailURL)
        try c.encode(claims,                 forKey: .claims)
        try c.encodeIfPresent(datePosted,    forKey: .datePosted)
        try c.encodeIfPresent(platform,      forKey: .platform)
        try c.encodeIfPresent(aiGenerated,   forKey: .aiGenerated)
        try c.encodeIfPresent(aiProbability, forKey: .aiProbability)
    }

    // Convert to FactCheckItem for display
    func toFactCheckItem(originalLink: String) -> FactCheckItem {
        let resolvedPlatform = platform ?? detectedPlatformFromURL(originalLink)
        let (platformName, platformIcon) = platformInfo(for: resolvedPlatform)
        return FactCheckItem(
            reelID: reelID,
            sourceName: platformName, sourceIcon: platformIcon,
            timeAgo: "Recently", title: title, summary: summary,
            thumbnailURL: thumbnailURL.flatMap { URL(string: $0) },
            credibilityScore: calculateCredibilityScore(from: claimAccuracyRating),
            sources: sources.joined(separator: ", "),
            verdict: verdict, claims: claims,
            originalLink: originalLink, datePosted: datePosted,
            aiGenerated: aiGenerated, aiProbability: aiProbability
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

    /// Set to `true` immediately when the user taps a completed Dynamic Island
    /// so the detail view can navigate instantly (with a loading skeleton).
    /// Cleared once the item resolves or resolution fails.
    @Published var deepLinkLoading: Bool = false

    /// URL of the share-extension submission currently being processed.
    /// Drives the ProcessingBanner in HomeView when a fact check was started outside the app.
    @Published var activeProcessingURL: String? = nil

    private var currentUserId: String?
    private var lastActivityCheckTime: Date? // For debouncing Live Activity checks
    /// Submission IDs that currently have an active progress-polling Task running.
    private var activePollingIds: Set<String> = []
    /// Submission IDs we've already sent a main-app fallback fact-check for (Share Extension request may have been killed).
    private var fallbackSentForSubmissions: Set<String> = []
    /// Whether a thumbnail-refresh sync is already scheduled/running.
    private var thumbnailRefreshScheduled = false
    
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
        let appGroupName = "group.rob"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupName) else {
            return
        }
        
        guard let submissions = sharedDefaults.array(forKey: "pending_submissions") as? [[String: Any]] else {
            return
        }
        
        let now = Date().timeIntervalSince1970
        let fiveMinutesAgo = now - 300 // 5 minutes — matches the polling window (60 polls × 3s)

        // Keep only submissions from the last 5 minutes
        let recentSubmissions = submissions.filter { submission in
            guard let submittedAt = submission["submitted_at"] as? TimeInterval else {
                return false
            }
            return submittedAt > fiveMinutesAgo
        }
        
        if recentSubmissions.count < submissions.count {
            print("🧹 Cleaned up \(submissions.count - recentSubmissions.count) stale App Group submissions (>5 min old)")
            sharedDefaults.set(recentSubmissions, forKey: "pending_submissions")
            sharedDefaults.synchronize()
        }
    }
    
    // MARK: - Storage

    /// Per-user storage key — preserves each account's reels independently on this device.
    private func storageKey(for userId: String?) -> String {
        if let uid = userId { return "stored_shared_reels_\(uid)" }
        return "stored_shared_reels_anonymous"
    }

    private func loadStoredReels() {
        let key = storageKey(for: currentUserId)
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([SharedReel].self, from: data) {
            // Drop stale processing/pending placeholders older than 5 minutes,
            // and drop any failed reels persisted by older app versions.
            let cutoff = Date().addingTimeInterval(-300)
            let cleaned = decoded.filter { reel in
                if reel.status == .failed { return false }
                if reel.status == .processing || reel.status == .pending {
                    return reel.submittedAt > cutoff
                }
                return true
            }
            let dropped = decoded.count - cleaned.count
            if dropped > 0 { print("🧹 Dropped \(dropped) stale/failed reel(s) on load") }
            self.reels = cleaned
            print("📱 Loaded \(cleaned.count) stored reels for user \(currentUserId ?? "anonymous")")
        } else {
            self.reels = []
            print("📱 No stored reels found for user \(currentUserId ?? "anonymous")")
        }
    }

    func saveReels() {
        // Use currentUserId (maintained by this class) — never read UserManager.shared
        // here as it may have already advanced to a different user mid-flight.
        let key = storageKey(for: currentUserId)
        let reelsToSave = reels.filter { reel in
            // Never persist in-flight placeholders (no data yet).
            if (reel.status == .processing || reel.status == .pending) && reel.factCheckData == nil {
                return false
            }
            // Never persist failed reels — error cards are session-only so they
            // don't accumulate across launches. They re-appear if the user retries
            // and fails again, but otherwise clear themselves on next app start.
            if reel.status == .failed {
                return false
            }
            return true
        }
        if let encoded = try? JSONEncoder().encode(reelsToSave) {
            UserDefaults.standard.set(encoded, forKey: key)
            print("💾 Saved \(reelsToSave.count) reels for user \(currentUserId ?? "anonymous")")
        }
    }

    /// Called by UserManager.saveUser() synchronously before isAuthenticated flips,
    /// so the correct user's reels are loaded before ContentView/SharedReelsView appear.
    func reloadReelsForCurrentUser(userId: String?) {
        guard currentUserId != userId else { return }
        print("🔄 Reloading reels: \(currentUserId ?? "nil") → \(userId ?? "nil")")
        // Wipe immediately so the old user's reels are never visible on screen.
        reels = []
        lastSyncDate = nil
        currentUserId = userId
        // Repopulate from this user's local storage right away.
        loadStoredReels()
        // Then fetch full history from backend to fill any gaps
        // (e.g. reels submitted on another device or after a data loss).
        if userId != nil {
            Task { await restoreReelsFromBackend() }
        }
    }

    /// Fetches the user's complete reel history from /api/my-reels (with fallback
    /// to /api/user-reels) and merges it with local storage. Additive only.
    func restoreReelsFromBackend() async {
        guard let userId = currentUserId,
              let sessionId = UserManager.shared.currentSessionId else { return }

        print("☁️ Restoring full reel history from backend for user \(userId)…")

        // Try /api/my-reels first; fall back to /api/user-reels if not yet deployed.
        let endpoints = [Config.Endpoints.myReels, Config.Endpoints.userReels]
        var backendReels: [UserReel] = []

        for endpoint in endpoints {
            guard var components = URLComponents(string: endpoint) else { continue }
            components.queryItems = [
                URLQueryItem(name: "userId", value: userId),
                URLQueryItem(name: "sessionId", value: sessionId),
                URLQueryItem(name: "limit", value: "200")
            ]
            guard let url = components.url else { continue }

            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let http = response as? HTTPURLResponse else { continue }
                guard (200...299).contains(http.statusCode) else {
                    print("⚠️ \(endpoint) returned HTTP \(http.statusCode) — trying next endpoint")
                    continue
                }
                let decoded = try JSONDecoder().decode(UserReelsResponse.self, from: data)
                backendReels = decoded.reels
                print("☁️ Got \(backendReels.count) reels from \(endpoint)")
                break // success — no need to try fallback
            } catch {
                print("⚠️ \(endpoint) request failed: \(error) — trying next endpoint")
            }
        }

        guard !backendReels.isEmpty else {
            print("☁️ All endpoints returned 0 reels — local storage unchanged")
            return
        }

        // Guard: discard if user changed while request was in flight.
        guard currentUserId == userId else {
            print("⚠️ User changed during restoreReelsFromBackend — discarding")
            return
        }

        // Convert backend UserReel → SharedReel
        let formatter = ISO8601DateFormatter()
        let restored: [SharedReel] = backendReels.map { r in
            let status: FactCheckStatus
            switch r.status.lowercased() {
            case "completed":  status = .completed
            case "processing": status = .processing
            case "failed":     status = .failed
            default:           status = .pending
            }
            let date = formatter.date(from: r.submittedAt) ?? Date()
            var storedData: StoredFactCheckData? = nil
            if status == .completed, !r.claims.isEmpty {
                storedData = StoredFactCheckData(
                    title: r.title,
                    summary: r.summary ?? r.claims[0].summary,
                    thumbnailURL: r.thumbnailUrl,
                    claims: r.claims,
                    datePosted: nil,
                    platform: r.platform,
                    aiGenerated: r.aiGenerated,
                    aiProbability: r.aiProbability,
                    reelID: r.id
                )
            } else if status == .completed,
               let claim = r.claim, let verdict = r.verdict,
               let rating = r.claimAccuracyRating, let summary = r.summary {
                storedData = StoredFactCheckData(
                    title: r.title, summary: summary, thumbnailURL: r.thumbnailUrl,
                    claim: claim, verdict: verdict, claimAccuracyRating: rating,
                    explanation: r.explanation ?? "", sources: r.sources ?? [],
                    datePosted: nil, platform: r.platform,
                    aiGenerated: r.aiGenerated, aiProbability: r.aiProbability,
                    reelID: r.id
                )
            }
            return SharedReel(
                id: r.id, url: r.link, submittedAt: date,
                status: status, resultId: r.title,
                errorMessage: r.errorMessage, factCheckData: storedData
            )
        }

        // Merge: backend reels are authoritative for their IDs;
        // keep any local reels the backend doesn't know about.
        let backendIds = Set(restored.map { $0.id })
        let localOnlyReels = reels.filter { !backendIds.contains($0.id) }
        reels = (localOnlyReels + restored).sorted { $0.submittedAt > $1.submittedAt }
        saveReels()
        print("☁️ Restored \(restored.count) reels from backend (\(localOnlyReels.count) local-only kept)")
    }

    /// Removes all reels stored for the current user.
    func clearReelsForCurrentUser() {
        reels.removeAll()
        saveReels()
        lastSyncDate = nil
        print("🗑️ Cleared reels for user \(currentUserId ?? "anonymous")")
    }

    /// Observes account changes as a safety net for logout.
    /// Login transitions are handled synchronously by reloadReelsForCurrentUser()
    /// in UserManager.saveUser() — this observer only needs to handle logout
    /// (newUserId = nil) where there is no saveUser() call.
    private func setupUserChangeObserver() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("UserDidChange"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let newUserId = UserManager.shared.currentUserId
                // If currentUserId already matches (reloadReelsForCurrentUser ran first),
                // do nothing — this is the normal login path.
                guard self.currentUserId != newUserId else {
                    print("👤 UserDidChange: already up to date (\(newUserId ?? "nil")) — no action")
                    return
                }
                // Only reach here on logout (newUserId = nil) or edge cases.
                print("👤 UserDidChange safety-net: \(self.currentUserId ?? "nil") → \(newUserId ?? "nil")")
                self.reels = []
                self.lastSyncDate = nil
                self.currentUserId = newUserId
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

        // Capture submission timestamp before the request so all code paths use the same value.
        let placeholderSubmittedAt = Date()

        // Generate a client-side ID used only for the initial request.
        // The placeholder is NOT inserted into reels[] until we have the confirmed backend ID
        // to avoid a SwiftUI identity rebind when the backend assigns a different ID.
        let clientSid = UUID().uuidString
        
        // Get user ID and session ID
        let userId = UserManager.shared.currentUserId ?? "anonymous"
        let sessionId = UserManager.shared.currentSessionId ?? ""
        
        // If we have a homeViewModel reference, trigger the same UI flow as pasting a link
        if let viewModel = homeViewModel {
            viewModel.processingLink = instagramURL
            if let url = URL(string: instagramURL) {
                viewModel.processingThumbnailURL = url
            }
        }
        
        do {
            let request = FactCheckRequest(link: instagramURL, userId: userId,
                                           sessionId: sessionId, submissionId: clientSid,
                                           deviceId: DeviceManager.deviceId)
            print("📤 Sending fact check request for shared reel...")

            let submission = try await sendFactCheck(request)
            print("✅ Submission response: status=\(submission.status)")

            if submission.status == "processing" || submission.status == "submitting"
                || submission.status == "completed" {
                // Async 202 flow — resolve the confirmed backend ID before inserting
                // into reels[] so the placeholder is always inserted with the stable ID.
                // The "completed" case means this URL was already fact-checked; the
                // first poll will return "completed" immediately and trigger the full
                // completion flow (completeActivity + syncHistoryFromBackend).
                let confirmedSid = submission.submissionId != clientSid ? submission.submissionId : clientSid
                let skipWait = submission.status == "completed"
                let newReel = SharedReel(
                    id: confirmedSid,
                    url: instagramURL,
                    submittedAt: placeholderSubmittedAt,
                    status: .processing
                )
                reels.insert(newReel, at: 0)
                saveReels()
                startProgressPolling(submissionId: confirmedSid, skipInitialWait: skipWait)
                await MainActor.run { isUploading = false; lastUploadSuccess = true }
                return true
            }

            // Legacy sync response — submission.legacyData contains the full result.
            // Insert a temporary placeholder so updateReelStatus can find the reel by ID.
            let legacyReel = SharedReel(id: clientSid, url: instagramURL,
                                        submittedAt: placeholderSubmittedAt, status: .pending)
            reels.insert(legacyReel, at: 0)
            saveReels()

            guard let legacy = submission.legacyData else {
                // status=="completed" but no data — do a sync to fetch it
                scheduleThumbnailRefresh()
                await MainActor.run { isUploading = false; lastUploadSuccess = true }
                return true
            }

            let resolvedClaims = legacy.resolvedClaims
            let storedData = StoredFactCheckData(
                title: legacy.title,
                summary: resolvedClaims[0].summary,
                thumbnailURL: legacy.thumbnailUrl,
                claims: resolvedClaims,
                datePosted: legacy.date,
                platform: legacy.platform,
                aiGenerated: legacy.aiGenerated,
                aiProbability: legacy.aiProbability
            )
            updateReelStatus(id: clientSid, status: .completed,
                             resultId: legacy.title, factCheckData: storedData)
            if let viewModel = homeViewModel {
                viewModel.refreshFeedAfterExternalFactCheck()
                viewModel.processingLink = nil; viewModel.processingThumbnailURL = nil
            }
            scheduleThumbnailRefresh()
            await MainActor.run { lastUploadSuccess = true; isUploading = false }
            return true
            
        } catch let fcErr as FactCheckError where fcErr.localizedDescription == "limit_reached" {
            // Backend rejected the submission — daily or weekly cap hit.
            // Show the upgrade paywall instead of a generic error toast.
            let limitType = fcErr.errorType ?? "daily"
            print("⚠️ [SharedReelManager] uploadReelToBackend: limit_reached (\(limitType)) — showing paywall")
            await MainActor.run {
                isUploading = false
                uploadError = nil  // suppress error toast — paywall is the CTA
                if let viewModel = homeViewModel {
                    viewModel.processingLink = nil
                    viewModel.processingThumbnailURL = nil
                }
                SubscriptionManager.shared.handleLimitReached(type: limitType)
            }
            return false

        } catch {
            print("❌ Error fact-checking shared reel: \(error)")
            
            await MainActor.run {
                uploadError = "Failed to fact-check: \(error.localizedDescription)"
                updateReelStatus(id: clientSid, status: .failed, errorMessage: error.localizedDescription)
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
    
    // MARK: - Foreground Recovery
    
    /// Called when the app returns to the foreground. Checks every active in-progress
    /// Live Activity against the backend and completes / fails any that finished while
    /// the app was suspended. Also flushes any pending activity push tokens so the
    /// backend can push future updates.
    ///
    /// This is the safety net that covers:
    ///  - Background polling being suspended by iOS before seeing completion
    ///  - Activity push tokens that were never delivered because the app was frozen
    ///  - Push-to-start activities with no per-activity push token
    @available(iOS 16.1, *)
    func reconcileActiveActivitiesWithBackend() async {
        let activities = Activity<ReelProcessingActivityAttributes>.activities.filter {
            $0.activityState == .active
        }
        
        guard !activities.isEmpty else { return }
        
        let inProgressActivities = activities.filter {
            let status = $0.content.state.status
            return status != .completed && status != .failed
        }
        
        guard !inProgressActivities.isEmpty else {
            print("🔄 [Reconcile] No in-progress activities to reconcile")
            return
        }
        
        print("🔄 [Reconcile] Checking \(inProgressActivities.count) in-progress Live Activities against backend")
        
        for activity in inProgressActivities {
            let submissionId = activity.attributes.submissionId
            
            // 1. Try to flush the activity push token to the backend.
            //    On foreground, the token may now be available (iOS generates it
            //    asynchronously). The register-activity-token endpoint will
            //    immediately push the current backend state back, closing any gap.
            let tokenFlushed = await ReelProcessingActivityManager.shared
                .tryRegisterActivityPushToken(submissionId: submissionId)
            if tokenFlushed {
                print("🔑 [Reconcile] Flushed activity push token for \(submissionId.prefix(8))")
            }
            
            // 2. Also try the App Group path (Share Extension may have saved a token
            //    that the main app never forwarded).
            ReelProcessingActivityManager.shared.flushAppGroupPushToken(submissionId: submissionId)
            
            // 3. If the activity has no push token, try upgrading it now (foreground).
            //    This replaces the pushType:nil activity with a pushType:.token one.
            if activity.pushToken == nil {
                print("🔄 [Reconcile] Activity \(submissionId.prefix(8)) has no push token — upgrading")
                await ReelProcessingActivityManager.shared.startActivity(
                    submissionId: submissionId,
                    reelURL: activity.attributes.reelURL
                )
            }
            
            // 4. Poll the backend directly for the current status. If the task
            //    completed while we were suspended, drive the island to completion.
            do {
                let statusResponse = try await fetchSubmissionStatus(submissionId: submissionId)
                let backendStatus = statusResponse.status.lowercased()
                
                if backendStatus == "completed" {
                    print("✅ [Reconcile] Submission \(submissionId.prefix(8)) already completed on backend — completing Live Activity")
                    ReelProcessingActivityManager.removeFromAppGroupPendingSubmissions(submissionId: submissionId)
                    await ReelProcessingActivityManager.shared.completeActivity(
                        submissionId: submissionId,
                        title: statusResponse.title ?? "Fact-Check Complete",
                        verdict: "Tap to view results"
                    )
                    
                    // Eagerly update the SharedReel with full fact-check data
                    let eagerClaims = (statusResponse.claims ?? []).map { $0.toClaimEntry() }
                    if !eagerClaims.isEmpty {
                        let eagerData = StoredFactCheckData(
                            title: statusResponse.title ?? "",
                            summary: eagerClaims[0].summary,
                            thumbnailURL: statusResponse.thumbnailUrl,
                            claims: eagerClaims,
                            datePosted: nil,
                            platform: statusResponse.platform,
                            aiGenerated: statusResponse.aiGenerated,
                            aiProbability: statusResponse.aiProbability
                        )
                        await MainActor.run {
                            self.updateReelStatus(
                                id: submissionId, status: .completed,
                                resultId: statusResponse.title,
                                factCheckData: eagerData
                            )
                        }
                    }
                    Task { await self.syncHistoryFromBackend() }
                    
                } else if backendStatus == "failed" {
                    print("❌ [Reconcile] Submission \(submissionId.prefix(8)) failed on backend — failing Live Activity")
                    ReelProcessingActivityManager.removeFromAppGroupPendingSubmissions(submissionId: submissionId)
                    let rawMessage = statusResponse.currentStage.isEmpty
                        ? (statusResponse.errorMessage ?? "")
                        : statusResponse.currentStage
                    let displayMessage = ReelProcessingActivityManager.friendlyErrorMessage(rawMessage)
                    await MainActor.run {
                        updateReelStatus(id: submissionId, status: .failed, errorMessage: displayMessage)
                    }
                    await ReelProcessingActivityManager.shared.failActivity(
                        submissionId: submissionId,
                        errorMessage: rawMessage
                    )
                } else {
                    print("🔄 [Reconcile] Submission \(submissionId.prefix(8)) still \(backendStatus) — ensuring polling is active")
                    // Restart polling if it's not already running
                    startProgressPolling(submissionId: submissionId, skipInitialWait: true)
                }
            } catch {
                print("⚠️ [Reconcile] Could not fetch status for \(submissionId.prefix(8)): \(error.localizedDescription)")
                // Restart polling as fallback
                startProgressPolling(submissionId: submissionId, skipInitialWait: true)
            }
        }
    }

    // MARK: - Real-Time Progress Polling
    
    /// Polls backend for submission progress and updates Live Activity
    /// - Parameter submissionId: The unique submission ID from backend
    func startProgressPolling(submissionId: String, skipInitialWait: Bool = false) {
        guard #available(iOS 16.1, *) else { return }

        // Avoid spawning a duplicate polling task for the same submission.
        guard !activePollingIds.contains(submissionId) else {
            print("⏭️ [ProgressPolling] Already polling \(submissionId.prefix(8)), skipping duplicate")
            return
        }

        // Skip polling for submissions that are already completed or failed locally.
        if let localReel = reels.first(where: { $0.id == submissionId }),
           localReel.status == .completed || localReel.status == .failed {
            print("⏭️ [ProgressPolling] Submission \(submissionId.prefix(8)) already \(localReel.status.rawValue) locally — skipping polling")
            return
        }

        // Also skip if the Live Activity itself is already in completed state.
        if let activity = Activity<ReelProcessingActivityAttributes>.activities.first(where: { $0.attributes.submissionId == submissionId }),
           activity.content.state.status == .completed || activity.content.state.status == .failed {
            print("⏭️ [ProgressPolling] Live Activity for \(submissionId.prefix(8)) already \(activity.content.state.status.rawValue) — skipping polling")
            return
        }

        activePollingIds.insert(submissionId)
        
        print("🔄 [ProgressPolling] Starting progress polling for: \(submissionId) (skipInitialWait=\(skipInitialWait))")
        
        Task {
            defer {
                // Always remove from the active set when the task finishes so a
                // future call can restart polling if needed (e.g., after an app restart).
                Task { @MainActor in
                    self.activePollingIds.remove(submissionId)
                }
            }

            // Capture the URL linked to this submission while the placeholder is
            // still in reels[]. After syncHistoryFromBackend the placeholder may be
            // replaced by a reel with a different ID (uniqueID), so we need the URL
            // as a fallback key for the post-completion navigation lookup.
            let submissionURL: String? = await MainActor.run {
                self.reels.first(where: { $0.id == submissionId })?.url
            }

            // Wait before the first poll so the submission has time to be inserted
            // into the backend DB (the /fact-check HTTP round-trip + Celery task
            // enqueue can take a couple of seconds after the Share Extension fires).
            // Without this, poll #1 hits a 404 and logs a spurious error.
            // Skip the wait for duplicate URLs that are already marked completed.
            if !skipInitialWait {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 s
            }

            var isCompleted = false
            var pollCount = 0
            let maxPolls = 60 // 60 polls * 3s = 3 minutes max

            // Track whether we've successfully forwarded an APNs activity push token
            // to the backend for this submission. The token is issued asynchronously by
            // APNs and may not be available on the first poll — we check on every
            // iteration until it appears so the backend can send APNs progress updates.
            var activityTokenRegistered = false

            // Flush any token the Share Extension stored in the App Group before the
            // polling loop begins. The extension process is often killed before its
            // network call completes, so the App Group is the most reliable cache.
            if #available(iOS 16.1, *) {
                ReelProcessingActivityManager.shared.flushAppGroupPushToken(submissionId: submissionId)
            }

            while !isCompleted && pollCount < maxPolls {
                pollCount += 1

                // On each poll, check whether the Live Activity now has a push token
                // that we haven't forwarded yet. APNs typically issues the token within
                // a few seconds of activity creation; polling here catches it as soon
                // as it's available regardless of whether the async pushTokenUpdates
                // sequence has had a chance to emit (it may be suspended in background).
                if !activityTokenRegistered {
                    if #available(iOS 16.1, *) {
                        // Try the system Activity object first (most reliable).
                        var tokenFound = await ReelProcessingActivityManager.shared
                            .tryRegisterActivityPushToken(submissionId: submissionId)
                        // Fallback: try the App Group cache in case the Share Extension
                        // stored the token but the system Activity object doesn't have it yet.
                        if !tokenFound {
                            ReelProcessingActivityManager.shared.flushAppGroupPushToken(submissionId: submissionId)
                            // Re-check — flushAppGroupPushToken fires the network call;
                            // mark as registered so we stop retrying.
                            if let sharedDefaults = UserDefaults(suiteName: "group.rob"),
                               sharedDefaults.string(forKey: "activity_push_token_\(submissionId)") != nil {
                                tokenFound = true
                            }
                        }
                        if tokenFound {
                            activityTokenRegistered = true
                            print("🔑 [ProgressPolling] Activity push token registered on poll \(pollCount) for \(submissionId.prefix(8))")
                        }
                    }
                }

                do {
                    // Fetch current status from backend
                    let statusResponse = try await fetchSubmissionStatus(submissionId: submissionId)
                    
                    print("📊 [ProgressPolling] Poll \(pollCount): \(statusResponse.status) - \(statusResponse.progressPercentage)%")
                    
                    // Derive the ProcessingStatus from the backend response
                    let processingStatus = statusResponse.toProcessingStatus()
                    
                    // Update Live Activity with real backend data including status and time estimate.
                    // Skip this update when the status is "completed" — completeActivity() below
                    // will set the final state with its own AlertConfiguration.  Calling
                    // updateProgress here too would trigger a second buzz before completeActivity fires.
                    if statusResponse.status.lowercased() != "completed" {
                        await ReelProcessingActivityManager.shared.updateProgress(
                            submissionId: submissionId,
                            status: processingStatus,
                            progress: statusResponse.normalizedProgress,
                            message: statusResponse.currentStage,
                            estimatedSecondsRemaining: statusResponse.estimatedSecondsRemaining
                        )
                    }
                    
                    // Check if completed or failed
                    if statusResponse.status.lowercased() == "completed" {
                        print("✅ [ProgressPolling] Submission completed!")
                        isCompleted = true
                        // Remove from App Group immediately so the periodic checker
                        // cannot re-spawn a ghost activity for this submission.
                        if #available(iOS 16.1, *) {
                            ReelProcessingActivityManager.removeFromAppGroupPendingSubmissions(submissionId: submissionId)
                        }
                        // Drive the Dynamic Island to its completed state immediately.
                        await ReelProcessingActivityManager.shared.completeActivity(
                            submissionId: submissionId,
                            title: statusResponse.title ?? "Fact-Check Complete",
                            verdict: "Tap to view results"
                        )

                        // Eagerly update the SharedReel with full fact-check data from the
                        // status response so My Reels shows the result card immediately,
                        // without waiting for syncHistoryFromBackend to return.
                        let eagerClaims = (statusResponse.claims ?? []).map { $0.toClaimEntry() }
                        if !eagerClaims.isEmpty {
                            let eagerData = StoredFactCheckData(
                                title: statusResponse.title ?? "",
                                summary: eagerClaims[0].summary,
                                thumbnailURL: statusResponse.thumbnailUrl,
                                claims: eagerClaims,
                                datePosted: nil,
                                platform: statusResponse.platform,
                                aiGenerated: statusResponse.aiGenerated,
                                aiProbability: statusResponse.aiProbability,
                                reelID: statusResponse.uniqueID
                            )
                            await MainActor.run {
                                self.updateReelStatus(
                                    id: submissionId, status: .completed,
                                    resultId: statusResponse.title,
                                    factCheckData: eagerData
                                )
                            }
                        }

                        // Note: syncCompletedFactChecksFromAppGroup is intentionally NOT called
                        // here. The Darwin factCheckComplete notification fires the moment the
                        // Share Extension writes to the App Group, and that handler calls
                        // syncCompletedFactChecksFromAppGroup (with its own completeActivity).
                        // Calling it again from the polling path produces a double buzz.
                        // The background sync below keeps My Reels up to date instead.
                        Task { await self.syncHistoryFromBackend() }

                        // ── Navigate using embedded data (no local-cache dependency) ─────
                        //
                        // The status response now ships title + claims + thumbnail so we can
                        // navigate to the detail view directly, even for a fresh user whose
                        // reels[] array is empty and syncHistoryFromBackend returns nothing.
                        //
                        // Fallback: if embedded data is missing (old backend), look up in
                        // local reels[] using URL path-matching (ignores ?igsh= params).
                        await MainActor.run {
                            // Clear banner (both share-extension and in-app paths).
                            let stillPending = (UserDefaults(suiteName: "group.rob")?
                                .array(forKey: "pending_submissions") as? [[String: Any]])?.count ?? 0
                            if stillPending == 0 { self.activeProcessingURL = nil }
                            self.homeViewModel?.processingLink = nil
                            self.homeViewModel?.processingThumbnailURL = nil

                            guard self.homeViewModel != nil else { return }

                            // Do NOT navigate while in the background — the island is still
                            // visible on the lock screen / Dynamic Island and opening
                            // FactDetailView in background would immediately fire endActivity.
                            // The user will tap the island or open the app themselves.
                            guard !ReelProcessingActivityManager.shared.isAppInBackground() else {
                                print("⏸️ [Polling] App in background — deferring ShowFactCheckDetail navigation until foreground")
                                return
                            }

                            let navURL = submissionURL ?? ""

                            // ── Tier 1: embedded claims from status response ─────────────
                            let embeddedClaims = (statusResponse.claims ?? []).map { $0.toClaimEntry() }
                            if !embeddedClaims.isEmpty {
                                print("♻️ [Polling] Navigating from embedded status-response data")
                                let stored = StoredFactCheckData(
                                    title: statusResponse.title ?? "",
                                    summary: embeddedClaims[0].summary,
                                    thumbnailURL: statusResponse.thumbnailUrl,
                                    claims: embeddedClaims,
                                    datePosted: nil,
                                    platform: statusResponse.platform,
                                    aiGenerated: statusResponse.aiGenerated,
                                    aiProbability: statusResponse.aiProbability,
                                    reelID: statusResponse.uniqueID
                                )
                                NotificationCenter.default.post(
                                    name: NSNotification.Name("ShowFactCheckDetail"),
                                    object: nil,
                                    userInfo: ["factCheckItem": stored.toFactCheckItem(originalLink: navURL)]
                                )
                                return
                            }

                            // ── Tier 2: local reels[] lookup ─────────────────────────────
                            func urlPathsMatch(_ a: String, _ b: String) -> Bool {
                                guard a != b else { return true }
                                guard let ua = URL(string: a), let ub = URL(string: b) else { return false }
                                let pa = ua.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                                let pb = ub.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                                return ua.host?.lowercased() == ub.host?.lowercased() && pa == pb
                            }
                            let completed = self.reels.first(where: {
                                $0.id == submissionId && $0.status == .completed && $0.factCheckData != nil
                            }) ?? self.reels.first(where: {
                                guard !navURL.isEmpty else { return false }
                                return urlPathsMatch($0.url, navURL) && $0.status == .completed && $0.factCheckData != nil
                            })
                            guard let reel = completed, let data = reel.factCheckData else {
                                print("⚠️ [Polling] No completed reel found for navigation — sync will update My Reels in background")
                                return
                            }
                            NotificationCenter.default.post(
                                name: NSNotification.Name("ShowFactCheckDetail"),
                                object: nil,
                                userInfo: ["factCheckItem": data.toFactCheckItem(originalLink: reel.url)]
                            )
                        }

                        // Leave the Live Activity running in its completed state.
                        // dismissAllCompletedLiveActivities() will end it when the user
                        // opens the app, keeping the Dynamic Island visible until then.
                        break
                    } else if statusResponse.status.lowercased() == "failed" {
                        print("❌ [ProgressPolling] Submission failed")
                        // Remove from App Group immediately.
                        if #available(iOS 16.1, *) {
                            ReelProcessingActivityManager.removeFromAppGroupPendingSubmissions(submissionId: submissionId)
                        }
                        await MainActor.run {
                            let stillPending = (UserDefaults(suiteName: "group.rob")?
                                .array(forKey: "pending_submissions") as? [[String: Any]])?.count ?? 0
                            if stillPending == 0 { self.activeProcessingURL = nil }
                            self.homeViewModel?.processingLink = nil
                            self.homeViewModel?.processingThumbnailURL = nil
                        }
                        // Prefer the backend's current_stage (now a user-friendly message
                        // set by friendly_error_for_live_activity on the server). Fall back
                        // to errorMessage if currentStage is empty.
                        let rawMessage = statusResponse.currentStage.isEmpty
                            ? (statusResponse.errorMessage ?? "")
                            : statusResponse.currentStage
                        // Run through the client-side friendly filter as a safety net so
                        // nothing technical can ever leak to the user.
                        let displayMessage = ReelProcessingActivityManager.friendlyErrorMessage(rawMessage)
                        // Update the local SharedReel to .failed so SharedReelsView shows
                        // the error card instead of leaving the cell stuck in "processing".
                        await MainActor.run {
                            updateReelStatus(id: submissionId, status: .failed,
                                             errorMessage: displayMessage)
                        }
                        await ReelProcessingActivityManager.shared.failActivity(
                            submissionId: submissionId,
                            errorMessage: rawMessage
                        )
                        isCompleted = true
                        break
                    }
                    
                    // Wait 3 seconds before next poll
                    try await Task.sleep(nanoseconds: 3_000_000_000)
                    
                } catch {
                    // Poll 1-2 errors are expected if the submission hasn't reached the DB yet
                    // (race between Share Extension HTTP request and our first poll).
                    if pollCount <= 2 {
                        print("⏳ [ProgressPolling] Poll \(pollCount) not ready yet (submission may still be inserting) — retrying in 5s")
                    } else {
                        print("⚠️ [ProgressPolling] Error fetching status (poll \(pollCount)): \(error.localizedDescription)")
                        // Main app fallback: Share Extension may have been killed before its POST completed.
                        // If we get 404 and haven't tried yet, send the fact-check from the main app.
                        let is404 = error.localizedDescription.contains("404")
                        if is404, let url = submissionURL, !fallbackSentForSubmissions.contains(submissionId),
                           let userId = UserManager.shared.currentUserId, let sessionId = UserManager.shared.currentSessionId {
                            fallbackSentForSubmissions.insert(submissionId)
                            do {
                                let request = FactCheckRequest(link: url, userId: userId, sessionId: sessionId, submissionId: submissionId, deviceId: DeviceManager.deviceId)
                                _ = try await sendFactCheck(request)
                                print("🔄 [ProgressPolling] Main app fallback: sent fact-check for \(submissionId.prefix(8)) (Share Extension request may have been killed)")
                            } catch let fallbackError {
                                let errMsg = fallbackError.localizedDescription
                                print("⚠️ [ProgressPolling] Main app fallback failed: \(errMsg)")
                                // If the submission was rejected (daily limit, duplicate, unsupported URL, etc.) it
                                // will NEVER appear in the DB — stop polling and fail immediately.
                                let isTerminal = errMsg.contains("limit_reached") || errMsg.contains("duplicate") || errMsg.contains("invalid_url") || errMsg.contains("unsupported") || errMsg.contains("Unsupported")
                                if isTerminal {
                                    let userMessage: String
                                    if errMsg.contains("limit_reached") {
                                        userMessage = "Daily limit reached"
                                    } else if errMsg.contains("invalid_url") || errMsg.contains("unsupported") || errMsg.contains("Unsupported") {
                                        userMessage = "Unsupported URL format"
                                    } else {
                                        userMessage = "Already fact-checked"
                                    }
                                    await MainActor.run {
                                        self.updateReelStatus(id: submissionId, status: .failed, errorMessage: userMessage)
                                        if self.activeProcessingURL == submissionURL { self.activeProcessingURL = nil }
                                    }
                                    if #available(iOS 16.1, *) {
                                        ReelProcessingActivityManager.removeFromAppGroupPendingSubmissions(submissionId: submissionId)
                                        await ReelProcessingActivityManager.shared.failActivity(
                                            submissionId: submissionId,
                                            errorMessage: userMessage
                                        )
                                    }
                                    isCompleted = true
                                    break
                                }
                            }
                        }
                    }
                    if isCompleted { break }
                    try? await Task.sleep(nanoseconds: 5_000_000_000) // 5s back-off on error
                }
            }
            
            if !isCompleted && pollCount >= maxPolls {
                print("⏱️ [ProgressPolling] Timeout after \(maxPolls) polls (3 minutes)")
                if #available(iOS 16.1, *) {
                    ReelProcessingActivityManager.removeFromAppGroupPendingSubmissions(submissionId: submissionId)
                }
                await MainActor.run {
                    let stillPending = (UserDefaults(suiteName: "group.rob")?
                        .array(forKey: "pending_submissions") as? [[String: Any]])?.count ?? 0
                    if stillPending == 0 { self.activeProcessingURL = nil }
                }
                await ReelProcessingActivityManager.shared.failActivity(
                    submissionId: submissionId,
                    errorMessage: "Processing timeout"
                )
            }
        }
    }
    
    /// Fetches current submission status from backend via the shared NetworkService session.
    private func fetchSubmissionStatus(submissionId: String) async throws -> SubmissionStatusResponse {
        guard let userId = UserManager.shared.currentUserId,
              let sessionId = UserManager.shared.currentSessionId else {
            throw URLError(.userAuthenticationRequired)
        }
        return try await NetworkService.shared.fetchSubmissionStatus(
            submissionId: submissionId, userId: userId, sessionId: sessionId
        )
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
                Task { @MainActor [weak self] in
                    self?.markReelAsCompleted(factCheckId: factCheckId)
                }
            }
        }
    }
    
    // MARK: - Sync Completed Fact-Checks from Share Extension
    
    func syncCompletedFactChecksFromAppGroup() {
        let appGroupName = "group.rob"
        
        guard let sharedDefaults = UserDefaults(suiteName: appGroupName) else {
            print("⚠️ Could not access App Group: \(appGroupName)")
            return
        }
        
        // Check for COMPLETED fact-checks from Share Extension
        guard let completedFactChecks = sharedDefaults.array(forKey: "completed_fact_checks") as? [[String: Any]],
              !completedFactChecks.isEmpty else {
            print("📭 No completed fact-checks found in App Group")
            // Still update the banner — the submission may have been removed from
            // pending_submissions by removeFromAppGroupPendingSubmissions already.
            let pendingCount = (sharedDefaults.array(forKey: "pending_submissions") as? [[String: Any]])?.count ?? 0
            if pendingCount == 0 {
                activeProcessingURL = nil
            }
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
            if let existingIndex = reels.firstIndex(where: { $0.id == id }) {
                let existing = reels[existingIndex]
                if existing.status == .completed {
                    // Already fully completed — nothing more to do here. The activity
                    // will be cleaned up by dismissAllCompletedLiveActivities when the
                    // user foregrounds the app.
                    print("ℹ️ Fact-check \(id) already completed, skipping (will dismiss on foreground)")
                    continue
                }
                // Otherwise it's a placeholder .processing reel — fall through
                // so we update it with the real completion data below.
                print("ℹ️ Updating placeholder reel \(id.prefix(8)) from .processing → .completed")
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
                let aiGenerated = factCheckData["aiGenerated"] as? String
                let aiProbability = factCheckData["aiProbability"] as? Double
                let backendReelID = factCheckData["unique_id"] as? String
                    ?? factCheckData["uniqueID"] as? String

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
                    platform: platform,
                    aiGenerated: aiGenerated,
                    aiProbability: aiProbability,
                    reelID: backendReelID
                )
            } else {
                print("⚠️ Missing some fact-check fields, creating without stored data")
                storedData = nil
            }
            
            // Add/update the reel as completed in SharedReelManager with fact-check data.
            // If a placeholder .processing reel was inserted earlier, replace it in place;
            // otherwise insert at the top.
            let sharedReel = SharedReel(
                id: id,
                url: url,
                submittedAt: Date(timeIntervalSince1970: submittedAt),
                status: .completed,
                resultId: factCheckData["title"] as? String,
                errorMessage: nil,
                factCheckData: storedData
            )
            
            if let existingIndex = reels.firstIndex(where: { $0.id == id }) {
                reels[existingIndex] = sharedReel
                print("✅ Updated placeholder reel → completed for \(id.prefix(8))")
            } else {
                reels.insert(sharedReel, at: 0)
                print("✅ Synced completed fact-check \(id) to SharedReelManager with full data")
            }
            
            // Update the Live Activity to its completed state. Don't end it here —
            // it stays in the Dynamic Island showing the result until the user opens
            // the app, at which point dismissAllCompletedLiveActivities ends it.
            if #available(iOS 16.1, *) {
                Task {
                    let title = factCheckData["title"] as? String ?? "Fact-Check Complete"
                    let verdict = factCheckData["verdict"] as? String ?? "View Results"
                    await ReelProcessingActivityManager.shared.completeActivity(
                        submissionId: id,
                        title: title,
                        verdict: verdict
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

        // Schedule a background sync to resolve any social-page thumbnail URLs that
        // the direct fact-check response may have returned instead of real CDN URLs.
        scheduleThumbnailRefresh()
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

    // MARK: - Thumbnail Refresh

    /// Returns true when `urlString` is a real CDN image URL rather than a social page URL.
    /// Mirrors the `hasRealThumbnail` logic used in LinkPreviewView / FactDetailView.
    private static func isCDNThumbnail(_ urlString: String?) -> Bool {
        guard let s = urlString?.lowercased(), !s.isEmpty else { return false }
        let socialPagePatterns = [
            "instagram.com/reel", "instagram.com/p/",
            "tiktok.com/@", "tiktok.com/t/",
            "twitter.com/", "x.com/",
            "threads.net/",
            "youtube.com/shorts/", "youtu.be/"
        ]
        return !socialPagePatterns.contains(where: { s.contains($0) })
    }

    /// Schedules a targeted thumbnail patch to run once after a short delay.
    /// Only updates `factCheckData.thumbnailURL` fields that currently hold a social-page
    /// URL but now have a real CDN URL on the backend. Does NOT replace the whole reels[]
    /// array or trigger a feed refresh, eliminating the T+2s animated list swap.
    func scheduleThumbnailRefresh() {
        guard !thumbnailRefreshScheduled else { return }
        thumbnailRefreshScheduled = true
        print("🖼️ [ThumbnailRefresh] Scheduling targeted thumbnail patch...")
        Task {
            // Brief delay so the backend has time to persist the CDN URL.
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            await patchStaleThumbnails()
            await MainActor.run { self.thumbnailRefreshScheduled = false }
        }
    }

    /// Fetches user reels and updates only the thumbnail URLs that have graduated from
    /// social-page placeholders to real CDN images. No full list replacement or feed refresh.
    private func patchStaleThumbnails() async {
        guard let userId = UserManager.shared.currentUserId,
              let sessionId = UserManager.shared.currentSessionId else { return }

        do {
            let userReels = try await fetchUserReels(userId: userId, sessionId: sessionId)
            // Build an id → CDN-thumbnail map, ignoring entries without a real thumbnail.
            let thumbnailMap: [String: String] = userReels.reduce(into: [:]) { map, reel in
                if let url = reel.thumbnailUrl, Self.isCDNThumbnail(url) {
                    map[reel.id] = url
                }
            }
            guard !thumbnailMap.isEmpty else { return }

            var changed = false
            for idx in reels.indices {
                let reel = reels[idx]
                guard reel.factCheckData != nil else { continue }
                let currentThumb = reels[idx].factCheckData?.thumbnailURL
                // Only patch when the local thumbnail is absent or still a social-page URL.
                guard !Self.isCDNThumbnail(currentThumb) else { continue }
                if let newThumb = thumbnailMap[reel.id] {
                    reels[idx].factCheckData?.thumbnailURL = newThumb
                    changed = true
                    print("🖼️ [ThumbnailRefresh] Patched thumbnail for \(reel.id.prefix(8))")
                }
            }

            if changed {
                saveReels()
                print("🖼️ [ThumbnailRefresh] Thumbnail patch complete")
            } else {
                print("🖼️ [ThumbnailRefresh] No stale thumbnails found — skipping save")
            }
        } catch {
            print("⚠️ [ThumbnailRefresh] Failed to fetch thumbnails: \(error)")
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
    
    // MARK: - Sync History from Backend
    
    /// Syncs user's complete reel history from the backend
    func syncHistoryFromBackend() async {
        // Prevent multiple concurrent syncs from racing to replace reels[].
        guard !isSyncing else {
            print("⏭️ syncHistoryFromBackend skipped — sync already in progress")
            return
        }

        guard let userId = UserManager.shared.currentUserId,
              let sessionId = UserManager.shared.currentSessionId else {
            print("⚠️ Cannot sync: No user credentials")
            return
        }

        // Snapshot the user ID at the start of the sync so we can detect
        // mid-flight user changes and discard stale results.
        let syncingForUserId = userId

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
                    if status == .completed, !userReel.claims.isEmpty {
                        storedData = StoredFactCheckData(
                            title: userReel.title,
                            summary: userReel.summary ?? userReel.claims[0].summary,
                            thumbnailURL: userReel.thumbnailUrl,
                            claims: userReel.claims,
                            datePosted: nil,
                            platform: userReel.platform,
                            aiGenerated: userReel.aiGenerated,
                            aiProbability: userReel.aiProbability,
                            reelID: userReel.id
                        )
                    } else if status == .completed,
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
                            platform: userReel.platform,
                            aiGenerated: userReel.aiGenerated,
                            aiProbability: userReel.aiProbability,
                            reelID: userReel.id
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
                
                // Guard: discard results if the user changed while this sync was in flight.
                guard UserManager.shared.currentUserId == syncingForUserId else {
                    isSyncing = false
                    print("⚠️ Discarding sync results — user changed mid-flight (was \(syncingForUserId))")
                    return
                }

                // Always reload persisted reels for this user before merging,
                // as a safety net in case reels is still [] from a timing race.
                self.loadStoredReels()

                // If backend returned nothing, local reels are already loaded — done.
                guard !syncedReels.isEmpty else {
                    lastSyncDate = Date()
                    isSyncing = false
                    print("✅ Backend returned 0 reels — using \(reels.count) local reel(s)")
                    return
                }

                // Merge: keep in-flight local pending/processing reels the backend
                // doesn't know about yet, then layer backend results on top.
                let cutoff = Date().addingTimeInterval(-300)
                let appGroupPendingIds: Set<String> = {
                    guard let defaults = UserDefaults(suiteName: "group.rob"),
                          let subs = defaults.array(forKey: "pending_submissions") as? [[String: Any]] else {
                        return []
                    }
                    return Set(subs.compactMap { $0["id"] as? String })
                }()
                let localPendingReels = reels.filter { reel in
                    guard reel.status == .pending || reel.status == .processing else { return false }
                    return reel.submittedAt > cutoff && appGroupPendingIds.contains(reel.id)
                }
                let remoteIds = Set(syncedReels.map { $0.id })
                // Also collect URLs of completed synced reels so we can drop any
                // local placeholders that represent the same video (ID mismatch when
                // a duplicate URL was submitted — submissionId ≠ uniqueID).
                let completedRemoteURLs = Set(syncedReels.filter { $0.status == .completed }.map { $0.url })
                let uniqueLocalReels = localPendingReels.filter {
                    !remoteIds.contains($0.id) && !completedRemoteURLs.contains($0.url)
                }

                // Also keep local completed reels that aren't in the backend results yet.
                // This happens when syncHistoryFromBackend runs before the backend has
                // written the new reel to user_history (race condition after Share Extension
                // or fast polling completion). Without this merge step, the reel count
                // drops from N+1 → N on every sync until the backend catches up.
                //
                // IMPORTANT: also dedup by URL path (ignoring ?igsh= query params) so
                // a local reel whose submissionId ≠ backend unique_id doesn't show up
                // as a second identical card alongside the backend copy.
                let completedRemoteURLPaths: Set<String> = Set(
                    syncedReels.filter { $0.status == .completed }.compactMap {
                        URL(string: $0.url)?.path
                            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    }
                )
                let localCompletedNotYetSynced = reels.filter { reel in
                    guard reel.status == .completed,
                          !remoteIds.contains(reel.id),
                          reel.submittedAt > cutoff else { return false }
                    // Drop if the backend already has a completed reel for the same URL path
                    let localPath = URL(string: reel.url)?.path
                        .trimmingCharacters(in: CharacterSet(charactersIn: "/")) ?? reel.url
                    return !completedRemoteURLPaths.contains(localPath)
                }

                reels = uniqueLocalReels + localCompletedNotYetSynced + syncedReels
                saveReels()

                lastSyncDate = Date()
                isSyncing = false
                print("✅ Synced \(syncedReels.count) reels from backend")

                // Refresh home feed so newly-completed reels appear immediately
                homeViewModel?.refreshFeedAfterExternalFactCheck()
            }
            
        } catch {
            await MainActor.run {
                isSyncing = false
                uploadError = "Failed to sync: \(error.localizedDescription)"
            }
            print("❌ Error syncing history: \(error)")
        }
    }
    
    /// Fetches user's reels from the backend via the shared NetworkService session.
    private func fetchUserReels(userId: String, sessionId: String) async throws -> [UserReel] {
        try await NetworkService.shared.fetchUserReels(userId: userId, sessionId: sessionId)
    }
    
    // MARK: - Live Activity Management
    
    @available(iOS 16.1, *)
    func checkAndStartPendingLiveActivities() async {
        print("🔍 [LiveActivity] checkAndStartPendingLiveActivities called")
        // ── GHOST DIAGNOSTICS ──────────────────────────────────────────
        let sysNow = Activity<ReelProcessingActivityAttributes>.activities
        print("🔬 [GHOST_DIAG] checkAndStart entry: system=\(sysNow.count) tracked=\(ReelProcessingActivityManager.shared.currentActivities.count)")
        for a in sysNow {
            print("🔬 [GHOST_DIAG]   • sid=\(a.attributes.submissionId.prefix(8)) state=\(a.activityState) progress=\(Int(a.content.state.progress*100))% age=\(Int(Date().timeIntervalSince(a.attributes.startTime)))s")
        }
        // ───────────────────────────────────────────────────────────────

        // Check App Group for pending submissions that need Live Activities.
        // NOTE: Access the App Group BEFORE the debounce check so that the
        // latest_submission_id_for_polling flag is always consumed (even when
        // the debounce fires) and so the orphan-sweep guard below always runs.
        let appGroupName = "group.rob"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupName) else {
            print("❌ [LiveActivity] Could not access App Group: \(appGroupName)")
            return
        }

        // Force sync to get latest data
        sharedDefaults.synchronize()

        // ── FIX: consume the polling flag BEFORE any early-return so it is never lost ──
        var pollingIdsToStart: [String] = []
        if let submissionIdForPolling = sharedDefaults.string(forKey: "latest_submission_id_for_polling") {
            print("🔄 [LiveActivity] Found submission ID for progress polling: \(submissionIdForPolling)")
            sharedDefaults.removeObject(forKey: "latest_submission_id_for_polling")
            sharedDefaults.synchronize()
            pollingIdsToStart.append(submissionIdForPolling)
        }

        // Debounce: Skip the heavy work if we checked within the last 2 seconds.
        // Still start any pending polling tasks that were queued above.
        let now = Date()
        if let lastCheck = lastActivityCheckTime {
            let timeSinceLastCheck = now.timeIntervalSince(lastCheck)
            if timeSinceLastCheck < 2.0 {
                print("⏭️ [LiveActivity] Skipping check - last check was \(String(format: "%.1f", timeSinceLastCheck))s ago (debouncing)")
                for id in pollingIdsToStart { startProgressPolling(submissionId: id) }
                return
            }
        }
        lastActivityCheckTime = now
        
        print("📂 [LiveActivity] Accessing App Group: \(appGroupName)")

        // ── App Group diagnostic: dump all keys so we can see what Share Ext wrote ──
        let allKeys = sharedDefaults.dictionaryRepresentation().keys.sorted()
        print("🔑 [LiveActivity] App Group keys (\(allKeys.count)): \(allKeys.joined(separator: ", "))")
        // Check the write-test key the Share Extension deposits
        let diagTs = sharedDefaults.double(forKey: "_share_ext_diag_ts")
        print("🔑 [LiveActivity] Share Ext diag timestamp: \(diagTs > 0 ? "✅ \(diagTs)" : "❌ not present — Share Extension hasn't been run yet")")
        // ──────────────────────────────────────────────────────────────────────────────

        // Check and clear the hasPendingReel flag from Share Extension
        let hasPendingReel = sharedDefaults.bool(forKey: "hasPendingReel")
        if hasPendingReel {
            print("🚀 [LiveActivity] Share Extension flag detected - new reel submitted!")
            sharedDefaults.removeObject(forKey: "hasPendingReel")
            sharedDefaults.synchronize()
        }
        
        guard let submissions = sharedDefaults.array(forKey: "pending_submissions") as? [[String: Any]] else {
            print("📭 [LiveActivity] No pending_submissions array found in App Group")
            print("   Raw value: \(String(describing: sharedDefaults.object(forKey: "pending_submissions")))")
            activeProcessingURL = nil   // no pending submissions → hide banner
            for id in pollingIdsToStart { startProgressPolling(submissionId: id) }
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
            
            // ── FIX: Ensure there is a local .processing SharedReel for every live
            // share-extension submission so the orphan sweep in
            // dismissAllCompletedLiveActivities() never kills its Live Activity. ──
            if localReel == nil {
                let placeholderReel = SharedReel(
                    id: submissionId,
                    url: url,
                    submittedAt: Date(timeIntervalSince1970: submittedAt),
                    status: .processing,
                    platform: url.contains("tiktok") ? "tiktok" : "instagram"
                )
                reels.insert(placeholderReel, at: 0)
                print("   ➕ Inserted placeholder .processing reel for \(submissionId.prefix(8)) to protect from orphan sweep")
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
                let existingAge = Date().timeIntervalSince(existing.attributes.startTime)
                print("✅ [LiveActivity] Active Live Activity found for \(submissionId)")
                print("     State: \(existing.activityState)")
                print("     Age: \(Int(existingAge))s")
                print("     ✅ Keeping existing activity - it's already visible!")
                
                // Track it in our manager
                ReelProcessingActivityManager.shared.currentActivities[submissionId] = existing

                // ── FIX: also ensure progress polling is running for this submission ──
                if !pollingIdsToStart.contains(submissionId) {
                    pollingIdsToStart.append(submissionId)
                }

                startedCount += 1 // Count as started
                continue // Skip creating a duplicate
            }
            
            // Limit how many we start at once to avoid hitting the system limit
            if startedCount >= maxToStart {
                print("⏸️ [LiveActivity] Reached max new activities (\(maxToStart)), stopping for now")
                break
            }
            
            print("🎬 [LiveActivity] Preparing to start Live Activity for submission: \(submissionId)")
            print("   URL: \(url)")
            print("   Age: \(Int(age))s")

            // Always call startActivity — it handles both cases internally:
            //  • If the Share Extension already started an activity for this ID → wires up
            //    observePushToken (safe in background).
            //  • If no activity exists yet and app is in background → skips creation
            //    (ActivityKit Error 7) and logs; the activity will start on next foreground.
            //  • If no activity exists and app is in foreground → creates a new one.
            await ReelProcessingActivityManager.shared.startActivity(
                submissionId: submissionId,
                reelURL: url,
                thumbnailURL: nil
            )
            startedCount += 1

            // ── FIX: begin progress polling for every newly-started activity
            // (or delayed activity) so progress is fresh. ──
            if !pollingIdsToStart.contains(submissionId) {
                pollingIdsToStart.append(submissionId)
            }
        }
        
        // Start/resume progress polling for all submissions gathered above.
        for id in pollingIdsToStart {
            startProgressPolling(submissionId: id)
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
