//
//  ReelProcessingLiveActivity.swift
//  informed
//
//  Dynamic Island and Live Activity UI for reel processing.
//
//  Design notes
//    • One accent colour per activity (brand blue; gold for Pro). Completed is
//      green, failed is red. No per-stage colour changes, no gradients.
//    • Flat tinted icon, system typography, and a Wallet-style segmented stage
//      bar with plain labels — the same component the in-app banner uses.
//    • Live motion comes from `Text(timerInterval:)` only. `@State`, `onAppear`
//      and repeating animations never run inside a Live Activity, so nothing
//      here relies on them.
//    • Remote images can't be loaded in the widget process, so no thumbnails.
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
            .keylineTint(LAStyle.tint(for: context))
            .widgetURL(URL(string: "factcheckapp://detail?id=\(context.attributes.submissionId)"))
        }
    }
}

// MARK: - Style helpers

@available(iOS 16.1, *)
enum LAStyle {
    /// The single accent for this activity.
    static func tint(for context: ActivityViewContext<ReelProcessingActivityAttributes>) -> Color {
        switch context.state.status {
        case .completed: return .brandGreen
        case .failed:    return .brandRed
        default:         return context.attributes.isPro ? .brandGold : .brandBlue
        }
    }

    /// Headline for the current state.
    static func headline(for context: ActivityViewContext<ReelProcessingActivityAttributes>) -> String {
        switch context.state.status {
        case .completed: return "Fact-check complete"
        case .failed:    return "Fact-check failed"
        default:         return "Fact-checking"
        }
    }

    /// "Instagram Reel", "TikTok video", …
    static func sourceLabel(for context: ActivityViewContext<ReelProcessingActivityAttributes>) -> String {
        switch context.attributes.platformName {
        case "Instagram": return "Instagram Reel"
        case "TikTok":    return "TikTok video"
        case "YouTube":   return "YouTube Short"
        case "X":         return "Post on X"
        case "Threads":   return "Threads post"
        default:          return "Shared link"
        }
    }

    static func verdict(for context: ActivityViewContext<ReelProcessingActivityAttributes>) -> String? {
        let v = context.state.verdict
        return VerdictStyle.isPlaceholder(v) ? nil : v
    }

    /// Countdown end date safe for `Text(timerInterval:)` — in the future, not absurdly so.
    static func countdownEnd(for context: ActivityViewContext<ReelProcessingActivityAttributes>) -> Date? {
        guard !context.state.status.isTerminal, let eta = context.state.etaDate else { return nil }
        let now = Date()
        guard eta > now.addingTimeInterval(1), eta < now.addingTimeInterval(15 * 60) else { return nil }
        return eta
    }
}

/// Flat, tinted rounded-square icon (no gradients).
@available(iOS 16.1, *)
struct LAIcon: View {
    let symbol: String
    let tint: Color
    var size: CGFloat = 36
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(tint.opacity(0.18))
            Image(systemName: symbol)
                .font(.system(size: size * 0.5, weight: .semibold))
                .foregroundColor(tint)
                .contentTransition(.symbolEffect(.replace))
        }
        .frame(width: size, height: size)
    }
}

/// Live countdown ("0:42") with a fixed width so the digits don't jitter.
@available(iOS 16.1, *)
struct LACountdown: View {
    let context: ActivityViewContext<ReelProcessingActivityAttributes>
    var size: CGFloat = 15
    var weight: Font.Weight = .semibold
    var color: Color = .primary

    var body: some View {
        Group {
            if let end = LAStyle.countdownEnd(for: context) {
                Text(timerInterval: Date()...end, countsDown: true, showsHours: false)
                    .font(.system(size: size, weight: weight, design: .rounded))
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .frame(width: size * 2.7, alignment: .trailing)
            } else if let est = context.state.estimatedSecondsRemaining, est > 0 {
                Text(est > 60 ? "~\(Int((Double(est) / 60).rounded(.up))) min" : "~\(est)s")
                    .font(.system(size: size, weight: weight, design: .rounded))
                    .monospacedDigit()
            } else {
                Text("Finishing")
                    .font(.system(size: size - 2, weight: .medium))
            }
        }
        .foregroundColor(color)
        .lineLimit(1)
    }
}

/// Soft tinted verdict chip: coloured text on a light tint, not white on a solid.
@available(iOS 16.1, *)
struct LAVerdictChip: View {
    let verdict: String
    var body: some View {
        let color = VerdictStyle.color(for: verdict)
        HStack(spacing: 4) {
            Image(systemName: VerdictStyle.icon(for: verdict))
                .font(.system(size: 11, weight: .semibold))
            Text(verdict)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundColor(color)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(color.opacity(0.16))
        .clipShape(Capsule())
    }
}

// MARK: - Lock Screen / Banner

@available(iOS 16.1, *)
struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<ReelProcessingActivityAttributes>

    private var status: ProcessingStatus { context.state.status }
    private var tint: Color { LAStyle.tint(for: context) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                LAIcon(symbol: status == .failed ? "exclamationmark.shield.fill" : "checkmark.shield.fill",
                       tint: tint, size: 40)

                VStack(alignment: .leading, spacing: 2) {
                    if status == .completed, let title = context.state.title, !title.isEmpty {
                        Text(title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                        Text("Tap to view results")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    } else {
                        Text(status.isTerminal ? LAStyle.headline(for: context)
                                               : "\(LAStyle.headline(for: context)) \(LAStyle.sourceLabel(for: context))")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Text(context.state.statusMessage)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                if status == .completed {
                    if let verdict = LAStyle.verdict(for: context) {
                        LAVerdictChip(verdict: verdict)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(tint)
                    }
                } else if status == .failed {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(tint)
                } else {
                    LACountdown(context: context, size: 17, weight: .semibold, color: .primary)
                }
            }

            if !status.isTerminal {
                SegmentedStageBar(status: status, progress: context.state.progress, tint: tint,
                                  track: Color.primary.opacity(0.12), height: 5,
                                  labelColor: .secondary, activeLabelColor: .primary, labelSize: 11)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .activitySystemActionForegroundColor(tint)
        .widgetURL(URL(string: "factcheckapp://detail?id=\(context.attributes.submissionId)"))
    }
}

// MARK: - Compact

@available(iOS 16.1, *)
struct CompactLeadingView: View {
    let context: ActivityViewContext<ReelProcessingActivityAttributes>
    var body: some View {
        Image(systemName: context.state.status == .failed ? "exclamationmark.shield.fill" : "checkmark.shield.fill")
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(LAStyle.tint(for: context))
            .padding(.leading, 2)
    }
}

@available(iOS 16.1, *)
struct CompactTrailingView: View {
    let context: ActivityViewContext<ReelProcessingActivityAttributes>
    var body: some View {
        switch context.state.status {
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(LAStyle.tint(for: context))
                .padding(.trailing, 2)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(LAStyle.tint(for: context))
                .padding(.trailing, 2)
        default:
            if LAStyle.countdownEnd(for: context) != nil {
                LACountdown(context: context, size: 13, weight: .semibold, color: LAStyle.tint(for: context))
                    .padding(.trailing, 2)
            } else {
                Text("\(Int(context.state.progress * 100))%")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(LAStyle.tint(for: context))
                    .contentTransition(.numericText())
                    .padding(.trailing, 2)
            }
        }
    }
}

// MARK: - Minimal

@available(iOS 16.1, *)
struct MinimalView: View {
    let context: ActivityViewContext<ReelProcessingActivityAttributes>
    var body: some View {
        switch context.state.status {
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(LAStyle.tint(for: context))
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(LAStyle.tint(for: context))
        default:
            ZStack {
                Circle().stroke(LAStyle.tint(for: context).opacity(0.25), lineWidth: 2)
                Circle()
                    .trim(from: 0, to: max(context.state.progress, 0.05))
                    .stroke(LAStyle.tint(for: context), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.5), value: context.state.progress)
            }
            .frame(width: 14, height: 14)
        }
    }
}

// MARK: - Expanded

@available(iOS 16.1, *)
struct ExpandedLeadingView: View {
    let context: ActivityViewContext<ReelProcessingActivityAttributes>
    var body: some View {
        LAIcon(symbol: context.state.status == .failed ? "exclamationmark.shield.fill" : "checkmark.shield.fill",
               tint: LAStyle.tint(for: context), size: 36)
            .padding(.leading, 2)
    }
}

@available(iOS 16.1, *)
struct ExpandedCenterView: View {
    let context: ActivityViewContext<ReelProcessingActivityAttributes>
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(LAStyle.headline(for: context))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
            Text(context.state.status.isTerminal ? "Tap to view" : LAStyle.sourceLabel(for: context))
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

@available(iOS 16.1, *)
struct ExpandedTrailingView: View {
    let context: ActivityViewContext<ReelProcessingActivityAttributes>
    var body: some View {
        switch context.state.status {
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(LAStyle.tint(for: context))
                .padding(.trailing, 2)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(LAStyle.tint(for: context))
                .padding(.trailing, 2)
        default:
            LACountdown(context: context, size: 17, weight: .semibold, color: .white)
                .padding(.trailing, 2)
        }
    }
}

@available(iOS 16.1, *)
struct ExpandedBottomView: View {
    let context: ActivityViewContext<ReelProcessingActivityAttributes>

    private var status: ProcessingStatus { context.state.status }
    private var tint: Color { LAStyle.tint(for: context) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch status {
            case .completed:
                VStack(alignment: .leading, spacing: 6) {
                    if let title = context.state.title, !title.isEmpty {
                        Text(title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(2)
                    }
                    if let verdict = LAStyle.verdict(for: context) {
                        LAVerdictChip(verdict: verdict)
                    }
                }
            case .failed:
                Text(context.state.statusMessage)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.75))
                    .lineLimit(2)
            default:
                SegmentedStageBar(status: status, progress: context.state.progress, tint: tint,
                                  track: Color.white.opacity(0.14), height: 5,
                                  labelColor: .white.opacity(0.55), activeLabelColor: .white, labelSize: 11)
                Text(context.state.statusMessage)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
        .padding(.bottom, 2)
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
