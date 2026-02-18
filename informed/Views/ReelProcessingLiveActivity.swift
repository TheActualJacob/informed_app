//
//  ReelProcessingLiveActivity.swift
//  informed
//
//  Dynamic Island and Live Activity UI for reel processing
//

import ActivityKit
import SwiftUI
import WidgetKit

@available(iOS 16.1, *)
struct ReelProcessingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReelProcessingActivityAttributes.self) { context in
            // Lock screen and notification view
            LockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded region
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
                // Compact leading (left side of notch)
                CompactLeadingView(context: context)
            } compactTrailing: {
                // Compact trailing (right side of notch)
                CompactTrailingView(context: context)
            } minimal: {
                // Minimal view (when multiple activities or single dot)
                MinimalView(context: context)
            }
            .keylineTint(context.state.status.color)
        }
    }
}

// MARK: - Lock Screen View

@available(iOS 16.1, *)
struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<ReelProcessingActivityAttributes>
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: context.state.status.icon)
                    .font(.title2)
                    .foregroundColor(context.state.status.color)
                    .frame(width: 40, height: 40)
                    .background(context.state.status.color.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Fact-Checking Reel")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(context.state.statusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Progress indicator
                if context.state.status != .completed && context.state.status != .failed {
                    CircularProgressView(progress: context.state.progress)
                        .frame(width: 32, height: 32)
                }
            }
            
            // Progress bar
            if context.state.status != .completed && context.state.status != .failed {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                        
                        // Progress
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [context.state.status.color, context.state.status.color.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * context.state.progress)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: context.state.progress)
                    }
                }
                .frame(height: 6)
            }
            
            // Completion info
            if context.state.status == .completed, let title = context.state.title {
                HStack {
                    Text(title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if let verdict = context.state.verdict {
                        Text(verdict)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(context.state.status.color)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(16)
        .activityBackgroundTint(Color.cardBackground)
        .activitySystemActionForegroundColor(.brandBlue)
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
            .frame(width: 20, height: 20)
    }
}

@available(iOS 16.1, *)
struct CompactTrailingView: View {
    let context: ActivityViewContext<ReelProcessingActivityAttributes>
    
    var body: some View {
        if context.state.status == .completed {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.brandGreen)
                .frame(width: 20, height: 20)
        } else if context.state.status == .failed {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.brandRed)
                .frame(width: 20, height: 20)
        } else {
            // Progress ring - smaller to prevent clipping
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                
                Circle()
                    .trim(from: 0, to: context.state.progress)
                    .stroke(context.state.status.color, lineWidth: 1.5)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: context.state.progress)
            }
            .frame(width: 14, height: 14)
        }
    }
}

// MARK: - Minimal View

@available(iOS 16.1, *)
struct MinimalView: View {
    let context: ActivityViewContext<ReelProcessingActivityAttributes>
    
    var body: some View {
        if context.state.status == .completed {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.brandGreen)
                .frame(width: 16, height: 16)
        } else if context.state.status == .failed {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.brandRed)
                .frame(width: 16, height: 16)
        } else {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 1.2)
                
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Status icon with animation
            ZStack {
                Circle()
                    .fill(context.state.status.color.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: context.state.status.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(context.state.status.color)
            }
            .scaleEffect(context.state.status == .completed ? 1.1 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: context.state.status)
        }
    }
}

@available(iOS 16.1, *)
struct ExpandedTrailingView: View {
    let context: ActivityViewContext<ReelProcessingActivityAttributes>
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if context.state.status != .completed && context.state.status != .failed {
                // Circular progress
                CircularProgressView(progress: context.state.progress)
                    .frame(width: 44, height: 44)
            } else if context.state.status == .completed {
                // Completion checkmark
                ZStack {
                    Circle()
                        .fill(Color.brandGreen.opacity(0.2))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.brandGreen)
                }
                .scaleEffect(1.1)
            }
        }
    }
}

@available(iOS 16.1, *)
struct ExpandedCenterView: View {
    let context: ActivityViewContext<ReelProcessingActivityAttributes>
    
    var body: some View {
        VStack(spacing: 2) {
            Text("Fact-Checking")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            Text(context.state.statusMessage)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
        }
    }
}

@available(iOS 16.1, *)
struct ExpandedBottomView: View {
    let context: ActivityViewContext<ReelProcessingActivityAttributes>
    
    var body: some View {
        VStack(spacing: 8) {
            // Progress bar with gradient
            if context.state.status != .completed && context.state.status != .failed {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                        
                        // Animated progress
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        context.state.status.color,
                                        context.state.status.color.opacity(0.7)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * context.state.progress)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: context.state.progress)
                        
                        // Shimmer effect for active processing
                        if context.state.status == .processing || context.state.status == .analyzing || context.state.status == .factChecking {
                            ShimmerView()
                                .frame(width: geometry.size.width * context.state.progress)
                                .clipShape(Capsule())
                        }
                    }
                }
                .frame(height: 6)
                
                // Progress percentage and time estimate - improved layout with padding
                HStack(spacing: 8) {
                    Text("\(Int(context.state.progress * 100))%")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .fixedSize()
                    
                    Spacer(minLength: 4)
                    
                    // Time estimate
                    if context.state.progress < 1.0 {
                        Text("~\(estimatedTimeRemaining(progress: context.state.progress))")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.secondary)
                            .fixedSize()
                    }
                }
                .padding(.horizontal, 4)
            }
            
            // Completion info
            if context.state.status == .completed {
                VStack(spacing: 4) {
                    if let title = context.state.title {
                        Text(title)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "hand.tap.fill")
                            .font(.caption2)
                        Text("Tap to view results")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }
            }
            
            // Error message
            if context.state.status == .failed {
                Text(context.state.statusMessage)
                    .font(.caption)
                    .foregroundColor(.brandRed)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
        }
        .padding(.horizontal, 8)
    }
    
    private func estimatedTimeRemaining(progress: Double) -> String {
        // Use backend-provided estimate if available
        if let estimate = context.state.estimatedSecondsRemaining, estimate > 0 {
            if estimate > 60 {
                return "\(Int(estimate / 60))m"
            } else {
                return "\(estimate)s"
            }
        }
        
        // Fallback to calculated estimate
        let remaining = 1.0 - progress
        let totalTime: Double = 90 // Assume 90 seconds total
        let timeLeft = Int(totalTime * remaining)
        
        if timeLeft > 60 {
            return "\(Int(timeLeft / 60))m"
        } else {
            return "\(timeLeft)s"
        }
    }
}

// MARK: - Supporting Views

@available(iOS 16.1, *)
struct CircularProgressView: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 3)
            
            // Progress circle
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [Color.brandBlue, Color.brandBlue.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
            
            // Percentage text
            Text("\(Int(progress * 100))%")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

@available(iOS 16.1, *)
struct ShimmerView: View {
    @State private var phase: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            LinearGradient(
                colors: [
                    Color.white.opacity(0),
                    Color.white.opacity(0.3),
                    Color.white.opacity(0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .offset(x: phase * geometry.size.width - geometry.size.width)
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
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
        // Note: Live Activity previews work best in the widget simulator
        // Use Xcode's widget preview scheme to see the Dynamic Island
        Text("Use Widget Preview to see Live Activity")
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}

