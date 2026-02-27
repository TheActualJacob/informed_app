//
//  HowItWorksCarouselView.swift
//  informed
//
//  Swipeable tutorial carousel shown on the How It Works screen and during sign-up.
//

import SwiftUI

// MARK: - Tutorial Step Model

struct TutorialStep {
    let imageName: String
    let title: String
    let description: String
    let accentColor: Color
}

// MARK: - Carousel View

struct HowItWorksCarouselView: View {

    /// Called when the user taps "Get Started" on the last slide, or "Skip" on any slide.
    /// Pass `nil` to hide the action button entirely (e.g. when shown inline in InstructionsView).
    var onComplete: (() -> Void)?

    @State private var currentPage: Int = 0
    @Environment(\.colorScheme) var colorScheme

    private let steps: [TutorialStep] = [
        TutorialStep(
            imageName: "demo0",
            title: "Begin Your Informed Journey",
            description: "See real-time fact checks on social media content — know what's true before you share",
            accentColor: Color(red: 0.45, green: 0.25, blue: 0.95)
        ),
        TutorialStep(
            imageName: "demo1",
            title: "Open Your Social App",
            description: "Click the share button on your social media platform",
            accentColor: .brandTeal
        ),
        TutorialStep(
            imageName: "demo2",
            title: "Tap Share To",
            description: "Click the \"Share to\" button in the share menu",
            accentColor: .brandBlue
        ),
        TutorialStep(
            imageName: "demo3",
            title: "Find Informed",
            description: "Find Informed in the apps — you may need to scroll all the way left if it's your first time",
            accentColor: Color(red: 0.45, green: 0.25, blue: 0.95)
        ),
        TutorialStep(
            imageName: "demo4",
            title: "You're All Set!",
            description: "That's it! Start your fact check and get notified when it's ready (usually takes around 30 seconds)",
            accentColor: .brandGreen
        )
    ]

    var body: some View {
        ZStack {
            // Animated background that shifts with the current step
            steps[currentPage].accentColor
                .opacity(0.08)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.4), value: currentPage)

            VStack(spacing: 0) {

                // Skip button (hidden on last page)
                HStack {
                    Spacer()
                    if let onComplete = onComplete, currentPage < steps.count - 1 {
                        Button("Skip") {
                            withAnimation(.spring(response: 0.4)) {
                                onComplete()
                            }
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                    } else {
                        // Placeholder to keep layout stable
                        Color.clear.frame(height: 44)
                    }
                }

                // Page carousel
                TabView(selection: $currentPage) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        TutorialPageView(step: step)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.35), value: currentPage)

                // Dot indicator
                HStack(spacing: 8) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Capsule()
                            .fill(index == currentPage
                                  ? steps[currentPage].accentColor
                                  : Color.secondary.opacity(0.25))
                            .frame(width: index == currentPage ? 22 : 8, height: 8)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
                    }
                }
                .padding(.top, 4)

                // Bottom action button
                if let onComplete = onComplete {
                    actionButton(onComplete: onComplete)
                        .padding(.horizontal, 28)
                        .padding(.top, 20)
                        .padding(.bottom, 36)
                } else {
                    // Navigation-only forward arrow
                    forwardArrow
                        .padding(.top, 20)
                        .padding(.bottom, 36)
                }
            }
        }
    }

    // MARK: - Action button

    @ViewBuilder
    private func actionButton(onComplete: @escaping () -> Void) -> some View {
        let isLast = currentPage == steps.count - 1
        Button {
            withAnimation(.spring(response: 0.4)) {
                if isLast {
                    onComplete()
                } else {
                    currentPage += 1
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(isLast ? "Get Started" : "Next")
                    .font(.headline)
                Image(systemName: isLast ? "checkmark.circle.fill" : "arrow.right")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [steps[currentPage].accentColor, steps[currentPage].accentColor.opacity(0.7)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: steps[currentPage].accentColor.opacity(0.35), radius: 12, y: 6)
        }
        .animation(.easeInOut(duration: 0.25), value: currentPage)
    }

    // MARK: - Forward arrow (inline / no dismiss action)

    private var forwardArrow: some View {
        HStack {
            Spacer()
            if currentPage < steps.count - 1 {
                Button {
                    withAnimation(.spring(response: 0.4)) { currentPage += 1 }
                } label: {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [steps[currentPage].accentColor, steps[currentPage].accentColor.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: steps[currentPage].accentColor.opacity(0.3), radius: 10, y: 5)
                }
            } else {
                // Spacer placeholder on last page
                Color.clear.frame(width: 44, height: 44)
            }
            Spacer()
        }
    }
}

// MARK: - Individual Page View

private struct TutorialPageView: View {

    let step: TutorialStep
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 24) {

            // Screenshot card
            ZStack(alignment: .bottom) {
                // Glow behind the card
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(step.accentColor.opacity(0.18))
                    .blur(radius: 24)
                    .padding(.horizontal, 24)

                // The screenshot itself
                Image(step.imageName)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [step.accentColor.opacity(0.5), step.accentColor.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: step.accentColor.opacity(0.25), radius: 20, y: 10)
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.5 : 0.08), radius: 8, y: 4)
                    .padding(.horizontal, 28)
            }
            .frame(maxHeight: UIScreen.main.bounds.height * 0.50)

            // Text content
            VStack(spacing: 10) {
                Text(step.title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)

                Text(step.description)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 12)
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 12)
    }
}

// MARK: - Preview

struct HowItWorksCarouselView_Previews: PreviewProvider {
    static var previews: some View {
        HowItWorksCarouselView(onComplete: {})
    }
}
