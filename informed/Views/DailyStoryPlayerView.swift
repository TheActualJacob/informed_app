import SwiftUI
import Combine

struct DailyStoryPlayerView: View {
    let story: Story
    var onDismiss: (() -> Void)?

    @State private var currentIndex: Int = 0
    @State private var isFinished: Bool = false
    @State private var slideAppeared: Bool = false

    // Auto-advance timer
    @State private var isPaused: Bool = false
    @State private var timerProgress: CGFloat = 0

    @Environment(\.dismiss) private var dismiss

    /// True when the current page is a single heading or image (no scroll needed).
    private var currentPageIsSolo: Bool {
        guard currentIndex < pages.count else { return true }
        let page = pages[currentIndex]
        return page.count == 1 && (page[0].type == .heading || page[0].type == .image)
    }

    /// Adaptive reading duration based on block types and word count.
    private func pageDuration(for page: [StoryBlock]) -> Double {
        if page.count == 1 {
            switch page[0].type {
            case .heading:   return 4.0
            case .image:     return 6.0
            case .factCheck: return 10.0
            default: break
            }
        }
        // Sum words across all text-bearing blocks, ~200 wpm → 0.3s/word
        let totalWords = page
            .compactMap { $0.text }
            .joined(separator: " ")
            .split(separator: " ").count
        return max(7.0, min(24.0, Double(totalWords) * 0.3 + 4.0))
    }

    /// Builds slides: default is 1 block per slide.
    /// If a block has attachToPrevious=true it is grouped onto the same slide
    /// as the block before it (stacked, scrollable), matching the CMS grouping.
    private var pages: [[StoryBlock]] {
        var result: [[StoryBlock]] = []
        for block in story.blocks {
            if block.attachToPrevious && !result.isEmpty {
                result[result.count - 1].append(block)
            } else {
                result.append([block])
            }
        }
        return result
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isFinished {
                finishedView
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else if !pages.isEmpty {
                // Slide content
                BriefingSlideView(
                    blocks: pages[currentIndex],
                    storyHeadline: story.headline,
                    slideIndex: currentIndex,
                    totalSlides: pages.count
                )
                .id(currentIndex)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .offset(x: 20)),
                    removal: .opacity.combined(with: .offset(x: -20))
                ))

                // Controls overlay
                VStack(spacing: 0) {
                    // Top bar: progress + close
                    topBar
                        .padding(.top, 8)

                    Spacer()

                    // Bottom: slide counter + nav hint
                    bottomBar
                        .padding(.bottom, 20)
                }
                .padding(.horizontal, 16)

                // Tap + long-press zones
                tapControls
            } else {
                Text("This briefing has no content.")
                    .foregroundStyle(.secondary)
            }
        }
        .statusBarHidden(true)
        // Long-press anywhere pauses the timer; any touch-end resumes it.
        // These are simultaneousGestures so they never block the ScrollView.
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.25)
                .onChanged { _ in isPaused = true }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onEnded { _ in isPaused = false }
        )
        // Horizontal swipe navigates on stacked (scrollable) pages.
        // The ScrollView still handles vertical drags independently.
        .simultaneousGesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    guard !currentPageIsSolo else { return }
                    isPaused = false
                    let h = value.translation.width
                    let v = value.translation.height
                    guard abs(h) > abs(v), abs(h) > 50 else { return }
                    if h < 0 { advanceSlide() } else { goBack() }
                }
        )
        .onAppear { slideAppeared = true }
        .onReceive(
            Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
        ) { _ in
            guard !isPaused, !isFinished, !pages.isEmpty else { return }
            let duration = pageDuration(for: pages[currentIndex])
            timerProgress += 0.05 / duration
            if timerProgress >= 1.0 {
                advanceSlide()
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(alignment: .top, spacing: 0) {
            // Segmented progress
            StoryProgressBarView(
                total: pages.count,
                current: currentIndex,
                timerProgress: timerProgress
            )

            // Close button
            Button {
                onDismiss?()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding(.leading, 12)
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            // Slide counter
            Text("\(currentIndex + 1) of \(pages.count)")
                .font(.custom("Inter-Medium", size: 12))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())

            Spacer()

            // Share
            ShareLink(
                item: "Check out this briefing on Informed: \(story.headline)"
            ) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
    }

    // MARK: - Tap Controls
    // Only active on solo (heading/image) pages. On stacked/scrollable pages
    // hit-testing is disabled so all touches reach the underlying ScrollView.
    // Navigation on stacked pages is handled by the horizontal swipe gesture
    // applied to the parent ZStack.

    private var tapControls: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Left 30% → previous
                Color.clear
                    .contentShape(Rectangle())
                    .frame(width: geometry.size.width * 0.3)
                    .onTapGesture { goBack() }

                // Right 70% → next
                Color.clear
                    .contentShape(Rectangle())
                    .frame(width: geometry.size.width * 0.7)
                    .onTapGesture { advanceSlide() }
            }
        }
        // Transparent to touches on scrollable pages so the ScrollView works.
        .allowsHitTesting(currentPageIsSolo)
    }

    // MARK: - Navigation

    private func advanceSlide() {
        withAnimation(.easeInOut(duration: 0.25)) {
            if currentIndex < pages.count - 1 {
                currentIndex += 1
            } else {
                isFinished = true
            }
        }
        timerProgress = 0
    }

    private func goBack() {
        withAnimation(.easeInOut(duration: 0.25)) {
            if currentIndex > 0 {
                currentIndex -= 1
            }
        }
        timerProgress = 0
    }

    // MARK: - Finished View

    private var finishedView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.brandTeal.opacity(0.12))
                    .frame(width: 110, height: 110)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60, weight: .light))
                    .foregroundStyle(Color.brandTeal)
            }

            Text("You're all caught up")
                .font(.custom("GreycliffCF-Bold", size: 28))
                .foregroundColor(.white)

            Text("That's today's briefing.\nCheck back later for updates.")
                .font(.custom("Inter-Regular", size: 15))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Button {
                    withAnimation {
                        currentIndex = 0
                        isFinished = false
                        timerProgress = 0
                    }
                } label: {
                    Text("Read Again")
                        .font(.custom("Inter-SemiBold", size: 15))
                        .foregroundColor(.white)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 28)
                        .background(Color.white.opacity(0.1), in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                }

                Button {
                    onDismiss?()
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.custom("Inter-SemiBold", size: 15))
                        .foregroundColor(.white)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 36)
                        .background(Color.brandBlue, in: Capsule())
                }
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - Progress Bar

struct StoryProgressBarView: View {
    let total: Int
    let current: Int
    var timerProgress: CGFloat = 1

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<total, id: \.self) { index in
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Track
                        Capsule()
                            .fill(Color.white.opacity(0.2))

                        // Fill
                        Capsule()
                            .fill(Color.white)
                            .frame(width: fillWidth(for: index, totalWidth: geo.size.width))
                    }
                }
                .frame(height: 2.5)
            }
        }
    }

    private func fillWidth(for index: Int, totalWidth: CGFloat) -> CGFloat {
        if index < current {
            return totalWidth
        } else if index == current {
            return totalWidth * min(timerProgress, 1)
        } else {
            return 0
        }
    }
}
