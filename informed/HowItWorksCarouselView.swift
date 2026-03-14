//
//  HowItWorksCarouselView.swift
//  informed
//
//  Video-driven tutorial with Instagram-story-style progress bars.
//  The video (0314.mp4) is played as a single file; boundary time observers
//  pause playback at each segment end so the user must tap Next to advance.
//

import SwiftUI
import AVFoundation
import Combine

// MARK: - Segment Model

private struct VideoSegment {
    let startTime: Double
    let endTime: Double   // use .infinity for the final segment
    let caption: String
}

// MARK: - ViewModel

@MainActor
private final class VideoTutorialViewModel: ObservableObject {

    // MARK: Published state
    @Published var currentSegment: Int = 0
    @Published var segmentProgress: Double = 0   // 0–1 within the active segment
    @Published var isCompleted: Bool = false
    @Published var isPausedAtBoundary: Bool = false
    /// Height-over-width ratio of the actual video; set from the asset track in init.
    @Published var videoAspectRatio: CGFloat = 19.5 / 9.0

    // MARK: Player
    let player: AVPlayer

    // MARK: Segments
    let segments: [VideoSegment] = [
        VideoSegment(startTime: 0.0,  endTime: 3.2,      caption: "Tap share on any social media app"),
        VideoSegment(startTime: 3.2,  endTime: 4.8,      caption: "Tap Share To"),
        VideoSegment(startTime: 4.8,  endTime: 8.3,      caption: "If you don't see Informed, scroll all the way to the right and click More"),
        VideoSegment(startTime: 8.3,  endTime: 12.0,     caption: "Find Informed and click it"),
        VideoSegment(startTime: 12.0, endTime: .infinity, caption: "That's it! You can now seek the truth!"),
    ]

    // MARK: Private
    private var periodicObserver: Any?
    private var boundaryObserver: Any?
    private var endObserver: NSObjectProtocol?

    // MARK: Init
    init() {
        guard let url = Bundle.main.url(forResource: "0314", withExtension: "mp4") else {
            fatalError("0314.mp4 not found in app bundle")
        }
        self.player = AVPlayer(url: url)
        self.player.actionAtItemEnd = .pause

        // Detect the real video dimensions so the phone frame has no black bars
        let asset = AVURLAsset(url: url)
        if let track = asset.tracks(withMediaType: .video).first {
            let natural = track.naturalSize
            let t = track.preferredTransform
            // When a == 0 & d == 0 the track is rotated 90/270 — swap w/h
            let isRotated = (abs(t.a) < 0.1 && abs(t.d) < 0.1)
            let displayW = isRotated ? natural.height : natural.width
            let displayH = isRotated ? natural.width  : natural.height
            if displayW > 0 { videoAspectRatio = displayH / displayW }
        }

        setupObservers()
    }

    deinit {
        if let obs = periodicObserver { player.removeTimeObserver(obs) }
        if let obs = boundaryObserver { player.removeTimeObserver(obs) }
        if let obs = endObserver { NotificationCenter.default.removeObserver(obs) }
    }

    // MARK: Public actions

    func advanceSegment() {
        let next = currentSegment + 1
        guard next < segments.count else {
            isCompleted = true
            return
        }
        currentSegment = next
        segmentProgress = 0
        isPausedAtBoundary = false
        let seekTime = CMTime(seconds: segments[next].startTime + 0.1, preferredTimescale: 600)
        player.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            Task { @MainActor [weak self] in self?.player.play() }
        }
    }

    func goBackSegment() {
        let prev = max(0, currentSegment - 1)
        isCompleted = false
        currentSegment = prev
        segmentProgress = 0
        isPausedAtBoundary = false
        let seekTime = CMTime(seconds: segments[prev].startTime, preferredTimescale: 600)
        player.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            Task { @MainActor [weak self] in self?.player.play() }
        }
    }

    func startPlayback() {
        player.seek(to: .zero)
        player.play()
    }

    func pausePlayback() {
        player.pause()
    }

    // MARK: Private helpers

    private func setupObservers() {
        // Boundary observer — fires at each segment's end time, pauses & marks boundary
        let boundaryTimes: [NSValue] = segments.compactMap { seg in
            guard seg.endTime.isFinite else { return nil }
            return NSValue(time: CMTime(seconds: seg.endTime, preferredTimescale: 600))
        }
        boundaryObserver = player.addBoundaryTimeObserver(forTimes: boundaryTimes, queue: .main) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                // Only pause if this boundary matches the current segment's expected end.
                // The last segment has endTime = .infinity so it is always skipped here,
                // letting the video play through to the end naturally.
                let segEnd = self.segments[self.currentSegment].endTime
                guard segEnd.isFinite else { return }
                let crossedAt = self.player.currentTime().seconds
                guard crossedAt >= segEnd - 0.4 else { return }
                self.player.pause()
                self.segmentProgress = 1.0
                self.isPausedAtBoundary = true
            }
        }

        // Periodic observer — 60 fps progress tracking for the progress bar fill
        let interval = CMTime(value: 1, timescale: 60)
        periodicObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self, !self.isPausedAtBoundary, !self.isCompleted else { return }
                let seg = self.segments[self.currentSegment]
                let elapsed = time.seconds - seg.startTime
                let duration: Double
                if seg.endTime.isFinite {
                    duration = seg.endTime - seg.startTime
                } else if let d = self.player.currentItem?.duration, d.isNumeric {
                    duration = max(1.0, d.seconds - seg.startTime)
                } else {
                    duration = 1.0
                }
                self.segmentProgress = max(0, min(1, elapsed / duration))
            }
        }

        // End-of-video observer — detects when the last segment finishes playing
        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.segmentProgress = 1.0
                self.isCompleted = true
            }
        }
    }
}

// MARK: - AVPlayerLayer wrapper

private struct VideoPlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.playerLayer.player = player
    }

    final class PlayerUIView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}

// MARK: - Progress bar row

private struct SegmentProgressBars: View {
    let segmentCount: Int
    let currentSegment: Int
    let segmentProgress: Double

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<segmentCount, id: \.self) { index in
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.3))
                        Capsule()
                            .fill(Color.white)
                            .frame(width: fillWidth(for: index, totalWidth: geo.size.width))
                    }
                }
                .frame(height: 3)
            }
        }
    }

    private func fillWidth(for index: Int, totalWidth: CGFloat) -> CGFloat {
        if index < currentSegment { return totalWidth }
        if index == currentSegment { return totalWidth * segmentProgress }
        return 0
    }
}

// MARK: - Main view

struct HowItWorksCarouselView: View {

    /// Completion callback. Pass `nil` when shown inline (e.g. InstructionsView).
    var onComplete: (() -> Void)?

    /// When `false` the Skip button is hidden — user must watch all segments.
    var allowSkip: Bool = true

    @StateObject private var vm = VideoTutorialViewModel()
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 0.04, green: 0.06, blue: 0.12).ignoresSafeArea()

                VStack(spacing: 0) {

                    // ── Top bar: skip ─────────────────────────────────────────────
                    HStack {
                        Spacer()
                        if allowSkip, let onComplete, vm.currentSegment < vm.segments.count - 1 {
                            Button("Skip") {
                                vm.pausePlayback()
                                onComplete()
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white.opacity(0.75))
                        } else {
                            Color.clear.frame(width: 44)
                        }
                    }
                    .frame(height: 44)
                    .padding(.horizontal, 20)

                    // ── Phone frame ───────────────────────────────────────────────
                    // Reserve space below the frame for caption (64pt) + button (52pt) + padding (40pt)
                    let reservedBelow: CGFloat = 16 + 64 + 12 + 52 + 40
                    let maxH = geo.size.height - 44 - reservedBelow
                    let maxW = geo.size.width - 40
                    // Fit within both constraints while preserving the video's exact aspect ratio
                    let fW = min(maxW, maxH / vm.videoAspectRatio)
                    let fH = fW * vm.videoAspectRatio

                    // ── Progress bars above the phone frame ──────────────────────
                    SegmentProgressBars(
                        segmentCount: vm.segments.count,
                        currentSegment: vm.currentSegment,
                        segmentProgress: vm.segmentProgress
                    )
                    .frame(width: fW - 16)
                    .padding(.bottom, 8)

                    ZStack(alignment: .top) {
                        // Glow halo
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .fill(Color.brandBlue.opacity(0.18))
                            .blur(radius: 24)
                            .frame(width: fW + 18, height: fH + 18)

                        // Phone shell — sized exactly to the video, no black bars
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(Color.black)
                            .frame(width: fW, height: fH)
                            .overlay(
                                VideoPlayerView(player: vm.player)
                                    .frame(width: fW, height: fH)
                                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 26, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1.5)
                            )
                            .shadow(color: .black.opacity(0.5), radius: 18, y: 8)
                    }

                    // ── Caption ───────────────────────────────────────────────────
                    Text(vm.segments[vm.currentSegment].caption)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .padding(.horizontal, 32)
                        .padding(.top, 16)
                        .animation(.easeInOut(duration: 0.2), value: vm.currentSegment)
                        .frame(height: 64)

                    Spacer(minLength: 0)

                    // ── Bottom action ─────────────────────────────────────────────
                    if let onComplete {
                        HStack(spacing: 12) {
                            // Back button
                            if vm.currentSegment > 0 {
                                Button { vm.goBackSegment() } label: {
                                    Image(systemName: "arrow.left")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(width: 50, height: 50)
                                        .background(Color.white.opacity(0.15))
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                            } else {
                                Color.clear.frame(width: 50, height: 50)
                            }
                            // Next / Get Started
                            bottomButton(onComplete: onComplete)
                        }
                        .padding(.horizontal, 28)
                        .padding(.bottom, 40)
                    } else {
                        HStack(spacing: 32) {
                            // Back arrow
                            if vm.currentSegment > 0 {
                                Button { vm.goBackSegment() } label: {
                                    Image(systemName: "arrow.left.circle.fill")
                                        .font(.system(size: 44))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [Color.brandBlue, Color.brandBlue.opacity(0.6)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .shadow(color: Color.brandBlue.opacity(0.3), radius: 10, y: 5)
                                }
                            } else {
                                Color.clear.frame(width: 44, height: 44)
                            }
                            // Forward arrow
                            if !vm.isCompleted {
                                Button { vm.advanceSegment() } label: {
                                    Image(systemName: "arrow.right.circle.fill")
                                        .font(.system(size: 44))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [Color.brandBlue, Color.brandBlue.opacity(0.6)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .shadow(color: Color.brandBlue.opacity(0.3), radius: 10, y: 5)
                                }
                                .disabled(!vm.isPausedAtBoundary)
                                .opacity(vm.isPausedAtBoundary ? 1.0 : 0.4)
                                .animation(.easeInOut(duration: 0.2), value: vm.isPausedAtBoundary)
                            } else {
                                Color.clear.frame(width: 44, height: 44)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 36)
                    }
                }
            }
        }
        .onAppear  { vm.startPlayback() }
        .onDisappear { vm.pausePlayback() }
    }

    // MARK: - Bottom button (onboarding / sign-up flow)

    @ViewBuilder
    private func bottomButton(onComplete: @escaping () -> Void) -> some View {
        let isLastSegment = vm.currentSegment >= vm.segments.count - 1
        Button {
            if isLastSegment {
                onComplete()
            } else {
                vm.advanceSegment()
            }
        } label: {
            HStack(spacing: 8) {
                Text(isLastSegment ? "Get Started" : "Next")
                    .font(.headline)
                Image(systemName: isLastSegment ? "checkmark.circle.fill" : "arrow.right")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color.brandBlue, Color.brandTeal],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.brandBlue.opacity(0.4), radius: 12, y: 6)
        }
        // Disable "Next" until the player has actually paused at the boundary
        .disabled(!vm.isPausedAtBoundary && !isLastSegment)
        .opacity((!vm.isPausedAtBoundary && !isLastSegment) ? 0.45 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: vm.isPausedAtBoundary)
    }
}

    // MARK: - Preview

struct HowItWorksCarouselView_Previews: PreviewProvider {
    static var previews: some View {
        HowItWorksCarouselView(onComplete: {})
    }
}
