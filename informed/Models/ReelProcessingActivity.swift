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
    let progressPercentage: Int // 0-100
    let currentStage: String
    let estimatedSecondsRemaining: Int
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case submissionId = "submission_id"
        case status
        case progressPercentage = "progress_percentage"
        case currentStage = "current_stage"
        case estimatedSecondsRemaining = "estimated_seconds_remaining"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
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

enum ProcessingStatus: String, Codable, Hashable {
    case submitting = "Submitting..."
    case downloading = "Downloading video"
    case processing = "Processing"
    case analyzing = "Analyzing content"
    case factChecking = "Fact-checking"
    case completed = "Completed"
    case failed = "Failed"

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
    
    func startActivity(submissionId: String, reelURL: String, thumbnailURL: String? = nil) async {
        print("🚀 [ActivityManager] startActivity called for: \(submissionId)")
        
        // Check if activity actually exists in the system (not just in our tracking dictionary)
        let existingSystemActivity = Activity<ReelProcessingActivityAttributes>.activities.first {
            $0.attributes.submissionId == submissionId
        }
        
        if let existing = existingSystemActivity {
            print("⚠️ [ActivityManager] System Live Activity already exists for \(submissionId)")
            print("   State: \(existing.activityState)")
            currentActivities[submissionId] = existing
            return
        }
        
        print("   No existing system activity found, creating new one...")
        
        // Check if Live Activities are available (they may not work on simulators or with personal dev accounts)
        let authInfo = ActivityAuthorizationInfo()
        let areEnabled = authInfo.areActivitiesEnabled
        
        print("📋 [ActivityManager] Live Activities status:")
        print("   - areActivitiesEnabled: \(areEnabled)")
        
        guard areEnabled else {
            print("⚠️ [ActivityManager] Live Activities are NOT enabled")
            print("   Possible reasons:")
            print("   - iOS Simulator (not supported)")
            print("   - Personal Apple Developer accounts (limited)")
            print("   - Missing entitlements")
            print("   - Settings → [App] → Live Activities is OFF")
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
        
        let initialState = ReelProcessingActivityAttributes.ContentState(
            status: .submitting,
            progress: 0.1,
            statusMessage: "Submitting your reel...",
            title: nil,
            verdict: nil,
            thumbnailURL: thumbnailURL,
            estimatedSecondsRemaining: 90
        )
        
        do {
            print("🎬 [ActivityManager] Requesting Live Activity from system...")
            let activity = try Activity<ReelProcessingActivityAttributes>.request(
                attributes: attributes,
                content: ActivityContent(state: initialState, staleDate: nil),
                pushType: nil
            )
            
            currentActivities[submissionId] = activity
            print("✅ [ActivityManager] ✨ Live Activity started successfully! ✨")
            print("   - Activity ID: \(activity.id)")
            print("   - Submission ID: \(submissionId)")
            print("   - Dynamic Island should now be visible!")
            
            // Note: Haptic feedback removed to prevent constant feedback loop
            // from periodic activity checks. Only user-triggered events get haptic.
            
        } catch {
            print("❌ [ActivityManager] Failed to start Live Activity")
            print("   Error: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("   Domain: \(nsError.domain), Code: \(nsError.code)")
            }
            print("   This is expected if:")
            print("   - Running on simulator")
            print("   - Personal Apple Developer account")
            print("   - Live Activities disabled in Settings")
            print("   - Device doesn't have Dynamic Island hardware")
            // Don't crash - just continue without Live Activity
        }
    }
    
    // MARK: - Update Activity
    
    func updateActivity(submissionId: String, status: ProcessingStatus, customMessage: String? = nil) async {
        guard let activity = currentActivities[submissionId] else {
            print("⚠️ No Live Activity found for submission \(submissionId)")
            return
        }
        
        let newState = ReelProcessingActivityAttributes.ContentState(
            status: status,
            progress: status.progressPercentage,
            statusMessage: customMessage ?? status.rawValue,
            title: activity.content.state.title,
            verdict: activity.content.state.verdict,
            thumbnailURL: activity.content.state.thumbnailURL,
            estimatedSecondsRemaining: activity.content.state.estimatedSecondsRemaining
        )
        
        await updateActivityState(activity: activity, newState: newState)
    }
    
    func updateProgress(submissionId: String, status: ProcessingStatus? = nil, progress: Double, message: String, estimatedSecondsRemaining: Int? = nil) async {
        guard let activity = currentActivities[submissionId] else {
            print("⚠️ No Live Activity found for submission \(submissionId)")
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
        guard let activity = currentActivities[submissionId] else {
            print("⚠️ No Live Activity found for submission \(submissionId)")
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
        // First try our in-memory tracking dict. If the app was killed and relaunched
        // currentActivities will be empty, so fall back to the system list.
        let activity: Activity<ReelProcessingActivityAttributes>?
        if let tracked = currentActivities[submissionId] {
            activity = tracked
        } else {
            activity = Activity<ReelProcessingActivityAttributes>.activities.first {
                $0.attributes.submissionId == submissionId
            }
            if activity != nil {
                print("🔍 [ActivityManager] Found untracked system activity for \(submissionId) — ending it")
            }
        }

        guard let activity = activity else {
            print("⚠️ [ActivityManager] No Live Activity found for submission \(submissionId) (checked both dict and system)")
            return
        }
        let finalContent = ActivityContent(state: activity.content.state, staleDate: nil)
        await activity.end(finalContent, dismissalPolicy: dismissalPolicy)
        currentActivities.removeValue(forKey: submissionId)
        print("✅ Live Activity ended for submission \(submissionId)")
    }
    
    func failActivity(submissionId: String, errorMessage: String) async {
        guard let activity = currentActivities[submissionId] else {
            print("⚠️ No Live Activity found for submission \(submissionId)")
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
