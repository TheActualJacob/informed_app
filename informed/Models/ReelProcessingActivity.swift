//
//  ReelProcessingActivity.swift
//  informed
//
//  Live Activity models for reel processing with Dynamic Island support
//

import Foundation
import ActivityKit
import SwiftUI
import Combine

// MARK: - Backend Progress Response

/// Response from GET /api/submission-status/:id for real-time progress tracking
struct SubmissionStatusResponse: Codable {
    let submissionId: String
    let status: String // "submitting", "downloading", "processing", "analyzing", "fact_checking", "completed", "failed"
    let progressPercentage: Int
    let currentStage: String
    let estimatedSecondsRemaining: Int
    let createdAt: String?
    let updatedAt: String?
    let errorMessage: String?

    enum CodingKeys: String, CodingKey {
        case submissionId              = "submission_id"
        case status
        case progressPercentage        = "progress_percentage"
        case currentStage              = "current_stage"
        case estimatedSecondsRemaining = "estimated_seconds_remaining"
        case createdAt                 = "created_at"
        case updatedAt                 = "updated_at"
        case errorMessage              = "error_message"
    }
    
    /// Converts backend status string to ProcessingStatus enum
    func toProcessingStatus() -> ProcessingStatus {
        switch status.lowercased() {
        case "submitting":
            return .submitting
        case "downloading":
            return .downloading
        case "processing":
            return .processing
        case "analyzing":
            return .analyzing
        case "fact_checking", "factchecking", "fact-checking":
            return .factChecking
        case "completed":
            return .completed
        case "failed":
            return .failed
        default:
            return .processing
        }
    }
    
    /// Returns progress as 0.0 to 1.0
    var normalizedProgress: Double {
        return Double(progressPercentage) / 100.0
    }
}

// MARK: - Processing Status

// Raw values intentionally match the backend's snake_case status strings so that
// APNs push-to-start / update payloads can be decoded by JSONDecoder without
// a custom Decodable implementation.  Display text lives in `displayName` below.
enum ProcessingStatus: String, Codable, Hashable {
    case submitting   = "submitting"
    case downloading  = "downloading"
    case processing   = "processing"
    case analyzing    = "analyzing"
    case factChecking = "fact_checking"
    case completed    = "completed"
    case failed       = "failed"

    // MARK: - Human-readable label (was formerly the raw value)
    var displayName: String {
        switch self {
        case .submitting:   return "Submitting..."
        case .downloading:  return "Downloading video"
        case .processing:   return "Processing"
        case .analyzing:    return "Analyzing content"
        case .factChecking: return "Fact-checking"
        case .completed:    return "Completed"
        case .failed:       return "Failed"
        }
    }

    // MARK: - Per-stage SF Symbols
    var icon: String {
        switch self {
        case .submitting:   return "arrow.up.circle.fill"
        case .downloading:  return "arrow.down.to.line.circle.fill"
        case .processing:   return "waveform.circle.fill"
        case .analyzing:    return "sparkle.magnifyingglass"
        case .factChecking: return "magnifyingglass.circle.fill"
        case .completed:    return "checkmark.seal.fill"
        case .failed:       return "xmark.circle.fill"
        }
    }

    // MARK: - Per-stage primary colors
    var color: Color {
        switch self {
        case .submitting:   return Color(red: 0.45, green: 0.55, blue: 0.70)  // cool slate
        case .downloading:  return Color.brandTeal                              // teal
        case .processing:   return Color.brandBlue                             // blue
        case .analyzing:    return Color(red: 0.45, green: 0.25, blue: 0.90)  // indigo/purple
        case .factChecking: return Color(red: 0.98, green: 0.58, blue: 0.12)  // amber/orange
        case .completed:    return Color.brandGreen
        case .failed:       return Color.brandRed
        }
    }

    // MARK: - Per-stage secondary colors (for gradients)
    var secondaryColor: Color {
        switch self {
        case .submitting:   return Color(red: 0.55, green: 0.68, blue: 0.88)
        case .downloading:  return Color(red: 0.25, green: 0.90, blue: 0.80)
        case .processing:   return Color.brandTeal
        case .analyzing:    return Color(red: 0.65, green: 0.30, blue: 1.00)
        case .factChecking: return Color(red: 0.98, green: 0.80, blue: 0.15)
        case .completed:    return Color(red: 0.35, green: 0.92, blue: 0.60)
        case .failed:       return Color(red: 1.00, green: 0.55, blue: 0.45)
        }
    }

    // MARK: - Short label shown in the Dynamic Island center
    var shortLabel: String {
        switch self {
        case .submitting:   return "Submitting"
        case .downloading:  return "Downloading"
        case .processing:   return "Processing"
        case .analyzing:    return "Analyzing"
        case .factChecking: return "Verifying"
        case .completed:    return "Complete!"
        case .failed:       return "Failed"
        }
    }

    // MARK: - Progress percentages
    var progressPercentage: Double {
        switch self {
        case .submitting:   return 0.10
        case .downloading:  return 0.25
        case .processing:   return 0.45
        case .analyzing:    return 0.70
        case .factChecking: return 0.88
        case .completed:    return 1.00
        case .failed:       return 0.00
        }
    }
}

// MARK: - Activity Attributes

struct ReelProcessingActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var status: ProcessingStatus
        var progress: Double // 0.0 to 1.0
        var statusMessage: String
        var title: String? // Set when completed
        var verdict: String? // Set when completed
        var thumbnailURL: String? // Optional thumbnail URL
        var estimatedSecondsRemaining: Int? // Backend-provided time estimate
    }
    
    // Static attributes that don't change during the activity
    let reelURL: String
    let submissionId: String
    let startTime: Date
}

// MARK: - Activity Manager

@available(iOS 16.1, *)
@MainActor
class ReelProcessingActivityManager: ObservableObject {
    static let shared = ReelProcessingActivityManager()
    
    var currentActivities: [String: Activity<ReelProcessingActivityAttributes>] = [:]

    /// Injected by the main app target on startup. Called with each (token, submissionId) pair
    /// whenever a Live Activity's APNs push token is issued or rotated.
    /// Extensions leave this nil — they handle token forwarding via App Group storage instead.
    var onActivityPushToken: ((String, String) async -> Void)?

    /// Injected by the main app on startup. Returns whether the app is currently in the
    /// background. Extensions leave this as the default `{ false }` — they are always
    /// active when running, and `UIApplication.shared` is unavailable in extension targets.
    var isAppInBackground: () -> Bool = { false }

    init() {
        // Note: Removed automatic cleanup on init to prevent ending active Live Activities
        // Cleanup is now only called explicitly when needed (e.g., on app becoming active after long period)
        print("✅ [ActivityManager] Initialized (cleanup deferred)")
    }
    
    // MARK: - Cleanup Stale Activities
    
    func cleanupStaleActivities() async {
        print("🧹 [ActivityManager] Cleaning up stale Live Activities...")
        
        let allActivities = Activity<ReelProcessingActivityAttributes>.activities
        print("   Found \(allActivities.count) existing system activities")
        
        if allActivities.isEmpty {
            print("   No system activities found - clean slate!")
            print("✅ [ActivityManager] Cleanup complete. Active: 0")
            return
        }
        
        let now = Date()
        let staleThreshold: TimeInterval = 600 // 10 minutes
        var endedCount = 0
        
        // Only end activities older than 10 minutes (likely orphaned/stale)
        for activity in allActivities {
            let submissionId = activity.attributes.submissionId
            let age = now.timeIntervalSince(activity.attributes.startTime)
            
            print("   Checking activity: \(submissionId)")
            print("     - Age: \(Int(age))s")
            print("     - State: \(activity.activityState)")
            
            if age > staleThreshold {
                print("     - ❌ STALE (>\(Int(staleThreshold))s) - ending...")
                await activity.end(ActivityContent(state: activity.content.state, staleDate: nil), dismissalPolicy: .immediate)
                endedCount += 1
            } else {
                print("     - ✅ Fresh, keeping alive")
                // Track this activity so we don't lose it
                currentActivities[submissionId] = activity
            }
        }
        
        print("✅ [ActivityManager] Cleanup complete. Ended \(endedCount)/\(allActivities.count) stale activities. Kept: \(currentActivities.count)")
    }
    
    // MARK: - Start Activity
    
    func startActivity(submissionId: String, reelURL: String, thumbnailURL: String? = nil, inheritedState: ReelProcessingActivityAttributes.ContentState? = nil) async {
        print("🚀 [ActivityManager] startActivity called for: \(submissionId.prefix(8))…")
        print("🔬 [GHOST_DIAG] startActivity: currentActivities.count=\(currentActivities.count) systemActivities.count=\(Activity<ReelProcessingActivityAttributes>.activities.count)")
        
        // Check if activity actually exists in the system (not just in our tracking dictionary).
        // Skip .ended activities so a recursive upgrade call doesn't re-enter this branch.
        let existingSystemActivity = Activity<ReelProcessingActivityAttributes>.activities.first {
            $0.attributes.submissionId == submissionId && $0.activityState != .ended
        }
        
        if let existing = existingSystemActivity {
            print("⚠️ [ActivityManager] System Live Activity already exists for \(submissionId.prefix(8)) state=\(existing.activityState)")

            // If the Share Extension created this activity with pushType: nil (because it
            // lacked aps-environment entitlement), it has no push token and the backend
            // cannot send Dynamic Island updates. Upgrade it now that the main app is in
            // the foreground by ending the tokenless activity and starting a fresh one.
            let hasNoPushToken = existing.pushToken == nil
            if hasNoPushToken && !isAppInBackground() {
                print("🔄 [ActivityManager] Upgrading pushType:nil activity to pushType:.token for \(submissionId.prefix(8))…")
                let existingState = existing.content.state
                // End the old activity silently — no UI disruption because we immediately
                // start a replacement with identical content below.
                await existing.end(
                    ActivityContent(state: existingState, staleDate: nil),
                    dismissalPolicy: .immediate
                )
                currentActivities.removeValue(forKey: submissionId)
                // Re-enter startActivity with the preserved content state so the new
                // activity picks up right where the old one left off.
                await startActivity(submissionId: submissionId, reelURL: reelURL, thumbnailURL: thumbnailURL, inheritedState: existingState)
                return
            } else {
                currentActivities[submissionId] = existing
                // Set up the ongoing push-token rotation observer.
                // This is safe in the background; only CREATING activities requires foreground.
                observePushToken(for: existing, submissionId: submissionId)
                // The Share Extension stores the initial push token in App Group the moment
                // it arrives because the extension process may be killed before the main app
                // wakes up and `pushTokenUpdates` can re-emit it. Read and forward it now so
                // the backend can start pushing updates without waiting for the user to open
                // the app.
                flushAppGroupPushToken(submissionId: submissionId)
                return
            }
        }

        // ActivityKit Error 7: creating a NEW Live Activity requires the app to be in the foreground.
        // If we're in the background (woken by Darwin notification), bail out here.
        // The activity will be created the next time the user opens the app.
        guard !isAppInBackground() else {
            print("⚠️ [ActivityManager] App in background — cannot create new Live Activity (ActivityKit Error 7). Will start when foregrounded.")
            return
        }
        
        print("   No existing system activity found, creating new one...")
        
        let authInfo = ActivityAuthorizationInfo()
        let areEnabled = authInfo.areActivitiesEnabled
        
        print("📋 [ActivityManager] Live Activities status:")
        print("   - areActivitiesEnabled: \(areEnabled)")
        
        guard areEnabled else {
            print("⚠️ [ActivityManager] Live Activities are NOT enabled")
            return
        }
        
        print("✅ [ActivityManager] Live Activities are enabled, creating activity...")
        
        // Check if we're at the limit (8 activities max)
        let existingCount = Activity<ReelProcessingActivityAttributes>.activities.count
        if existingCount >= 8 {
            print("⚠️ [ActivityManager] At activity limit (\(existingCount)/8), cleaning up old activities...")
            await cleanupStaleActivities()
        }
        
        let attributes = ReelProcessingActivityAttributes(
            reelURL: reelURL,
            submissionId: submissionId,
            startTime: Date()
        )
        
        // Use the inherited state when upgrading a pushType:nil activity so the
        // replacement activity shows the current progress, not the initial state.
        let initialState = inheritedState ?? ReelProcessingActivityAttributes.ContentState(
            status: .submitting,
            progress: 0.1,
            statusMessage: "Submitting your reel...",
            title: nil,
            verdict: nil,
            thumbnailURL: thumbnailURL,
            estimatedSecondsRemaining: 90
        )
        
        do {
            print("🎬 [ActivityManager] Requesting Live Activity from system…")
            let activity = try Activity<ReelProcessingActivityAttributes>.request(
                attributes: attributes,
                content: ActivityContent(state: initialState, staleDate: nil),
                pushType: .token
            )
            
            currentActivities[submissionId] = activity
            print("✅ [ActivityManager] ✨ Live Activity started! id=\(activity.id) sid=\(submissionId.prefix(8))")
            print("🔬 [GHOST_DIAG] startActivity SUCCESS: currentActivities.count=\(currentActivities.count) systemActivities.count=\(Activity<ReelProcessingActivityAttributes>.activities.count)")
            
            observePushToken(for: activity, submissionId: submissionId)
            
        } catch {
            print("❌ [ActivityManager] Failed to start Live Activity: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("   Domain: \(nsError.domain), Code: \(nsError.code)")
            }
        }
    }
    
    // MARK: - Push Token Observation

    /// Observes push token updates for an activity and forwards each token via `onActivityPushToken`.
    /// Call this whenever a new activity is started OR when an existing activity is discovered
    /// (e.g. one started by the Share Extension before the main app woke up).
    func observePushToken(for activity: Activity<ReelProcessingActivityAttributes>, submissionId: String) {
        Task {
            for await pushToken in activity.pushTokenUpdates {
                let tokenString = pushToken.map { String(format: "%02x", $0) }.joined()
                print("🔑 [ActivityManager] Activity push token for \(submissionId.prefix(8)): \(tokenString)")
                await onActivityPushToken?(tokenString, submissionId)
            }
        }
    }
    
    // MARK: - App Group Token Flush

    /// Reads the activity push token that the Share Extension stored in App Group and
    /// immediately forwards it via `onActivityPushToken`.
    ///
    /// The Share Extension stores the token synchronously the moment `pushTokenUpdates`
    /// emits, but the extension process may be killed before its own network call
    /// completes. This method is the main app's reliable fallback: it runs in the
    /// background immediately after an existing Share-Extension activity is discovered,
    /// giving the backend the token it needs to push Dynamic Island updates without
    /// requiring the user to open the app.
    ///
    /// The key is intentionally NOT cleared after the send so that a token rotation
    /// (new value written by iOS) is also picked up on the next check. The backend
    /// endpoint is idempotent — registering the same token twice is harmless.
    func flushAppGroupPushToken(submissionId: String) {
        guard let sharedDefaults = UserDefaults(suiteName: "group.rob"),
              let storedToken = sharedDefaults.string(forKey: "activity_push_token_\(submissionId)") else {
            return
        }
        print("📦 [ActivityManager] Found App Group push token for \(submissionId.prefix(8)) — forwarding to backend")
        Task {
            await onActivityPushToken?(storedToken, submissionId)
        }
    }

    // MARK: - Update Activity
    
    /// Re-registers an activity under a new submission ID (e.g. when the backend
    /// returns a different ID than the local UUID we generated).
    func reRegisterActivity(oldSubmissionId: String, newSubmissionId: String) {
        if let activity = currentActivities[oldSubmissionId] {
            currentActivities[newSubmissionId] = activity
            currentActivities.removeValue(forKey: oldSubmissionId)
            print("🔄 [ActivityManager] Re-registered activity: \(oldSubmissionId.prefix(8)) → \(newSubmissionId.prefix(8))")
        } else if let system = Activity<ReelProcessingActivityAttributes>.activities.first(where: {
            $0.attributes.submissionId == oldSubmissionId
        }) {
            currentActivities[newSubmissionId] = system
            print("🔄 [ActivityManager] Re-registered system activity: \(oldSubmissionId.prefix(8)) → \(newSubmissionId.prefix(8))")
        } else {
            print("⚠️ [ActivityManager] reRegisterActivity: no activity found for old ID \(oldSubmissionId.prefix(8))")
        }
    }

    /// Resolves a tracked or system-level activity for the given submissionId.
    /// Falls back to scanning `Activity.activities` so that updates still reach
    /// an activity that was started before the current app session (e.g. after
    /// the Share Extension woke the app and the activity manager was freshly
    /// initialised).
    private func resolvedActivity(for submissionId: String) -> Activity<ReelProcessingActivityAttributes>? {
        if let tracked = currentActivities[submissionId] { return tracked }
        if let system = Activity<ReelProcessingActivityAttributes>.activities.first(where: {
            $0.attributes.submissionId == submissionId
        }) {
            print("⚠️ [ActivityManager] resolved untracked system activity for \(submissionId.prefix(8)) — caching it")
            currentActivities[submissionId] = system
            return system
        }
        return nil
    }

    func updateActivity(submissionId: String, status: ProcessingStatus, customMessage: String? = nil) async {
        guard let activity = resolvedActivity(for: submissionId) else {
            print("⚠️ [ActivityManager] updateActivity: no activity found for \(submissionId.prefix(8)) — skipping")
            return
        }
        
        let newState = ReelProcessingActivityAttributes.ContentState(
            status: status,
            progress: status.progressPercentage,
            statusMessage: customMessage ?? status.displayName,
            title: activity.content.state.title,
            verdict: activity.content.state.verdict,
            thumbnailURL: activity.content.state.thumbnailURL,
            estimatedSecondsRemaining: activity.content.state.estimatedSecondsRemaining
        )
        
        await updateActivityState(activity: activity, newState: newState)
    }
    
    func updateProgress(submissionId: String, status: ProcessingStatus? = nil, progress: Double, message: String, estimatedSecondsRemaining: Int? = nil) async {
        guard let activity = resolvedActivity(for: submissionId) else {
            print("⚠️ [ActivityManager] updateProgress: no activity found for \(submissionId.prefix(8)) — skipping")
            return
        }
        
        // Use the explicitly-passed status, or keep the old one as a fallback
        let resolvedStatus = status ?? activity.content.state.status
        
        let newState = ReelProcessingActivityAttributes.ContentState(
            status: resolvedStatus,
            progress: min(max(progress, 0.0), 1.0),
            statusMessage: message,
            title: activity.content.state.title,
            verdict: activity.content.state.verdict,
            thumbnailURL: activity.content.state.thumbnailURL,
            estimatedSecondsRemaining: estimatedSecondsRemaining
        )
        
        print("🎨 [ActivityManager] Updating activity: status=\(resolvedStatus.rawValue) progress=\(Int(progress*100))% msg=\(message)")
        await updateActivityState(activity: activity, newState: newState)
    }
    
    private func updateActivityState(activity: Activity<ReelProcessingActivityAttributes>, newState: ReelProcessingActivityAttributes.ContentState) async {
        await activity.update(ActivityContent(state: newState, staleDate: nil))
    }
    
    // MARK: - Complete Activity
    
    func completeActivity(submissionId: String, title: String, verdict: String) async {
        // Prefer the tracked instance; fall back to a system-level lookup so we
        // don't silently bail when a race caused the activity to be missed.
        let activity: Activity<ReelProcessingActivityAttributes>?
        if let tracked = currentActivities[submissionId] {
            activity = tracked
        } else {
            activity = Activity<ReelProcessingActivityAttributes>.activities.first {
                $0.attributes.submissionId == submissionId
            }
            if let a = activity {
                print("⚠️ [ActivityManager] completeActivity: found untracked system activity for \(submissionId) — using it")
                currentActivities[submissionId] = a
            }
        }
        
        guard let activity = activity else {
            print("⚠️ [ActivityManager] completeActivity: no activity found for \(submissionId)")
            return
        }
        
        let completedState = ReelProcessingActivityAttributes.ContentState(
            status: .completed,
            progress: 1.0,
            statusMessage: "Tap to view results",
            title: title,
            verdict: verdict,
            thumbnailURL: activity.content.state.thumbnailURL,
            estimatedSecondsRemaining: 0
        )
        
        // AlertConfiguration triggers the Dynamic Island to auto-expand
        let alertConfig = AlertConfiguration(
            title: "Fact-check complete!",
            body: LocalizedStringResource(stringLiteral: "\(title) — \(verdict)"),
            sound: .default
        )
        
        await activity.update(
            ActivityContent(state: completedState, staleDate: nil),
            alertConfiguration: alertConfig
        )
        HapticManager.successImpact()
    }
    
    // MARK: - End Activity
    
    func endActivity(submissionId: String, dismissalPolicy: ActivityUIDismissalPolicy = .default) async {
        print("🔬 [GHOST_DIAG] endActivity called for sid=\(submissionId.prefix(8)) policy=\(dismissalPolicy)")
        // Prefer the tracked instance; fall back to a system-level lookup.
        let activity: Activity<ReelProcessingActivityAttributes>?
        if let tracked = currentActivities[submissionId] {
            activity = tracked
            print("🔬 [GHOST_DIAG]   found in currentActivities ✓")
        } else {
            activity = Activity<ReelProcessingActivityAttributes>.activities.first {
                $0.attributes.submissionId == submissionId
            }
            if let a = activity {
                print("🔬 [GHOST_DIAG]   NOT in currentActivities — found in system (state=\(a.activityState)) ⚠️")
            } else {
                print("🔬 [GHOST_DIAG]   NOT found anywhere ❌ (currentActivities.count=\(currentActivities.count) system.count=\(Activity<ReelProcessingActivityAttributes>.activities.count))")
            }
        }
        
        guard let activity = activity else {
            print("⚠️ [ActivityManager] endActivity: no activity found for \(submissionId.prefix(8))")
            return
        }
        let finalContent = ActivityContent(state: activity.content.state, staleDate: nil)
        await activity.end(finalContent, dismissalPolicy: dismissalPolicy)
        currentActivities.removeValue(forKey: submissionId)
        print("✅ Live Activity ended for submission \(submissionId.prefix(8))")
        // Critically: remove this submission from the App Group pending_submissions so that
        // checkAndStartPendingLiveActivities can never re-create a ghost activity for it.
        // This is the root cause of the ghost: the App Group entry outlives the activity
        // (especially after syncHistoryFromBackend wipes the local reels array).
        Self.removeFromAppGroupPendingSubmissions(submissionId: submissionId)
    }
    
    func failActivity(submissionId: String, errorMessage: String) async {
        // Prefer the tracked instance; fall back to a system-level lookup.
        let activity: Activity<ReelProcessingActivityAttributes>?
        if let tracked = currentActivities[submissionId] {
            activity = tracked
        } else {
            activity = Activity<ReelProcessingActivityAttributes>.activities.first {
                $0.attributes.submissionId == submissionId
            }
            if let a = activity {
                print("⚠️ [ActivityManager] failActivity: found untracked system activity for \(submissionId) — using it")
                currentActivities[submissionId] = a
            }
        }
        
        guard let activity = activity else {
            print("⚠️ [ActivityManager] failActivity: no activity found for \(submissionId)")
            return
        }
        
        // Make the error message user-friendly and concise for the island
        let friendlyMessage = Self.friendlyErrorMessage(errorMessage)
        
        let failedState = ReelProcessingActivityAttributes.ContentState(
            status: .failed,
            progress: activity.content.state.progress, // keep last known progress
            statusMessage: friendlyMessage,
            title: nil,
            verdict: nil,
            thumbnailURL: activity.content.state.thumbnailURL,
            estimatedSecondsRemaining: 0
        )
        
        let alertConfig = AlertConfiguration(
            title: "Fact-check failed",
            body: LocalizedStringResource(stringLiteral: friendlyMessage),
            sound: .default
        )
        
        await activity.update(ActivityContent(state: failedState, staleDate: nil), alertConfiguration: alertConfig)
        HapticManager.errorImpact()
        
        // Show the error for 8 seconds, then dismiss
        Task {
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            await endActivity(submissionId: submissionId, dismissalPolicy: .immediate)
        }
    }
    
    /// Converts raw backend/network error strings into short, user-readable messages
    private static func friendlyErrorMessage(_ raw: String) -> String {
        let lower = raw.lowercased()
        if lower.contains("timeout") || lower.contains("timed out") {
            return "Took too long — please try again"
        }
        if lower.contains("network") || lower.contains("internet") || lower.contains("offline") {
            return "No internet connection"
        }
        if lower.contains("not found") || lower.contains("404") {
            return "Video not found or unavailable"
        }
        if lower.contains("private") || lower.contains("unauthori") || lower.contains("forbidden") {
            return "Video is private or restricted"
        }
        if lower.contains("unsupported") || lower.contains("platform") {
            return "Unsupported video format"
        }
        if lower.contains("processing") {
            return "Processing error — please try again"
        }
        // Truncate long raw messages so they fit in the island
        if raw.count > 60 {
            return String(raw.prefix(57)) + "…"
        }
        return raw
    }
    
    // MARK: - App Group Cleanup
    
    /// Removes a submission from the App Group `pending_submissions` list so that
    /// `checkAndStartPendingLiveActivities` cannot resurrect a ghost activity for it.
    static func removeFromAppGroupPendingSubmissions(submissionId: String) {
        let appGroupName = "group.rob"
        guard let defaults = UserDefaults(suiteName: appGroupName) else { return }
        guard var submissions = defaults.array(forKey: "pending_submissions") as? [[String: Any]] else { return }
        let before = submissions.count
        submissions.removeAll {
            ($0["id"] as? String)?.lowercased() == submissionId.lowercased()
        }
        if submissions.count < before {
            defaults.set(submissions, forKey: "pending_submissions")
            defaults.synchronize()
            print("🗑️ [ActivityManager] Removed \(submissionId.prefix(8)) from App Group pending_submissions (\(before)→\(submissions.count))")
        }
    }
    
    // MARK: - Cleanup
    
    func endAllActivities() async {
        print("🧹 [ActivityManager] Ending all active Live Activities...")
        
        // End all tracked activities
        for (submissionId, _) in currentActivities {
            await endActivity(submissionId: submissionId)
        }
        
        // Also end any system activities we might not be tracking
        for activity in Activity<ReelProcessingActivityAttributes>.activities {
            await activity.end(ActivityContent(state: activity.content.state, staleDate: nil), dismissalPolicy: .immediate)
        }
        
        currentActivities.removeAll()
        print("✅ [ActivityManager] All activities ended")
    }
}
