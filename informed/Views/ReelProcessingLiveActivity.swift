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

// MARK: - Lock Screen View

@available(iOS 16.1, *)
struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<ReelProcessingActivityAttributes>

    private var isTerminal: Bool {
        context.state.status == .completed || context.state.status == .failed
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(context.state.status.color.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: context.state.status.icon)
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundColor(context.state.status.color)
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: context.state.status)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Fact-Checking Reel")
                        .font(.system(size: 14, weight: .bold))
                    Text(context.state.statusMessage)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if context.state.status == .completed {
                    if let verdict = context.state.verdict {
                        Text(verdict)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(context.state.status.color)
                            .clipShape(Capsule())
                    }
                } else if context.state.status != .failed {
                    LACircularRing(progress: context.state.progress, color: context.state.status.color)
                        .frame(width: 38, height: 38)
                }
            }

            if !isTerminal {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.gray.opacity(0.18))
                        Capsule()
                            .fill(LinearGradient(
                                colors: [context.state.status.color, context.state.status.secondaryColor],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .frame(width: geo.size.width * context.state.progress)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: context.state.progress)
                    }
                }
                .frame(height: 5)
            }

            if context.state.status == .completed, let title = context.state.title {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill").foregroundColor(.brandGreen).font(.system(size: 13))
                    Text(title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                    Spacer()
                    HStack(spacing: 3) {
                        Image(systemName: "hand.tap.fill").font(.system(size: 10))
                        Text("View results").font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.brandGreen)
                }
                .padding(10)
                .background(Color.brandGreen.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if context.state.status == .failed {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.brandRed)
                        .font(.system(size: 13))
                    Text(context.state.statusMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    Spacer()
                }
                .padding(10)
                .background(Color.brandRed.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(16)
        .activityBackgroundTint(Color.cardBackground)
        .activitySystemActionForegroundColor(context.state.status.color)
    }
}

// MARK: - Compact Views

@available(iOS 16.1, *)
struct CompactLeadingView: View {
    let context: ActivityViewContext<ReelProcessingActivityAttributes>
    var body: some View {
        Image(systemName: context.state.status.icon)
            .font(.system(size: 11, weight: .semibold))
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
                HStack(spacing: 2) {
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 10, weight: .bold))
                    Text("Done").font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(.brandGreen)
                .padding(.trailing, 2)
            } else if context.state.status == .failed {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.brandRed)
                    .padding(.trailing, 2)
            } else {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.22), lineWidth: 1.5)
                    Circle()
                        .trim(from: 0, to: context.state.progress)
                        .stroke(context.state.status.color, lineWidth: 1.5)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: context.state.progress)
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
            Image(systemName: "checkmark.seal.fill").font(.system(size: 9, weight: .bold)).foregroundColor(.brandGreen)
        } else if context.state.status == .failed {
            Image(systemName: "xmark.circle.fill").font(.system(size: 9, weight: .bold)).foregroundColor(.brandRed)
        } else {
            ZStack {
                Circle().stroke(Color.white.opacity(0.22), lineWidth: 1.2)
                Circle()
                    .trim(from: 0, to: context.state.progress)
                    .stroke(context.state.status.color, lineWidth: 1.2)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: context.state.progress)
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
            Circle()
                .fill(context.state.status.color.opacity(isPulsing ? 0.24 : 0.13))
                .frame(width: 36, height: 36)
                .animation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true), value: isPulsing)
            Image(systemName: context.state.status.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(context.state.status.color)
                .scaleEffect(context.state.status == .completed ? 1.15 : 1.0)
                .animation(.spring(response: 0.4, dampingFraction: 0.55), value: context.state.status)
        }
        .onAppear {
            isPulsing = (context.state.status != .completed && context.state.status != .failed)
        }
        .onChange(of: context.state.status) { _, s in
            isPulsing = (s != .completed && s != .failed)
        }
    }
}

@available(iOS 16.1, *)
struct ExpandedTrailingView: View {
    let context: ActivityViewContext<ReelProcessingActivityAttributes>
    var body: some View {
        if context.state.status == .completed {
            ZStack {
                Circle().fill(Color.brandGreen.opacity(0.18)).frame(width: 36, height: 36)
                Image(systemName: "checkmark").font(.system(size: 18, weight: .bold)).foregroundColor(.brandGreen)
            }
            .scaleEffect(1.1)
            .animation(.spring(response: 0.45, dampingFraction: 0.5), value: context.state.status)
        } else if context.state.status == .failed {
            ZStack {
                Circle().fill(Color.brandRed.opacity(0.18)).frame(width: 36, height: 36)
                Image(systemName: "xmark").font(.system(size: 16, weight: .bold)).foregroundColor(.brandRed)
            }
        } else {
            LACircularRing(progress: context.state.progress, color: context.state.status.color)
                .frame(width: 36, height: 36)
        }
    }
}

@available(iOS 16.1, *)
struct ExpandedCenterView: View {
    let context: ActivityViewContext<ReelProcessingActivityAttributes>
    var body: some View {
        VStack(spacing: 3) {
            Text("Fact-Checking")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary.opacity(0.7))
                .textCase(.uppercase)
                .tracking(0.6)
            // Current stage name in its stage color — updates live as backend progresses
            Text(context.state.status.shortLabel)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(context.state.status.color)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: context.state.status)
        }
    }
}

@available(iOS 16.1, *)
struct ExpandedBottomView: View {
    let context: ActivityViewContext<ReelProcessingActivityAttributes>

    private var isActive: Bool {
        context.state.status != .completed && context.state.status != .failed
    }

    var body: some View {
        VStack(spacing: 10) {
            if isActive {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.14))
                        Capsule()
                            .fill(LinearGradient(
                                colors: [context.state.status.color, context.state.status.secondaryColor],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .frame(width: geo.size.width * context.state.progress)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: context.state.progress)
                        LAShimmerView()
                            .frame(width: geo.size.width * context.state.progress)
                            .clipShape(Capsule())
                    }
                }
                .frame(height: 5)

                HStack {
                    Text("\(Int(context.state.progress * 100))%")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary.opacity(0.85))
                    Spacer()
                    if let estimate = context.state.estimatedSecondsRemaining, estimate > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "clock").font(.system(size: 10))
                            Text(estimate > 60 ? "\(estimate / 60)m" : "\(estimate)s").font(.system(size: 12))
                        }
                        .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 6)
            }

            if context.state.status == .completed {
                VStack(spacing: 6) {
                    if let title = context.state.title {
                        Text(title)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 6)
                    }
                    if let verdict = context.state.verdict {
                        Text(verdict)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Color.brandGreen)
                            .clipShape(Capsule())
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "hand.tap.fill").font(.system(size: 10))
                        Text("Tap to view results").font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
                }
            }

            if context.state.status == .failed {
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.brandRed)
                        Text("Fact-check failed")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.brandRed)
                    }
                    Text(context.state.statusMessage)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 8)
                    Text("Dismissing shortly…")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.6))
                        .padding(.top, 2)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(.horizontal, 10)
    }
}

// MARK: - Supporting Views

@available(iOS 16.1, *)
struct LACircularRing: View {
    let progress: Double
    let color: Color
    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.15), lineWidth: 3.5)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
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
                colors: [.white.opacity(0), .white.opacity(0.28), .white.opacity(0)],
                startPoint: .leading, endPoint: .trailing
            )
            .offset(x: phase * geo.size.width - geo.size.width)
            .onAppear {
                withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) { phase = 2 }
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
