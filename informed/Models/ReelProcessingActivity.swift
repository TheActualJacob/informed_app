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
    
    var icon: String {
        switch self {
        case .submitting:
            return "arrow.up.circle.fill"
        case .downloading:
            return "arrow.down.circle.fill"
        case .processing, .analyzing, .factChecking:
            return "gearshape.fill"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .submitting:
            return .brandBlue.opacity(0.7)
        case .downloading:
            return .brandBlue.opacity(0.8)
        case .processing, .analyzing, .factChecking:
            return .brandBlue
        case .completed:
            return .brandGreen
        case .failed:
            return .brandRed
        }
    }
    
    var progressPercentage: Double {
        switch self {
        case .submitting:
            return 0.1
        case .downloading:
            return 0.2
        case .processing:
            return 0.4
        case .analyzing:
            return 0.6
        case .factChecking:
            return 0.85
        case .completed:
            return 1.0
        case .failed:
            return 0.0
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
                await activity.end(nil, dismissalPolicy: .immediate)
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
                contentState: initialState,
                pushType: nil // Use nil for personal dev accounts
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
            title: activity.contentState.title,
            verdict: activity.contentState.verdict,
            thumbnailURL: activity.contentState.thumbnailURL,
            estimatedSecondsRemaining: activity.contentState.estimatedSecondsRemaining
        )
        
        await updateActivityState(activity: activity, newState: newState)
    }
    
    func updateProgress(submissionId: String, progress: Double, message: String, estimatedSecondsRemaining: Int? = nil) async {
        guard let activity = currentActivities[submissionId] else {
            print("⚠️ No Live Activity found for submission \(submissionId)")
            return
        }
        
        let newState = ReelProcessingActivityAttributes.ContentState(
            status: activity.contentState.status,
            progress: min(max(progress, 0.0), 1.0),
            statusMessage: message,
            title: activity.contentState.title,
            verdict: activity.contentState.verdict,
            thumbnailURL: activity.contentState.thumbnailURL,
            estimatedSecondsRemaining: estimatedSecondsRemaining
        )
        
        await updateActivityState(activity: activity, newState: newState)
    }
    
    private func updateActivityState(activity: Activity<ReelProcessingActivityAttributes>, newState: ReelProcessingActivityAttributes.ContentState) async {
        do {
            await activity.update(using: newState)
            // Note: Haptic feedback removed to prevent constant feedback loop
            // Only completion/failure trigger haptic (user-facing events)
        } catch {
            print("⚠️ Could not update Live Activity: \(error.localizedDescription)")
            // Continue silently - not critical
        }
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
            thumbnailURL: activity.contentState.thumbnailURL,
            estimatedSecondsRemaining: 0
        )
        
        do {
            await activity.update(using: completedState)
            HapticManager.successImpact()
            
            // End activity after 8 seconds
            Task {
                try? await Task.sleep(nanoseconds: 8_000_000_000) // 8 seconds
                await endActivity(submissionId: submissionId)
            }
        } catch {
            print("⚠️ Could not complete Live Activity: \(error.localizedDescription)")
            // Try to end it anyway
            await endActivity(submissionId: submissionId)
        }
    }
    
    // MARK: - End Activity
    
    func endActivity(submissionId: String, dismissalPolicy: ActivityUIDismissalPolicy = .default) async {
        guard let activity = currentActivities[submissionId] else {
            print("⚠️ No Live Activity found for submission \(submissionId)")
            return
        }
        
        let finalState = activity.contentState
        
        await activity.end(using: finalState, dismissalPolicy: dismissalPolicy)
        currentActivities.removeValue(forKey: submissionId)
        
        print("✅ Live Activity ended for submission \(submissionId)")
    }
    
    func failActivity(submissionId: String, errorMessage: String) async {
        guard let activity = currentActivities[submissionId] else {
            print("⚠️ No Live Activity found for submission \(submissionId)")
            return
        }
        
        let failedState = ReelProcessingActivityAttributes.ContentState(
            status: .failed,
            progress: 0.0,
            statusMessage: errorMessage,
            title: nil,
            verdict: nil,
            thumbnailURL: activity.contentState.thumbnailURL,
            estimatedSecondsRemaining: 0
        )
        
        do {
            await activity.update(using: failedState)
            HapticManager.errorImpact()
            
            // End activity after 5 seconds
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                await endActivity(submissionId: submissionId)
            }
        } catch {
            print("⚠️ Could not fail Live Activity: \(error.localizedDescription)")
            // Try to end it anyway
            await endActivity(submissionId: submissionId)
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
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        
        currentActivities.removeAll()
        print("✅ [ActivityManager] All activities ended")
    }
}
