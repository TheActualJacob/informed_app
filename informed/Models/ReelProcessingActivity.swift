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
import UserNotifications

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
    // Embedded fact-check data — present when status == "completed".
    // Allows iOS to navigate directly without needing a separate sync call.
    let title: String?
    let thumbnailUrl: String?
    let platform: String?
    let aiGenerated: String?
    let aiProbability: Double?
    let claims: [StatusClaimEntry]?
    /// The backend uniqueID for the completed fact-check — used to build the shareable link.
    let uniqueID: String?
    /// Source video length vs. the analysed portion (backend caps at 5 minutes).
    let mediaDurationSeconds: Int?
    let analyzedDurationSeconds: Int?

    enum CodingKeys: String, CodingKey {
        case submissionId              = "submission_id"
        case status
        case progressPercentage        = "progress_percentage"
        case currentStage              = "current_stage"
        case estimatedSecondsRemaining = "estimated_seconds_remaining"
        case createdAt                 = "created_at"
        case updatedAt                 = "updated_at"
        case errorMessage              = "error_message"
        case title
        case thumbnailUrl              = "thumbnail_url"
        case platform
        case aiGenerated
        case aiProbability
        case claims
        case uniqueID
        case mediaDurationSeconds, analyzedDurationSeconds
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

    /// The primary claim's verdict ("True", "False", "Misleading", …) when the
    /// backend embedded claims in a completed response. Nil while processing.
    var primaryVerdict: String? {
        guard let v = claims?.first?.verdict, !v.isEmpty else { return nil }
        return v
    }
}

/// Lightweight claim struct for decoding the embedded claims inside
/// `SubmissionStatusResponse`. Lives in a file compiled into ALL targets
/// (main app + widget/Live Activity extensions).
/// The main-app-only `SharedReelManager` converts these to `ClaimEntry`.
struct StatusClaimEntry: Codable {
    let claim: String
    let verdict: String
    let claimAccuracyRating: String
    let explanation: String
    let summary: String
    let sources: [String]
    let category: String?

    enum CodingKeys: String, CodingKey {
        case claim, verdict, explanation, summary, sources, category
        case claimAccuracyRating
        case claimAccuracyRatingSnake = "claim_accuracy_rating"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        claim   = try c.decode(String.self, forKey: .claim)
        verdict = try c.decode(String.self, forKey: .verdict)
        claimAccuracyRating =
            (try? c.decodeIfPresent(String.self, forKey: .claimAccuracyRating)) ??
            (try? c.decodeIfPresent(String.self, forKey: .claimAccuracyRatingSnake)) ??
            "50%"
        explanation = (try? c.decodeIfPresent(String.self, forKey: .explanation)) ?? ""
        summary     = (try? c.decodeIfPresent(String.self, forKey: .summary))     ?? ""
        sources     = (try? c.decodeIfPresent([String].self, forKey: .sources))   ?? []
        category    = try? c.decodeIfPresent(String.self, forKey: .category)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(claim,               forKey: .claim)
        try c.encode(verdict,             forKey: .verdict)
        try c.encode(claimAccuracyRating, forKey: .claimAccuracyRating)
        try c.encode(explanation,         forKey: .explanation)
        try c.encode(summary,             forKey: .summary)
        try c.encode(sources,             forKey: .sources)
        try c.encodeIfPresent(category,   forKey: .category)
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

    var isTerminal: Bool { self == .completed || self == .failed }

    // MARK: - Pipeline stages

    /// Labels for the three pipeline stages shown under the segmented stage bar
    /// (island, lock screen, in-app banner, My Reels card).
    static let pipelineStages: [String] = ["Fetch", "Analyze", "Verify"]

    /// Slice of overall progress (0…1) that each stage spans. Matches the
    /// backend's checkpoints (analyzing = 30 %, fact-checking = 80 % / 92 %).
    static let stageProgressRanges: [ClosedRange<Double>] = [0.0...0.30, 0.30...0.80, 0.80...1.0]

    /// Index into `pipelineStages` for this status; `pipelineStages.count` once terminal.
    var stageIndex: Int {
        switch self {
        case .submitting, .downloading:  return 0
        case .processing, .analyzing:    return 1
        case .factChecking:              return 2
        case .completed, .failed:        return ProcessingStatus.pipelineStages.count
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

// MARK: - Verdict Styling (shared by app + widget)

/// Maps a backend verdict string ("True", "False", "Misleading", …) to a colour
/// and icon. Lives here so the widget extension and the main app agree.
enum VerdictStyle {
    /// Placeholder strings that older code paths stuffed into the verdict slot.
    /// These must never be rendered as a verdict chip.
    private static let placeholders: Set<String> = [
        "", "tap to view results", "see results", "view results", "fact-check complete"
    ]

    static func isPlaceholder(_ verdict: String?) -> Bool {
        placeholders.contains((verdict ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }

    static func color(for verdict: String?) -> Color {
        let v = (verdict ?? "").lowercased()
        if v.contains("false") || v.contains("incorrect") || v.contains("fake") { return .brandRed }
        if v.contains("misleading") || v.contains("mixed") || v.contains("context") || v.contains("partial") { return .brandYellow }
        if v.contains("true") || v.contains("correct") || v.contains("accurate") { return .brandGreen }
        return .brandTeal
    }

    static func icon(for verdict: String?) -> String {
        let v = (verdict ?? "").lowercased()
        if v.contains("false") || v.contains("incorrect") || v.contains("fake") { return "xmark.circle.fill" }
        if v.contains("misleading") || v.contains("mixed") || v.contains("context") || v.contains("partial") { return "exclamationmark.triangle.fill" }
        if v.contains("true") || v.contains("correct") || v.contains("accurate") { return "checkmark.circle.fill" }
        return "questionmark.circle.fill"
    }
}

// MARK: - Segmented Stage Bar (shared by island, lock screen, and in-app views)

/// Wallet-style progress: one rounded segment per pipeline stage, filled in
/// order, with plain labels underneath. Static per content update (the island
/// re-renders on each push); motion comes from the countdown text next to it.
struct SegmentedStageBar: View {
    let status: ProcessingStatus
    let progress: Double
    let tint: Color
    var track: Color = Color.primary.opacity(0.12)
    var height: CGFloat = 5
    var showLabels: Bool = true
    var labelColor: Color = .secondary
    var activeLabelColor: Color = .primary
    var labelSize: CGFloat = 10

    private func fill(_ idx: Int) -> Double {
        if status == .completed { return 1 }
        let range = ProcessingStatus.stageProgressRanges[idx]
        let span = max(range.upperBound - range.lowerBound, 0.001)
        let fraction = min(max((progress - range.lowerBound) / span, 0), 1)
        // The stage we're in always reads as "underway": never empty, never full.
        if idx == status.stageIndex && !status.isTerminal {
            return min(max(fraction, 0.14), 0.9)
        }
        return fraction
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 3) {
                ForEach(0..<ProcessingStatus.pipelineStages.count, id: \.self) { idx in
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(track)
                            Capsule().fill(tint)
                                .frame(width: max(geo.size.width * fill(idx), fill(idx) > 0 ? height : 0))
                        }
                    }
                    .frame(height: height)
                }
            }
            .animation(.easeOut(duration: 0.5), value: progress)
            .animation(.easeOut(duration: 0.3), value: status)

            if showLabels {
                HStack(spacing: 3) {
                    ForEach(Array(ProcessingStatus.pipelineStages.enumerated()), id: \.offset) { idx, name in
                        let isActive = idx == status.stageIndex && !status.isTerminal
                        let isDone = status == .completed || idx < status.stageIndex
                        Text(name)
                            .font(.system(size: labelSize, weight: isActive ? .semibold : .regular))
                            .foregroundColor(isActive ? activeLabelColor : (isDone ? labelColor : labelColor.opacity(0.6)))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
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
        /// Absolute time the current stage is expected to finish. Drives the live,
        /// self-updating countdown in the island via `Text(timerInterval:)` — no
        /// pushes required for the number to tick. Optional so activities and push
        /// payloads created before this field existed still decode.
        var etaDate: Date? = nil
    }

    // Static attributes that don't change during the activity
    let reelURL: String
    let submissionId: String
    let startTime: Date
    var isPro: Bool = false  // Gold styling for pro users

    // Custom Codable conformance so existing Live Activities that were serialized
    // without the `isPro` key can still be decoded (defaults to false).
    enum CodingKeys: String, CodingKey {
        case reelURL, submissionId, startTime, isPro
    }

    init(reelURL: String, submissionId: String, startTime: Date, isPro: Bool = false) {
        self.reelURL = reelURL
        self.submissionId = submissionId
        self.startTime = startTime
        self.isPro = isPro
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        reelURL = try container.decode(String.self, forKey: .reelURL)
        submissionId = try container.decode(String.self, forKey: .submissionId)
        startTime = try container.decode(Date.self, forKey: .startTime)
        isPro = try container.decodeIfPresent(Bool.self, forKey: .isPro) ?? false
    }

    /// Source platform derived from the reel URL, for display in the island.
    var platformName: String {
        let u = reelURL.lowercased()
        if u.contains("tiktok")                                  { return "TikTok" }
        if u.contains("youtu")                                   { return "YouTube" }
        if u.contains("threads.")                                { return "Threads" }
        if u.contains("twitter.com") || u.contains("//x.com") || u.contains("www.x.com") { return "X" }
        if u.contains("instagram")                               { return "Instagram" }
        return "Link"
    }
}

// MARK: - Completion Source

/// Where a completion / failure signal originated. Used to decide whether the
/// app should present a local alert (island expansion + sound) or whether the
/// user has already been notified through another channel.
enum ActivityCompletionSource: String {
    /// The in-app progress-polling loop saw the terminal state.
    case polling
    /// Foreground reconciliation against the backend.
    case reconcile
    /// The Share Extension wrote a completed record into the App Group.
    case appGroupSync
    /// A regular APNs push (`action: fact_check_completed`). iOS has already
    /// shown a system banner for it, so the app must never alert again.
    case remotePush
    /// Legacy synchronous fact-check response inside the app.
    case inApp
    /// The app gave up waiting (polling / max-age timeout). The backend never
    /// sends anything for this, so the app must alert locally even when the
    /// backend holds the activity token.
    case localTimeout
}

// MARK: - Activity Manager

@available(iOS 16.1, *)
@MainActor
class ReelProcessingActivityManager: ObservableObject {
    static let shared = ReelProcessingActivityManager()

    private static let appGroupName = "group.rob"

    var currentActivities: [String: Activity<ReelProcessingActivityAttributes>] = [:]
    /// Maximum age (seconds) for a non-terminal Live Activity before it is force-failed.
    /// Acts as a hard safety net so no Dynamic Island activity lives forever.
    private let maxActivityAge: TimeInterval = 300 // 5 minutes
    /// Holds completion info for activities that couldn't be shown because the app was in the
    /// background when polling finished. Drained by `drainPendingCompletedActivities()` on foreground.
    private var pendingCompletedInfo: [String: (title: String, verdict: String?, url: String)] = [:]
    /// Holds error messages for submissions that failed (limit_reached, timeout, etc.) while the
    /// app was in the background and no Live Activity existed. Drained by
    /// `drainPendingFailedActivities()` on foreground so the user sees an error island.
    private var pendingFailedInfo: [String: String] = [:]

    // ── Notification dedup ──────────────────────────────────────────────────
    //
    // A single fact-check can reach its terminal state through many channels
    // at nearly the same moment: the polling loop, the foreground reconcile,
    // the Share-Extension App Group sync, the backend's APNs Live Activity
    // push, and the backend's regular-notification fallback. Every one of them
    // funnels through `completeActivity` / `failActivity`, and the rules are:
    //
    //   1. A submission is alerted AT MOST once, from ANY source.
    //   2. If the backend has confirmed it holds this activity's push token,
    //      the backend owns the alert (its APNs update carries it) and the
    //      app only refreshes content silently.
    //   3. If a system notification for the submission is already sitting in
    //      Notification Center, the user has been told — stay silent.
    //
    // Both sets are persisted in the App Group so an app relaunch between the
    // backend push and the next poll can't re-alert, and so the Share
    // Extension (which registers tokens itself) shares the same truth.

    /// Submission IDs the user has already been alerted about, from any source.
    private var notifiedSubmissionIds: Set<String> = []
    private static let notifiedKey = "la_notified_submission_ids"
    /// Submission IDs whose per-activity APNs token the backend has confirmed
    /// (HTTP 2xx from /register-activity-token).
    private var registeredActivityTokenIds: Set<String> = []
    private static let registeredTokenKey = "la_registered_activity_token_ids"
    /// Upper bound on the persisted ID lists so they never grow unbounded.
    private static let persistedIdCap = 50

    /// Activity IDs for which a `pushTokenUpdates` observer Task is already running.
    /// Prevents leaking a fresh observer every time an activity is re-discovered.
    private var observedActivityIds: Set<String> = []
    /// Submissions whose tokenless island has already been replaced once. See `startActivity`.
    private var upgradedSubmissionIds: Set<String> = []
    /// How old a token-less island must be before we assume it was created with
    /// `pushType: nil` rather than simply still waiting for its first APNs token.
    static let tokenlessUpgradeMinAge: TimeInterval = 20
    /// Last token string forwarded to the backend per submission — the sync
    /// `pushToken` fast path and the async `pushTokenUpdates` stream both emit
    /// the initial token, so this avoids sending it twice.
    private var lastForwardedToken: [String: String] = [:]

    /// Injected by the main app target on startup. Called with each (token, submissionId) pair
    /// whenever a Live Activity's APNs push token is issued or rotated. Returns `true` when
    /// the backend acknowledged the token (2xx).
    /// Extensions leave this nil — they handle token forwarding via App Group storage instead.
    var onActivityPushToken: ((String, String) async -> Bool)?

    /// Injected by the main app on startup. Returns whether the app is currently in the
    /// background. Extensions leave this as the default `{ false }` — they are always
    /// active when running, and `UIApplication.shared` is unavailable in extension targets.
    var isAppInBackground: () -> Bool = { false }

    /// Injected by the main app on startup. Returns the reel URL for a given submission ID
    /// by looking it up in SharedReelManager.reels. Extensions leave this as the default
    /// `{ _ in "" }` because SharedReelManager is not compiled into extension targets.
    var reelURLForSubmissionId: (String) -> String = { _ in "" }

    /// Injected by the main app. Called when the app discovers Live Activities are
    /// unavailable on this device so the backend can drop its stale push-to-start
    /// token. Without this the backend keeps "successfully" pushing to an island that
    /// never renders and its regular-notification fallback never fires.
    var onLiveActivitiesUnavailable: (() async -> Void)?

    init() {
        // Note: Removed automatic cleanup on init to prevent ending active Live Activities
        // Cleanup is now only called explicitly when needed (e.g., on app becoming active after long period)
        notifiedSubmissionIds = Set(Self.loadPersistedIds(key: Self.notifiedKey))
        registeredActivityTokenIds = Set(Self.loadPersistedIds(key: Self.registeredTokenKey))
        print("✅ [ActivityManager] Initialized (cleanup deferred) notified=\(notifiedSubmissionIds.count) registeredTokens=\(registeredActivityTokenIds.count)")
    }

    // MARK: - Persisted ID sets

    private static func loadPersistedIds(key: String) -> [String] {
        UserDefaults(suiteName: appGroupName)?.stringArray(forKey: key) ?? []
    }

    private static func appendPersistedId(_ id: String, key: String) {
        guard let defaults = UserDefaults(suiteName: appGroupName) else { return }
        var ids = defaults.stringArray(forKey: key) ?? []
        guard !ids.contains(id) else { return }
        ids.append(id)
        if ids.count > persistedIdCap { ids.removeFirst(ids.count - persistedIdCap) }
        defaults.set(ids, forKey: key)
    }

    // MARK: - Notification dedup API

    /// True when the user has already been alerted about this submission.
    func hasNotified(_ submissionId: String) -> Bool {
        notifiedSubmissionIds.contains(submissionId)
    }

    /// Records that the user has been alerted for this submission. Returns `true`
    /// only for the first caller — i.e. the caller that should actually alert.
    @discardableResult
    func claimNotification(_ submissionId: String) -> Bool {
        guard !notifiedSubmissionIds.contains(submissionId) else { return false }
        notifiedSubmissionIds.insert(submissionId)
        Self.appendPersistedId(submissionId, key: Self.notifiedKey)
        return true
    }

    /// Whether the backend has confirmed it holds this activity's push token and
    /// will therefore deliver the completion / failure alert itself.
    func isActivityTokenRegistered(_ submissionId: String) -> Bool {
        if registeredActivityTokenIds.contains(submissionId) { return true }
        // The Share Extension may have registered it in its own process.
        if Self.loadPersistedIds(key: Self.registeredTokenKey).contains(submissionId) {
            registeredActivityTokenIds.insert(submissionId)
            return true
        }
        return false
    }

    /// Marks a submission's activity token as acknowledged by the backend. Static so
    /// the Share Extension can call it from its own registration path.
    static func markActivityTokenRegistered(_ submissionId: String) {
        appendPersistedId(submissionId, key: registeredTokenKey)
    }

    /// True when a system notification for this submission is already in
    /// Notification Center — e.g. the backend's regular-push fallback landed while
    /// the app was force-quit, so no code path in the app ever saw it arrive.
    static func hasDeliveredNotification(for submissionId: String) async -> Bool {
        let delivered = await UNUserNotificationCenter.current().deliveredNotifications()
        return delivered.contains { note in
            let info = note.request.content.userInfo
            if (info["submission_id"] as? String) == submissionId { return true }
            return note.request.identifier == "factcheck-completed-\(submissionId)"
        }
    }

    // MARK: - Duplicate activity collapse

    /// An island that is still on screen and can still be updated. `.stale` just
    /// means its staleDate passed (typical after the app was suspended for a
    /// minute) — it is still visible and must be driven, not replaced.
    static func isLive(_ activity: Activity<ReelProcessingActivityAttributes>) -> Bool {
        switch activity.activityState {
        case .active, .stale: return true
        default:              return false
        }
    }

    /// iOS creates a *separate* activity for every push-to-start it receives, so one
    /// submission can end up with two islands (one started locally by the app or
    /// Share Extension, one by the backend's push-to-start). Keeps the best one and
    /// ends the rest immediately.
    ///
    /// Preference: terminal (completed/failed) > has push token > most recently started.
    @discardableResult
    func dedupeActivities(for submissionId: String) async -> Activity<ReelProcessingActivityAttributes>? {
        let matches = Activity<ReelProcessingActivityAttributes>.activities.filter {
            $0.attributes.submissionId == submissionId && Self.isLive($0)
        }
        guard let keeper = matches.max(by: { Self.rank($0) < Self.rank($1) }) else {
            // Nothing live — drop any stale tracked reference so callers fall
            // through to their "no activity" handling.
            if let tracked = currentActivities[submissionId],
               tracked.activityState == .ended || tracked.activityState == .dismissed {
                currentActivities.removeValue(forKey: submissionId)
            }
            return nil
        }
        for extra in matches where extra.id != keeper.id {
            print("🧹 [ActivityManager] Ending duplicate island \(extra.id.prefix(6)) for \(submissionId.prefix(8)) (keeping \(keeper.id.prefix(6)))")
            await extra.end(ActivityContent(state: extra.content.state, staleDate: nil), dismissalPolicy: .immediate)
        }
        if currentActivities[submissionId]?.id != keeper.id {
            currentActivities[submissionId] = keeper
            // A keeper we've never tracked (e.g. created by push-to-start) needs its
            // token forwarded so the backend can drive it.
            observePushToken(for: keeper, submissionId: submissionId)
            flushAppGroupPushToken(submissionId: submissionId)
        }
        return keeper
    }

    private static func rank(_ a: Activity<ReelProcessingActivityAttributes>) -> (Int, Int, TimeInterval) {
        let terminal = a.content.state.status.isTerminal ? 1 : 0
        let hasToken = a.pushToken != nil ? 1 : 0
        return (terminal, hasToken, a.attributes.startTime.timeIntervalSince1970)
    }

    /// Runs `dedupeActivities` for every submission that currently has an island.
    func dedupeAllActivities() async {
        let ids = Set(Activity<ReelProcessingActivityAttributes>.activities.map { $0.attributes.submissionId })
        for id in ids { await dedupeActivities(for: id) }
    }

    // MARK: - Live Activity availability

    /// Call on foreground. If Live Activities are unavailable (iPad without support,
    /// disabled in Settings, etc.) drop the cached push-to-start token so neither the
    /// Share Extension nor the backend keeps targeting an island that can't render.
    func syncLiveActivityAvailability() async {
        guard !ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard let defaults = UserDefaults(suiteName: Self.appGroupName),
              defaults.string(forKey: "live_activity_push_to_start_token") != nil else { return }
        print("🚫 [ActivityManager] Live Activities unavailable — clearing push-to-start token")
        defaults.removeObject(forKey: "live_activity_push_to_start_token")
        await onLiveActivitiesUnavailable?()
    }

    // MARK: - Cleanup Stale Activities

    func cleanupStaleActivities() async {
        print("🧹 [ActivityManager] Cleaning up stale Live Activities...")

        let allActivities = Activity<ReelProcessingActivityAttributes>.activities
        print("   Found \(allActivities.count) existing system activities")

        if allActivities.isEmpty {
            print("✅ [ActivityManager] Cleanup complete. Active: 0")
            return
        }

        let now = Date()
        let staleThreshold: TimeInterval = 300 // 5 minutes (matches maxActivityAge)
        var endedCount = 0

        for activity in allActivities {
            let submissionId = activity.attributes.submissionId
            let age = now.timeIntervalSince(activity.attributes.startTime)

            if age > staleThreshold {
                print("   ❌ \(submissionId.prefix(8)) STALE (\(Int(age))s) - ending...")
                await activity.end(ActivityContent(state: activity.content.state, staleDate: nil), dismissalPolicy: .immediate)
                endedCount += 1
            } else {
                currentActivities[submissionId] = activity
            }
        }

        print("✅ [ActivityManager] Cleanup complete. Ended \(endedCount)/\(allActivities.count) stale activities. Kept: \(currentActivities.count)")
    }

    // MARK: - Start Activity

    func startActivity(submissionId: String, reelURL: String, thumbnailURL: String? = nil, inheritedState: ReelProcessingActivityAttributes.ContentState? = nil) async {
        print("🚀 [ActivityManager] startActivity called for: \(submissionId.prefix(8))…")

        // Collapse any duplicate islands for this submission and pick up whatever
        // survives (skips .ended activities so a recursive upgrade call doesn't
        // re-enter this branch).
        if let existing = await dedupeActivities(for: submissionId) {
            print("⚠️ [ActivityManager] System Live Activity already exists for \(submissionId.prefix(8)) state=\(existing.activityState)")

            // If the Share Extension created this activity with pushType: nil (because it
            // lacked aps-environment entitlement), it has no push token and the backend
            // cannot send Dynamic Island updates. Upgrade it now that the main app is in
            // the foreground by ending the tokenless activity and starting a fresh one.
            //
            // ActivityKit exposes no `pushType` on an Activity, and a freshly created
            // token-backed island also has `pushToken == nil` until APNs issues one
            // (typically a few seconds). Guard on age and do it at most once per
            // submission so the 1 s pending-check timer can't end/recreate the island
            // in a loop while waiting for the first token.
            let age = Date().timeIntervalSince(existing.attributes.startTime)
            let looksTokenless = existing.pushToken == nil && age > Self.tokenlessUpgradeMinAge
            if looksTokenless && !isAppInBackground() && inheritedState == nil && !upgradedSubmissionIds.contains(submissionId) {
                upgradedSubmissionIds.insert(submissionId)
                print("🔄 [ActivityManager] Upgrading pushType:nil activity to pushType:.token for \(submissionId.prefix(8))… (age \(Int(age))s)")
                let existingState = existing.content.state
                await existing.end(
                    ActivityContent(state: existingState, staleDate: nil),
                    dismissalPolicy: .immediate
                )
                currentActivities.removeValue(forKey: submissionId)
                await startActivity(submissionId: submissionId, reelURL: reelURL, thumbnailURL: thumbnailURL, inheritedState: existingState)
                return
            } else {
                currentActivities[submissionId] = existing
                observePushToken(for: existing, submissionId: submissionId)
                flushAppGroupPushToken(submissionId: submissionId)
                return
            }
        }

        // ActivityKit Error 7: creating a NEW Live Activity requires the app to be in the foreground.
        guard !isAppInBackground() else {
            print("⚠️ [ActivityManager] App in background — cannot create new Live Activity (ActivityKit Error 7). Will start when foregrounded.")
            return
        }

        let authInfo = ActivityAuthorizationInfo()
        guard authInfo.areActivitiesEnabled else {
            print("⚠️ [ActivityManager] Live Activities are NOT enabled")
            // Fallback: a local "started" notification so iPad / disabled devices still get feedback.
            Self.scheduleLocalNotification(
                id: "factcheck-started-\(submissionId)",
                title: "Fact-check started",
                body: "We're analysing your content. You'll be notified when it's ready.",
                categoryId: "REEL_PROCESSING",
                userInfo: ["submission_id": submissionId]
            )
            return
        }

        // Check if we're at the limit (8 activities max)
        let existingCount = Activity<ReelProcessingActivityAttributes>.activities.count
        if existingCount >= 8 {
            print("⚠️ [ActivityManager] At activity limit (\(existingCount)/8), cleaning up old activities...")
            await cleanupStaleActivities()
        }

        let attributes = ReelProcessingActivityAttributes(
            reelURL: reelURL,
            submissionId: submissionId,
            startTime: Date(),
            isPro: UserDefaults(suiteName: Self.appGroupName)?.bool(forKey: "is_pro_user") ?? false
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
            estimatedSecondsRemaining: 90,
            etaDate: Date().addingTimeInterval(90)
        )

        do {
            let staleDate = Date().addingTimeInterval(maxActivityAge)
            let activity = try Activity<ReelProcessingActivityAttributes>.request(
                attributes: attributes,
                content: ActivityContent(state: initialState, staleDate: staleDate),
                pushType: .token
            )

            currentActivities[submissionId] = activity
            print("✅ [ActivityManager] ✨ Live Activity started! id=\(activity.id) sid=\(submissionId.prefix(8))")
            observePushToken(for: activity, submissionId: submissionId)

        } catch {
            print("❌ [ActivityManager] Failed to start Live Activity: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("   Domain: \(nsError.domain), Code: \(nsError.code)")
            }
        }
    }

    // MARK: - Push Token Observation

    /// Forwards a token to the backend (via the injected hook) unless this exact token
    /// was already sent for this submission. Records backend acknowledgement.
    private func forwardToken(_ tokenString: String, submissionId: String) async {
        guard lastForwardedToken[submissionId] != tokenString else { return }
        lastForwardedToken[submissionId] = tokenString
        if let sharedDefaults = UserDefaults(suiteName: Self.appGroupName) {
            sharedDefaults.set(tokenString, forKey: "activity_push_token_\(submissionId)")
        }
        guard let hook = onActivityPushToken else { return }
        let acknowledged = await hook(tokenString, submissionId)
        if acknowledged {
            registeredActivityTokenIds.insert(submissionId)
            Self.markActivityTokenRegistered(submissionId)
        } else {
            // Allow a retry with the same token on the next trigger.
            if lastForwardedToken[submissionId] == tokenString { lastForwardedToken.removeValue(forKey: submissionId) }
        }
    }

    /// Observes push token updates for an activity and forwards each token via `onActivityPushToken`.
    /// Safe to call repeatedly — only one observer Task is ever created per activity.
    func observePushToken(for activity: Activity<ReelProcessingActivityAttributes>, submissionId: String) {
        // Fast path: forward any already-available token before the async stream emits.
        if let pushToken = activity.pushToken {
            let tokenString = pushToken.map { String(format: "%02x", $0) }.joined()
            Task { await forwardToken(tokenString, submissionId: submissionId) }
        }
        guard !observedActivityIds.contains(activity.id) else { return }
        observedActivityIds.insert(activity.id)
        Task {
            for await pushToken in activity.pushTokenUpdates {
                let tokenString = pushToken.map { String(format: "%02x", $0) }.joined()
                print("🔑 [ActivityManager] Activity push token for \(submissionId.prefix(8)): \(tokenString.prefix(12))…")
                await forwardToken(tokenString, submissionId: submissionId)
            }
            observedActivityIds.remove(activity.id)
        }
    }

    /// Checks if the Live Activity for the given submission now has an APNs push token
    /// and, if so, forwards it to the backend. Returns `true` when a token exists.
    @available(iOS 16.1, *)
    func tryRegisterActivityPushToken(submissionId: String) async -> Bool {
        guard let activity = resolvedActivity(for: submissionId) else { return false }
        guard let pushToken = activity.pushToken else { return false }
        let tokenString = pushToken.map { String(format: "%02x", $0) }.joined()
        await forwardToken(tokenString, submissionId: submissionId)
        return true
    }

    // MARK: - App Group Token Flush

    /// Reads the activity push token that the Share Extension stored in App Group and
    /// forwards it via `onActivityPushToken` (deduplicated — a token already sent is skipped).
    func flushAppGroupPushToken(submissionId: String) {
        guard let sharedDefaults = UserDefaults(suiteName: Self.appGroupName),
              let storedToken = sharedDefaults.string(forKey: "activity_push_token_\(submissionId)") else {
            return
        }
        Task { await forwardToken(storedToken, submissionId: submissionId) }
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
    private func resolvedActivity(for submissionId: String) -> Activity<ReelProcessingActivityAttributes>? {
        if let tracked = currentActivities[submissionId], Self.isLive(tracked) { return tracked }
        if let system = Activity<ReelProcessingActivityAttributes>.activities.first(where: {
            $0.attributes.submissionId == submissionId && Self.isLive($0)
        }) {
            currentActivities[submissionId] = system
            observePushToken(for: system, submissionId: submissionId)
            flushAppGroupPushToken(submissionId: submissionId)
            return system
        }
        return nil
    }

    func updateActivity(submissionId: String, status: ProcessingStatus, customMessage: String? = nil) async {
        guard let activity = await dedupeActivities(for: submissionId) else {
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
            estimatedSecondsRemaining: activity.content.state.estimatedSecondsRemaining,
            etaDate: activity.content.state.etaDate
        )

        await updateActivityState(activity: activity, newState: newState)
    }

    func updateProgress(submissionId: String, status: ProcessingStatus? = nil, progress: Double, message: String, estimatedSecondsRemaining: Int? = nil) async {
        if await dedupeActivities(for: submissionId) == nil, !isAppInBackground() {
            // App was foregrounded mid-poll before the activity could be created —
            // start it now so subsequent updates are visible.
            let url = reelURLForSubmissionId(submissionId)
            if !url.isEmpty {
                print("🟢 [ActivityManager] updateProgress: lazy-starting activity for \(submissionId.prefix(8)) (now in foreground)")
                await startActivity(submissionId: submissionId, reelURL: url)
            }
        }
        guard let activity = await dedupeActivities(for: submissionId) else {
            print("⚠️ [ActivityManager] updateProgress: no activity found for \(submissionId.prefix(8)) — skipping")
            return
        }

        // Never regress a terminal island back to "in progress" because a late
        // poll result arrived after completion.
        guard !activity.content.state.status.isTerminal else { return }

        // Hard timeout: if the activity has been alive longer than maxActivityAge,
        // force-fail it instead of updating. Prevents stuck Dynamic Island.
        let age = Date().timeIntervalSince(activity.attributes.startTime)
        if age > maxActivityAge {
            print("⏱️ [ActivityManager] Activity for \(submissionId.prefix(8)) exceeded max age (\(Int(age))s) — force-failing")
            await failActivity(submissionId: submissionId, errorMessage: "Processing timeout", source: .localTimeout)
            return
        }

        let resolvedStatus = status ?? activity.content.state.status
        let clamped = min(max(progress, 0.0), 1.0)
        // Only ever move forward — a lower percentage from a racing poll would make
        // the bar jump backwards.
        let monotonic = max(clamped, activity.content.state.progress)
        let eta: Date? = estimatedSecondsRemaining.map { Date().addingTimeInterval(TimeInterval(max($0, 0))) }

        let newState = ReelProcessingActivityAttributes.ContentState(
            status: resolvedStatus,
            progress: monotonic,
            statusMessage: message,
            title: activity.content.state.title,
            verdict: activity.content.state.verdict,
            thumbnailURL: activity.content.state.thumbnailURL,
            estimatedSecondsRemaining: estimatedSecondsRemaining,
            etaDate: eta ?? activity.content.state.etaDate
        )

        // Skip no-op updates — each `update` re-renders the island and counts
        // toward the system's update budget.
        guard newState != activity.content.state else { return }

        print("🎨 [ActivityManager] Updating activity: status=\(resolvedStatus.rawValue) progress=\(Int(monotonic*100))% msg=\(message)")
        await updateActivityState(activity: activity, newState: newState)
    }

    private func updateActivityState(activity: Activity<ReelProcessingActivityAttributes>, newState: ReelProcessingActivityAttributes.ContentState) async {
        // Roll the staleDate forward on each update so iOS knows the activity is still active,
        // but always cap it so the activity cannot live beyond maxActivityAge from its start.
        let absoluteDeadline = activity.attributes.startTime.addingTimeInterval(maxActivityAge)
        let rollingStale = Date().addingTimeInterval(60) // 1 minute from now
        let staleDate = min(rollingStale, absoluteDeadline)
        await activity.update(ActivityContent(state: newState, staleDate: staleDate))
    }

    // MARK: - Complete Activity

    /// Drives the island for `submissionId` to its completed state.
    ///
    /// - Parameters:
    ///   - verdict: The primary claim's verdict ("True", "False", …). Pass `nil` when
    ///     unknown — never a placeholder string; the UI hides the chip for nil.
    ///   - source: Which channel observed the completion. Governs alert dedup — see
    ///     the notes on `notifiedSubmissionIds`.
    func completeActivity(submissionId: String, title: String, verdict: String?, source: ActivityCompletionSource) async {
        let cleanVerdict = VerdictStyle.isPlaceholder(verdict) ? nil : verdict
        let activity = await dedupeActivities(for: submissionId)

        // The "Fact-check started" local notification (no-Live-Activity devices) is
        // obsolete the moment the result exists — clear it whichever channel got here.
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["factcheck-started-\(submissionId)"])
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["factcheck-started-\(submissionId)"])

        // ── Who alerts? ─────────────────────────────────────────────────────
        // A regular APNs push has already produced a system banner — record that
        // and never alert again for this submission.
        if source == .remotePush { claimNotification(submissionId) }
        var alreadyNotified = hasNotified(submissionId)
        if !alreadyNotified, await Self.hasDeliveredNotification(for: submissionId) {
            print("ℹ️ [ActivityManager] completeActivity: system notification already delivered for \(submissionId.prefix(8)) — staying silent")
            claimNotification(submissionId)
            alreadyNotified = true
        }
        let backendOwnsAlert = isActivityTokenRegistered(submissionId)

        guard let activity else {
            // No island exists (e.g. share-ext submission while the app was in the
            // background, or Live Activities are unavailable on this device).
            let url = reelURLForSubmissionId(submissionId)
            if ActivityAuthorizationInfo().areActivitiesEnabled {
                if !isAppInBackground() {
                    print("🟢 [ActivityManager] completeActivity: app in foreground, starting completed island for \(submissionId.prefix(8))")
                    await startActivityInCompletedState(submissionId: submissionId, url: url, title: title, verdict: cleanVerdict)
                } else {
                    pendingCompletedInfo[submissionId] = (title: title, verdict: cleanVerdict, url: url)
                    print("📥 [ActivityManager] completeActivity: queued pending completion for \(submissionId.prefix(8)) (app in background)")
                }
            } else if !alreadyNotified && !backendOwnsAlert {
                // Devices without Live Activities (iPad, disabled in Settings, iOS < 16.1):
                // a local notification is the only way to tell the user.
                if claimNotification(submissionId) {
                    Self.scheduleCompletionLocalNotification(submissionId: submissionId, title: title, verdict: cleanVerdict)
                }
            }
            return
        }

        let completedState = ReelProcessingActivityAttributes.ContentState(
            status: .completed,
            progress: 1.0,
            statusMessage: "Tap to view results",
            title: title,
            verdict: cleanVerdict ?? (VerdictStyle.isPlaceholder(activity.content.state.verdict) ? nil : activity.content.state.verdict),
            thumbnailURL: activity.content.state.thumbnailURL,
            estimatedSecondsRemaining: 0,
            etaDate: nil
        )
        let content = ActivityContent(state: completedState, staleDate: Date().addingTimeInterval(300))

        let islandAlreadyCompleted = activity.content.state.status == .completed
        if alreadyNotified || backendOwnsAlert || islandAlreadyCompleted {
            if backendOwnsAlert && !alreadyNotified {
                // The backend's APNs completion push carries the alert. Record it so a
                // later path (e.g. a foreground reconcile) doesn't add a second one.
                claimNotification(submissionId)
            }
            let reason = alreadyNotified ? "already notified" : (backendOwnsAlert ? "backend owns alert" : "island already completed")
            print("ℹ️ [ActivityManager] completeActivity: silent content refresh for \(submissionId.prefix(8)) (\(reason))")
            // Skip the update entirely if nothing changed — avoids a redundant re-render.
            if activity.content.state != completedState {
                await activity.update(content)
            }
            return
        }

        // First (and only) alert for this submission.
        guard claimNotification(submissionId) else {
            await activity.update(content)
            return
        }
        let body = cleanVerdict.map { "\(title) — \($0)" } ?? title
        let alertConfig = AlertConfiguration(
            title: "Fact-check complete!",
            body: LocalizedStringResource(stringLiteral: body),
            sound: .default
        )
        await activity.update(content, alertConfiguration: alertConfig)
        HapticManager.successImpact()
        print("🔔 [ActivityManager] completeActivity: alerted for \(submissionId.prefix(8)) via \(source.rawValue)")
    }

    // MARK: - Drain Pending Completions

    /// Creates a brief failed Live Activity for every submission that errored (limit_reached etc.)
    /// while the app was in the background and no activity existed.
    /// Call this from the foreground `scenePhase == .active` handler.
    @available(iOS 16.1, *)
    func drainPendingFailedActivities() async {
        guard !isAppInBackground(), !pendingFailedInfo.isEmpty else { return }
        let pending = pendingFailedInfo
        pendingFailedInfo = [:]
        print("🔄 [ActivityManager] Draining \(pending.count) pending failed activity(ies)")
        for (submissionId, errorMessage) in pending {
            let url = reelURLForSubmissionId(submissionId)
            await startActivityInFailedState(submissionId: submissionId, url: url, errorMessage: errorMessage)
        }
    }

    /// Creates a brief failed Live Activity for a submission that errored out.
    @available(iOS 16.1, *)
    private func startActivityInFailedState(submissionId: String, url: String, errorMessage: String) async {
        guard !isAppInBackground() else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        if await dedupeActivities(for: submissionId) != nil {
            // An island appeared in the meantime — fail that one instead of adding another.
            await failActivity(submissionId: submissionId, errorMessage: errorMessage, source: .reconcile)
            return
        }
        let friendlyMessage = Self.friendlyErrorMessage(errorMessage)
        let attributes = ReelProcessingActivityAttributes(
            reelURL: url, submissionId: submissionId, startTime: Date(),
            isPro: UserDefaults(suiteName: Self.appGroupName)?.bool(forKey: "is_pro_user") ?? false
        )
        let failedState = ReelProcessingActivityAttributes.ContentState(
            status: .failed,
            progress: 0,
            statusMessage: friendlyMessage,
            title: nil, verdict: nil,
            thumbnailURL: nil, estimatedSecondsRemaining: 0, etaDate: nil
        )
        do {
            let activity = try Activity<ReelProcessingActivityAttributes>.request(
                attributes: attributes,
                content: ActivityContent(state: failedState, staleDate: Date().addingTimeInterval(30)),
                pushType: .token
            )
            currentActivities[submissionId] = activity
            if claimNotification(submissionId) { HapticManager.errorImpact() }
            print("✅ [ActivityManager] Started failed Live Activity for \(submissionId.prefix(8)): \(friendlyMessage)")
            // Auto-dismiss after 8 seconds
            Task {
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                await endActivity(submissionId: submissionId, dismissalPolicy: .immediate)
            }
        } catch {
            print("⚠️ [ActivityManager] Failed to start error activity for \(submissionId.prefix(8)): \(error.localizedDescription)")
        }
    }

    /// Creates a completed Live Activity for every submission that finished while the app
    /// was in the background (and therefore could not create an activity at that time).
    /// Call this from the foreground `scenePhase == .active` handler.
    @available(iOS 16.1, *)
    func drainPendingCompletedActivities() async {
        guard !isAppInBackground(), !pendingCompletedInfo.isEmpty else { return }
        let pending = pendingCompletedInfo
        pendingCompletedInfo = [:]
        print("🔄 [ActivityManager] Draining \(pending.count) pending completed activity(ies)")
        for (submissionId, info) in pending {
            await startActivityInCompletedState(
                submissionId: submissionId, url: info.url,
                title: info.title, verdict: info.verdict
            )
        }
    }

    /// Starts a brand-new Live Activity directly in the completed "Tap to view" state.
    @available(iOS 16.1, *)
    private func startActivityInCompletedState(
        submissionId: String, url: String, title: String, verdict: String?
    ) async {
        guard !isAppInBackground() else { return }

        // If an island for this submission is still alive (e.g. the backend's
        // push-to-start-completed fallback created one), reuse it.
        if let existing = await dedupeActivities(for: submissionId) {
            print("♻️ [ActivityManager] startActivityInCompletedState: existing island found for \(submissionId.prefix(8)) — reusing")
            if existing.content.state.status != .completed {
                await completeActivity(submissionId: submissionId, title: title, verdict: verdict, source: .reconcile)
            } else {
                claimNotification(submissionId)
            }
            return
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = ReelProcessingActivityAttributes(
            reelURL: url, submissionId: submissionId, startTime: Date(),
            isPro: UserDefaults(suiteName: Self.appGroupName)?.bool(forKey: "is_pro_user") ?? false
        )
        let completedState = ReelProcessingActivityAttributes.ContentState(
            status: .completed, progress: 1.0,
            statusMessage: "Tap to view results",
            title: title, verdict: verdict,
            thumbnailURL: nil, estimatedSecondsRemaining: 0, etaDate: nil
        )
        do {
            let activity = try Activity<ReelProcessingActivityAttributes>.request(
                attributes: attributes,
                content: ActivityContent(state: completedState, staleDate: Date().addingTimeInterval(300)),
                pushType: .token
            )
            currentActivities[submissionId] = activity
            // Do NOT observe the push token here. This activity is created directly in
            // the completed state — there are no future backend updates to deliver, and
            // registering the token would make /register-activity-token re-push the
            // completion.
            if claimNotification(submissionId) {
                HapticManager.successImpact()
            }
            print("✅ [ActivityManager] Started completed Live Activity for \(submissionId.prefix(8)) (drained from pending)")
        } catch {
            print("⚠️ [ActivityManager] Failed to start completed activity for \(submissionId.prefix(8)): \(error.localizedDescription)")
        }
    }

    // MARK: - Cleanup

    /// Removes `currentActivities` entries that no longer have a matching live system activity.
    @available(iOS 16.1, *)
    func cleanupStaleTrackedActivities() {
        let systemIds = Set(Activity<ReelProcessingActivityAttributes>.activities.map { $0.attributes.submissionId })
        let stale = currentActivities.keys.filter { !systemIds.contains($0) }
        for sid in stale {
            currentActivities.removeValue(forKey: sid)
        }
        if !stale.isEmpty {
            print("🧹 [ActivityManager] Cleared \(stale.count) stale currentActivities entries")
        }
    }

    // MARK: - End Activity

    func endActivity(submissionId: String, dismissalPolicy: ActivityUIDismissalPolicy = .default) async {
        // End EVERY island for this submission, not just the tracked one.
        let matches = Activity<ReelProcessingActivityAttributes>.activities.filter {
            $0.attributes.submissionId == submissionId
        }
        guard !matches.isEmpty else {
            currentActivities.removeValue(forKey: submissionId)
            print("⚠️ [ActivityManager] endActivity: no activity found for \(submissionId.prefix(8))")
            return
        }
        for activity in matches {
            let finalContent = ActivityContent(state: activity.content.state, staleDate: nil)
            await activity.end(finalContent, dismissalPolicy: dismissalPolicy)
        }
        currentActivities.removeValue(forKey: submissionId)
        print("✅ Live Activity ended for submission \(submissionId.prefix(8)) (\(matches.count) island(s))")
        // Remove this submission from the App Group pending_submissions so that
        // checkAndStartPendingLiveActivities can never re-create a ghost activity for it.
        Self.removeFromAppGroupPendingSubmissions(submissionId: submissionId)
    }

    func failActivity(submissionId: String, errorMessage: String, source: ActivityCompletionSource = .polling) async {
        if source == .remotePush { claimNotification(submissionId) }

        guard let activity = await dedupeActivities(for: submissionId) else {
            // No existing island — queue it so drainPendingFailedActivities() can create one
            // on foreground and the user still sees the error.
            if pendingFailedInfo[submissionId] == nil {
                pendingFailedInfo[submissionId] = errorMessage
                print("📥 [ActivityManager] failActivity: no activity found for \(submissionId.prefix(8)) — queued for foreground display")
            }
            return
        }

        let friendlyMessage = Self.friendlyErrorMessage(errorMessage)
        let failedState = ReelProcessingActivityAttributes.ContentState(
            status: .failed,
            progress: activity.content.state.progress, // keep last known progress
            statusMessage: friendlyMessage,
            title: nil,
            verdict: nil,
            thumbnailURL: activity.content.state.thumbnailURL,
            estimatedSecondsRemaining: 0,
            etaDate: nil
        )
        let content = ActivityContent(state: failedState, staleDate: Date().addingTimeInterval(30))

        // Same single-alert rule as completion: the backend alerts when it holds the
        // token; otherwise the first local observer alerts, everyone else is silent.
        // A local timeout is the exception — the backend isn't sending anything.
        let backendOwnsAlert = source != .localTimeout && isActivityTokenRegistered(submissionId)
        let alreadyFailed = activity.content.state.status == .failed
        if alreadyFailed || backendOwnsAlert || !claimNotification(submissionId) {
            if backendOwnsAlert { claimNotification(submissionId) }
            if activity.content.state != failedState { await activity.update(content) }
        } else {
            let alertConfig = AlertConfiguration(
                title: "Fact-check failed",
                body: LocalizedStringResource(stringLiteral: friendlyMessage),
                sound: .default
            )
            await activity.update(content, alertConfiguration: alertConfig)
            HapticManager.errorImpact()
        }

        // Show the error for 8 seconds, then dismiss
        Task {
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            await endActivity(submissionId: submissionId, dismissalPolicy: .immediate)
        }
    }

    /// Converts raw backend/network error strings into short, user-readable messages.
    /// The backend's friendly_error_for_live_activity() already maps most exceptions
    /// before they arrive here, so this function acts as a final safety net for any
    /// message that might slip through — especially from local network failures.
    static func friendlyErrorMessage(_ raw: String) -> String {
        let lower = raw.lowercased()

        // Pipe-separated backend errors ("error_type|||user message") — take the user half
        if raw.contains("|||") {
            let userPart = raw.components(separatedBy: "|||").last?.trimmingCharacters(in: .whitespaces) ?? ""
            if !userPart.isEmpty { return friendlyErrorMessage(userPart) }
        }

        // AI service overload / 503
        if lower.contains("503") || lower.contains("overloaded") || lower.contains("high demand")
            || (lower.contains("unavailable") && lower.contains("model")) {
            return "AI service is busy — please try again"
        }

        // Quota / rate limiting
        if lower.contains("quota") || lower.contains("rate limit") || lower.contains("429")
            || lower.contains("too many requests") || lower.contains("resource exhausted") {
            return "Too many requests — please try again soon"
        }

        // Usage limits (already user-facing)
        if lower.contains("limit reached") {
            return raw
        }

        // Network / connectivity
        if lower.contains("timeout") || lower.contains("timed out") {
            return "Took too long — please try again"
        }
        if lower.contains("network") || lower.contains("internet") || lower.contains("offline")
            || lower.contains("connection") {
            return "No internet connection"
        }

        // Video availability
        if lower.contains("not found") || lower.contains("404") {
            return "Video not found or unavailable"
        }
        if lower.contains("age") || lower.contains("sign in") {
            return "Video is age-restricted"
        }
        if lower.contains("private") || lower.contains("unauthori") || lower.contains("forbidden")
            || lower.contains("geo") || lower.contains("region") {
            return "Video is private or restricted"
        }
        if lower.contains("unsupported") || lower.contains("platform") {
            return "Unsupported video format"
        }

        // Download / audio processing
        if lower.contains("download") || lower.contains("yt-dlp") || lower.contains("ytdlp") {
            return "Could not download video — please try again"
        }
        if lower.contains("transcri") || lower.contains("audio") || lower.contains("speech") {
            return "Could not process audio — please try again"
        }

        // Generic backend failure labels — replace with cleaner copy
        if lower.contains("processing") || lower.contains("failed") || lower.contains("error") {
            return "Something went wrong — please try again"
        }

        // If the message is already short and looks human-readable, use it directly
        if raw.count <= 60 && !raw.contains("{") && !raw.contains("http") && !raw.contains("stack") {
            return raw
        }

        // Final fallback — never show raw technical output
        return "Something went wrong — please try again"
    }

    // MARK: - App Group Cleanup

    /// Removes a submission from the App Group `pending_submissions` list so that
    /// `checkAndStartPendingLiveActivities` cannot resurrect a ghost activity for it.
    static func removeFromAppGroupPendingSubmissions(submissionId: String) {
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

    // MARK: - End All

    func endAllActivities() async {
        print("🧹 [ActivityManager] Ending all active Live Activities...")
        for activity in Activity<ReelProcessingActivityAttributes>.activities {
            await activity.end(ActivityContent(state: activity.content.state, staleDate: nil), dismissalPolicy: .immediate)
        }
        currentActivities.removeAll()
        print("✅ [ActivityManager] All activities ended")
    }

    // MARK: - Local Notification Fallbacks

    /// Schedule a local notification (works in all targets including extensions).
    static func scheduleLocalNotification(id: String, title: String, body: String, categoryId: String, userInfo: [String: String]) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = categoryId
        content.userInfo = userInfo

        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ [ActivityManager] Failed to schedule local notification: \(error)")
            } else {
                print("✅ [ActivityManager] Scheduled local notification: \(title)")
            }
        }
    }

    /// Schedule a completion local notification, removing any prior "started" notification.
    static func scheduleCompletionLocalNotification(submissionId: String, title: String, verdict: String?) {
        let center = UNUserNotificationCenter.current()
        center.removeDeliveredNotifications(withIdentifiers: ["factcheck-started-\(submissionId)"])
        center.removePendingNotificationRequests(withIdentifiers: ["factcheck-started-\(submissionId)"])

        let cleanVerdict = VerdictStyle.isPlaceholder(verdict) ? nil : verdict
        var userInfo: [String: String] = [
            "submission_id": submissionId,
            "action": "fact_check_completed",
            "title": title
        ]
        if let cleanVerdict { userInfo["verdict"] = cleanVerdict }
        scheduleLocalNotification(
            id: "factcheck-completed-\(submissionId)",
            title: "Fact-check complete!",
            body: cleanVerdict.map { "\(title) — \($0)" } ?? title,
            categoryId: "FACT_CHECK_COMPLETED",
            userInfo: userInfo
        )
    }
}
