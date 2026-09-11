//
//  ReelProcessingLiveActivity.swift
//  informed
//
//  Dynamic Island and Live Activity UI for reel processing
//
//  Rendering notes — this file runs inside the WidgetKit extension:
//    • Views are re-rendered only when the activity's content state changes.
//      `@State`, `onAppear` and `withAnimation(.repeatForever)` never fire, so
//      any "live" motion has to come from system-driven primitives:
//        – `Text(timerInterval:)` ticks every second on its own
//        – `.animation(_, value:)` / `.contentTransition` animate between
//          consecutive content states
//    • Remote images can't be loaded (no network in the extension).
//

import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Widget Entry Point

@available(iOS 16.1, *)
struct ReelProcessingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReelProcessingActivityAttributes.self) { context in
            LockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedLeadingView(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTrailingView(context: context)
                }
                DynamicIslandExpandedRegion(.center) {
                    ExpandedCenterView(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomView(context: context)
                }
            } compactLeading: {
                CompactLeadingView(context: context)
            } compactTrailing: {
                CompactTrailingView(context: context)
            } minimal: {
                MinimalView(context: context)
            }
            .keylineTint(LAPalette.tint(for: context))
            .widgetURL(URL(string: "factcheckapp://detail?id=\(context.attributes.submissionId)"))
        }
    }
}

// MARK: - Shared palette helpers

@available(iOS 16.1, *)
enum LAPalette {
    static let goldDark = Color(red: 0.72, green: 0.53, blue: 0.10)

    /// Primary accent for the current state. Pro users get gold while processing;
    /// terminal states always use their semantic colour so results read instantly.
    static func tint(for context: ActivityViewContext<ReelProcessingActivityAttributes>) -> Color {
        let status = context.state.status
        if status == .completed { return context.attributes.isPro ? .brandGold : .brandGreen }
        if status == .failed    { return .brandRed }
        return context.attributes.isPro ? .brandGold : status.color
    }

    static func gradient(for context: ActivityViewContext<ReelProcessingActivityAttributes>) -> LinearGradient {
        let colors: [Color]
        if context.attributes.isPro && !context.state.status.isTerminal {
            colors = [.brandGold, goldDark]
        } else {
            colors = [context.state.status.color, context.state.status.secondaryColor]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// The verdict to show, or nil when we only have a placeholder.
    static func verdict(for context: ActivityViewContext<ReelProcessingActivityAttributes>) -> String? {
        let v = context.state.verdict
        return VerdictStyle.isPlaceholder(v) ? nil : v
    }

    /// A countdown end date that is safe to feed `Text(timerInterval:)` — in the
    /// future, but not absurdly so (guards against a mis-decoded timestamp).
    static func countdownEnd(for context: ActivityViewContext<ReelProcessingActivityAttributes>) -> Date? {
        guard !context.state.status.isTerminal, let eta = context.state.etaDate else { return nil }
        let now = Date()
        guard eta > now.addingTimeInterval(1), eta < now.addingTimeInterval(15 * 60) else { return nil }
        return eta
    }
}

// MARK: - Lock Screen / Banner View

@available(iOS 16.1, *)
struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<ReelProcessingActivityAttributes>

    private var status: ProcessingStatus { context.state.status }
    private var tint: Color { LAPalette.tint(for: context) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 13) {
                // Gradient icon badge
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(LAPalette.gradient(for: context))
                        .frame(width: 46, height: 46)
                    Image(systemName: status.icon)
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundColor(.white)
                        .contentTransition(.symbolEffect(.replace))
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: status)

                // Text stack
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Text(context.attributes.isPro ? "+informed" : "informed")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(context.attributes.isPro ? .brandGold : .secondary)
                        if context.attributes.isPro {
                            Image(systemName: "star.fill")
                                .font(.system(size: 7))
                                .foregroundColor(.brandGold)
                        }
                        Text("·")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text(context.attributes.platformName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    if status == .completed, let title = context.state.title, !title.isEmpty {
                        Text(title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                    } else {
                        Text(status == .failed ? "Fact-check failed" : status.shortLabel)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(status == .failed ? .brandRed : .primary)
                            .lineLimit(1)
                        Text(context.state.statusMessage)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                // Right element
                if status == .completed {
                    if let verdict = LAPalette.verdict(for: context) {
                        LAVerdictChip(verdict: verdict, isPro: context.attributes.isPro)
                    } else {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 26))
                            .foregroundColor(tint)
                    }
                } else if status == .failed {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(.brandRed)
                } else {
                    LACircularRing(progress: context.state.progress, color: tint, textColor: .primary)
                        .frame(width: 42, height: 42)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, status.isTerminal ? 14 : 10)

            // Stepper + progress bar + countdown — only while processing
            if !status.isTerminal {
                VStack(spacing: 8) {
                    LAStageStepper(status: status, tint: tint)
                    LAProgressBar(progress: context.state.progress, gradient: LAPalette.gradient(for: context), track: Color.primary.opacity(0.1))
                        .frame(height: 4)
                    HStack {
                        Text("\(Int(context.state.progress * 100))%")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(tint)
                            .contentTransition(.numericText())
                        Spacer()
                        LACountdownLabel(context: context, color: .secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            } else if status == .completed {
                HStack(spacing: 5) {
                    Image(systemName: "hand.tap.fill")
                    Text("Tap to view results")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .activityBackgroundTint(Color.cardBackground)
        .activitySystemActionForegroundColor(tint)
        .widgetURL(URL(string: "factcheckapp://detail?id=\(context.attributes.submissionId)"))
    }
}

// MARK: - Compact Views

@available(iOS 16.1, *)
struct CompactLeadingView: View {
    let context: ActivityViewContext<ReelProcessingActivityAttributes>
    var body: some View {
        // Brand glyph — a stable identity mark, tinted by stage. Keeping the leading
        // slot constant (rather than a per-stage icon) stops the island from looking
        // like a slot machine as stages tick by; the trailing slot carries the data.
        Image(systemName: context.state.status == .failed ? "exclamationmark.shield.fill" : "checkmark.shield.fill")
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(LAPalette.tint(for: context))
            .padding(.leading, 3)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: context.state.status)
    }
}

@available(iOS 16.1, *)
struct CompactTrailingView: View {
    let context: ActivityViewContext<ReelProcessingActivityAttributes>
    var body: some View {
        Group {
            switch context.state.status {
            case .completed:
                Image(systemName: context.attributes.isPro ? "star.fill" : "checkmark.seal.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(LAPalette.tint(for: context))
                    .padding(.trailing, 3)
            case .failed:
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.brandRed)
                    .padding(.trailing, 3)
            default:
                Text("\(Int(context.state.progress * 100))%")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(LAPalette.tint(for: context))
                    .contentTransition(.numericText())
                    .padding(.trailing, 3)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: context.state.status)
        .animation(.easeOut(duration: 0.4), value: context.state.progress)
    }
}

// MARK: - Minimal View

@available(iOS 16.1, *)
struct MinimalView: View {
    let context: ActivityViewContext<ReelProcessingActivityAttributes>
    var body: some View {
        switch context.state.status {
        case .completed:
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(LAPalette.tint(for: context))
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.brandRed)
        default:
            ZStack {
                Circle().stroke(Color.white.opacity(0.22), lineWidth: 2)
                Circle()
                    .trim(from: 0, to: max(context.state.progress, 0.04))
                    .stroke(LAPalette.tint(for: context), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: context.state.progress)
            }
            .frame(width: 13, height: 13)
        }
    }
}

// MARK: - Expanded Views

@available(iOS 16.1, *)
struct ExpandedLeadingView: View {
    let context: ActivityViewContext<ReelProcessingActivityAttributes>

    var body: some View {
        ZStack {
            Circle()
                .fill(LAPalette.tint(for: context).opacity(0.14))
                .frame(width: 46, height: 46)
            Circle()
                .fill(LAPalette.gradient(for: context))
                .frame(width: 34, height: 34)
            Image(systemName: context.state.status.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .contentTransition(.symbolEffect(.replace))
                .scaleEffect(context.state.status == .completed ? 1.12 : 1.0)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: context.state.status)
    }
}

@available(iOS 16.1, *)
struct ExpandedTrailingView: View {
    let context: ActivityViewContext<ReelProcessingActivityAttributes>
    var body: some View {
        switch context.state.status {
        case .completed:
            let verdict = LAPalette.verdict(for: context)
            let color = context.attributes.isPro ? Color.brandGold : (verdict.map { VerdictStyle.color(for: $0) } ?? .brandGreen)
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [color, color.opacity(0.7)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 38, height: 38)
                Image(systemName: context.attributes.isPro ? "star.fill" : (verdict.map { VerdictStyle.icon(for: $0) } ?? "checkmark"))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.5), value: context.state.status)
        case .failed:
            ZStack {
                Circle()
                    .fill(Color.brandRed.opacity(0.18))
                    .frame(width: 38, height: 38)
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.brandRed)
            }
        default:
            LACircularRing(progress: context.state.progress, color: LAPalette.tint(for: context), textColor: .white)
                .frame(width: 40, height: 40)
        }
    }
}

@available(iOS 16.1, *)
struct ExpandedCenterView: View {
    let context: ActivityViewContext<ReelProcessingActivityAttributes>
    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Text(context.attributes.isPro ? "+informed" : "informed")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.6)
                if context.attributes.isPro {
                    Image(systemName: "star.fill")
                        .font(.system(size: 6))
                        .foregroundColor(.brandGold)
                }
                Text("· \(context.attributes.platformName)")
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundColor(context.attributes.isPro ? Color.brandGold.opacity(0.85) : Color.white.opacity(0.55))
            .lineLimit(1)

            Text(context.state.status == .failed ? "Failed" : context.state.status.shortLabel)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(LAPalette.tint(for: context))
                .lineLimit(1)
                .contentTransition(.opacity)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: context.state.status)
        }
    }
}

@available(iOS 16.1, *)
struct ExpandedBottomView: View {
    let context: ActivityViewContext<ReelProcessingActivityAttributes>

    private var status: ProcessingStatus { context.state.status }
    private var tint: Color { LAPalette.tint(for: context) }

    var body: some View {
        VStack(spacing: 8) {
            if !status.isTerminal {
                LAStageStepper(status: status, tint: tint)
                    .padding(.top, 2)

                LAProgressBar(progress: context.state.progress, gradient: LAPalette.gradient(for: context), track: Color.white.opacity(0.12))
                    .frame(height: 6)

                HStack(alignment: .center, spacing: 8) {
                    Text(context.state.statusMessage)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.65))
                        .lineLimit(1)
                        .contentTransition(.opacity)
                    Spacer(minLength: 4)
                    LACountdownLabel(context: context, color: .white.opacity(0.8))
                }
                .padding(.horizontal, 2)
            }

            // Completed
            if status == .completed {
                VStack(spacing: 6) {
                    if let title = context.state.title, !title.isEmpty {
                        Text(title)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                    }
                    if let verdict = LAPalette.verdict(for: context) {
                        LAVerdictChip(verdict: verdict, isPro: context.attributes.isPro)
                    }
                    Label("Tap to view results", systemImage: "hand.tap.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.top, 1)
                }
            }

            // Failed
            if status == .failed {
                VStack(spacing: 6) {
                    Label("Fact-check failed", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.brandRed)
                    Text(context.state.statusMessage)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 6)
                }
                .padding(.vertical, 2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }
}

// MARK: - Supporting Views

/// Four-step pipeline indicator: Fetch → Analyze → Verify → Done.
/// Each column owns half of the connector on either side so the segments meet
/// exactly at column boundaries and the dots stay centred over their labels.
@available(iOS 16.1, *)
struct LAStageStepper: View {
    let status: ProcessingStatus
    let tint: Color

    private var current: Int { status.stageIndex }
    private var stages: [String] { ProcessingStatus.pipelineStages }
    private var dim: Color { Color.primary.opacity(0.14) }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(stages.enumerated()), id: \.offset) { idx, name in
                let isDone   = idx < current || status == .completed
                let isActive = idx == current && !status.isTerminal
                let isLast   = idx == stages.count - 1
                VStack(spacing: 4) {
                    ZStack {
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(idx == 0 ? Color.clear : (idx <= current ? tint : dim))
                                .frame(height: 1.5)
                            Rectangle()
                                .fill(isLast ? Color.clear : (idx < current ? tint : dim))
                                .frame(height: 1.5)
                        }
                        ZStack {
                            Circle()
                                .fill(isDone ? tint : (isActive ? tint.opacity(0.22) : dim))
                                .frame(width: 9, height: 9)
                            if isActive {
                                Circle()
                                    .stroke(tint, lineWidth: 1.5)
                                    .frame(width: 9, height: 9)
                            }
                            if isDone {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 5, weight: .black))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .frame(height: 10)
                    Text(name)
                        .font(.system(size: 8.5, weight: (isDone || isActive) ? .semibold : .medium))
                        .foregroundColor(isActive ? tint : (isDone ? .primary : .secondary))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: status)
    }
}

/// Gradient progress bar that animates between content states.
@available(iOS 16.1, *)
struct LAProgressBar: View {
    let progress: Double
    let gradient: LinearGradient
    let track: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule()
                    .fill(gradient)
                    .frame(width: max(geo.size.width * min(max(progress, 0), 1), 6))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
            }
        }
    }
}

/// Live countdown to the current stage's ETA. `Text(timerInterval:)` ticks on its
/// own inside the Live Activity, so the number stays fresh between pushes. Falls
/// back to the static estimate when no usable ETA date is available.
@available(iOS 16.1, *)
struct LACountdownLabel: View {
    let context: ActivityViewContext<ReelProcessingActivityAttributes>
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.system(size: 10, weight: .semibold))
            if let end = LAPalette.countdownEnd(for: context) {
                Text(timerInterval: Date()...end, countsDown: true, showsHours: false)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 44, alignment: .trailing)
                Text("left")
                    .font(.system(size: 11, weight: .medium))
            } else if let est = context.state.estimatedSecondsRemaining, est > 0 {
                Text(est > 60 ? "~\(est / 60)m left" : "~\(est)s left")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .monospacedDigit()
            } else {
                Text("Almost done")
                    .font(.system(size: 11, weight: .medium))
            }
        }
        .foregroundColor(color)
        .lineLimit(1)
    }
}

/// Verdict pill coloured by outcome (green / red / amber; gold for Pro).
@available(iOS 16.1, *)
struct LAVerdictChip: View {
    let verdict: String
    let isPro: Bool

    var body: some View {
        let color = isPro ? Color.brandGold : VerdictStyle.color(for: verdict)
        HStack(spacing: 4) {
            Image(systemName: VerdictStyle.icon(for: verdict))
                .font(.system(size: 10, weight: .bold))
            Text(verdict)
                .font(.system(size: 12, weight: .bold))
                .lineLimit(1)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color)
        .clipShape(Capsule())
    }
}

@available(iOS 16.1, *)
struct LACircularRing: View {
    let progress: Double
    let color: Color
    var textColor: Color = .white
    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.18), lineWidth: 3)
            Circle()
                .trim(from: 0, to: max(min(progress, 1), 0.02))
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
            Text("\(Int(progress * 100))%")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(textColor)
                .contentTransition(.numericText())
        }
    }
}

// MARK: - Preview

@available(iOS 16.1, *)
struct ReelProcessingLiveActivity_Previews: PreviewProvider {
    static var previews: some View {
        Text("Use Widget Preview to see Live Activity")
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
