//
//  ReelProcessingLiveActivity.swift
//  informed
//
//  Dynamic Island and Live Activity UI for reel processing
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
            .keylineTint(context.state.status.color)
            .widgetURL(URL(string: "factcheckapp://detail?id=\(context.attributes.submissionId)"))
        }
    }
}

// MARK: - Lock Screen / Banner View

@available(iOS 16.1, *)
struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<ReelProcessingActivityAttributes>

    private var isCompleted: Bool { context.state.status == .completed }
    private var isFailed:    Bool { context.state.status == .failed }
    private var isTerminal:  Bool { isCompleted || isFailed }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 13) {
                // Gradient icon badge
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(LinearGradient(
                            colors: [context.state.status.color,
                                     context.state.status.secondaryColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 46, height: 46)
                    Image(systemName: context.state.status.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: context.state.status)

                // Text stack
                VStack(alignment: .leading, spacing: 2) {
                    Text("informed · fact-check")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)

                    if isCompleted, let title = context.state.title {
                        Text(title)
                            .font(.system(size: 15, weight: .bold))
                            .lineLimit(1)
                    } else {
                        Text(context.state.statusMessage)
                            .font(.system(size: 15, weight: .semibold))
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Right element
                if isCompleted {
                    if let verdict = context.state.verdict {
                        Text(verdict)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 6)
                            .background(context.state.status.color)
                            .clipShape(Capsule())
                    }
                } else if isFailed {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(.brandRed)
                } else {
                    LACircularRing(progress: context.state.progress,
                                   color: context.state.status.color)
                        .frame(width: 40, height: 40)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            // Progress bar — only while processing
            if !isTerminal {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.gray.opacity(0.15))
                        Capsule()
                            .fill(LinearGradient(
                                colors: [context.state.status.color,
                                         context.state.status.secondaryColor],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .frame(width: geo.size.width * context.state.progress)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8),
                                       value: context.state.progress)
                    }
                }
                .frame(height: 3)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .activityBackgroundTint(Color.cardBackground)
        .activitySystemActionForegroundColor(context.state.status.color)
        .widgetURL(URL(string: "factcheckapp://detail?id=\(context.attributes.submissionId)"))
    }
}

// MARK: - Compact Views

@available(iOS 16.1, *)
struct CompactLeadingView: View {
    let context: ActivityViewContext<ReelProcessingActivityAttributes>
    var body: some View {
        Image(systemName: context.state.status.icon)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(context.state.status.color)
            .padding(.leading, 2)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: context.state.status)
    }
}

@available(iOS 16.1, *)
struct CompactTrailingView: View {
    let context: ActivityViewContext<ReelProcessingActivityAttributes>
    var body: some View {
        Group {
            if context.state.status == .completed {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.brandGreen)
                    .padding(.trailing, 2)
            } else if context.state.status == .failed {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.brandRed)
                    .padding(.trailing, 2)
            } else {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.22), lineWidth: 1.5)
                    Circle()
                        .trim(from: 0, to: context.state.progress)
                        .stroke(context.state.status.color, lineWidth: 1.5)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.5, dampingFraction: 0.8),
                                   value: context.state.progress)
                }
                .frame(width: 11, height: 11)
                .padding(.leading, 2)
                .padding(.trailing, 3)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: context.state.status)
    }
}

// MARK: - Minimal View

@available(iOS 16.1, *)
struct MinimalView: View {
    let context: ActivityViewContext<ReelProcessingActivityAttributes>
    var body: some View {
        if context.state.status == .completed {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.brandGreen)
        } else if context.state.status == .failed {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.brandRed)
        } else {
            ZStack {
                Circle().stroke(Color.white.opacity(0.22), lineWidth: 1.2)
                Circle()
                    .trim(from: 0, to: context.state.progress)
                    .stroke(context.state.status.color, lineWidth: 1.2)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8),
                               value: context.state.progress)
            }
            .frame(width: 10, height: 10)
        }
    }
}

// MARK: - Expanded Views

@available(iOS 16.1, *)
struct ExpandedLeadingView: View {
    let context: ActivityViewContext<ReelProcessingActivityAttributes>
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            // Outer glow ring
            Circle()
                .fill(context.state.status.color.opacity(isPulsing ? 0.18 : 0.08))
                .frame(width: 46, height: 46)
                .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                           value: isPulsing)
            // Gradient inner circle
            Circle()
                .fill(LinearGradient(
                    colors: [context.state.status.color,
                             context.state.status.secondaryColor],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 34, height: 34)
            Image(systemName: context.state.status.icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .scaleEffect(context.state.status == .completed ? 1.12 : 1.0)
                .animation(.spring(response: 0.4, dampingFraction: 0.55),
                           value: context.state.status)
        }
        .onAppear {
            isPulsing = !context.state.status.isTerminal
        }
        .onChange(of: context.state.status) { _, s in
            isPulsing = !s.isTerminal
        }
    }
}

@available(iOS 16.1, *)
struct ExpandedTrailingView: View {
    let context: ActivityViewContext<ReelProcessingActivityAttributes>
    var body: some View {
        if context.state.status == .completed {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.brandGreen, Color.brandGreen.opacity(0.7)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 38, height: 38)
                Image(systemName: "checkmark")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
            }
            .scaleEffect(1.05)
            .animation(.spring(response: 0.45, dampingFraction: 0.5),
                       value: context.state.status)
        } else if context.state.status == .failed {
            ZStack {
                Circle()
                    .fill(Color.brandRed.opacity(0.18))
                    .frame(width: 38, height: 38)
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.brandRed)
            }
        } else {
            LACircularRing(progress: context.state.progress,
                           color: context.state.status.color)
                .frame(width: 38, height: 38)
        }
    }
}

@available(iOS 16.1, *)
struct ExpandedCenterView: View {
    let context: ActivityViewContext<ReelProcessingActivityAttributes>
    var body: some View {
        VStack(spacing: 2) {
            Text("informed")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.6))
                .textCase(.lowercase)
                .tracking(0.8)
            Text(context.state.status.shortLabel)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(context.state.status.color)
                .animation(.spring(response: 0.3, dampingFraction: 0.7),
                           value: context.state.status)
        }
    }
}

@available(iOS 16.1, *)
struct ExpandedBottomView: View {
    let context: ActivityViewContext<ReelProcessingActivityAttributes>

    private var isActive: Bool {
        !context.state.status.isTerminal
    }

    var body: some View {
        VStack(spacing: 8) {
            if isActive {
                // Progress bar with shimmer
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.12))
                        Capsule()
                            .fill(LinearGradient(
                                colors: [context.state.status.color,
                                         context.state.status.secondaryColor],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .frame(width: geo.size.width * context.state.progress)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8),
                                       value: context.state.progress)
                        LAShimmerView()
                            .frame(width: geo.size.width * context.state.progress)
                            .clipShape(Capsule())
                    }
                }
                .frame(height: 6)

                // % and ETA row
                HStack(alignment: .center) {
                    Text("\(Int(context.state.progress * 100))%")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))
                    Spacer()
                    if let est = context.state.estimatedSecondsRemaining, est > 0 {
                        Label(
                            est > 60 ? "~\(est / 60)m left" : "~\(est)s left",
                            systemImage: "clock"
                        )
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 2)
            }

            // Completed
            if context.state.status == .completed {
                VStack(spacing: 5) {
                    if let title = context.state.title {
                        Text(title)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 4)
                    }
                    if let verdict = context.state.verdict {
                        Text(verdict)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Color.brandGreen)
                            .clipShape(Capsule())
                    }
                    Label("Tap to view results", systemImage: "hand.tap.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.top, 1)
                }
            }

            // Failed
            if context.state.status == .failed {
                VStack(spacing: 6) {
                    Label("Fact-check failed", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.brandRed)
                    Text(context.state.statusMessage)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
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

@available(iOS 16.1, *)
struct LACircularRing: View {
    let progress: Double
    let color: Color
    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.15), lineWidth: 3)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
            Text("\(Int(progress * 100))%")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

@available(iOS 16.1, *)
struct LAShimmerView: View {
    @State private var phase: CGFloat = 0
    var body: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [.white.opacity(0), .white.opacity(0.25), .white.opacity(0)],
                startPoint: .leading, endPoint: .trailing
            )
            .offset(x: phase * geo.size.width - geo.size.width)
            .onAppear {
                withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                    phase = 2
                }
            }
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
