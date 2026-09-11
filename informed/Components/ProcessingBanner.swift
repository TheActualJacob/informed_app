//
//  ProcessingBanner.swift
//  informed
//
//  Loading banner shown during fact-check processing.
//
//  Mirrors the Dynamic Island: stage label, gradient progress bar and a live
//  countdown. This is the ONLY live progress surface on iPhones without a
//  Dynamic Island while the user is inside the app, so it carries the same
//  information the island does.
//

import SwiftUI

struct ProcessingBanner: View {
    let link: String
    let thumbnailURL: URL?
    /// Live progress from `SharedReelManager.activeProcessingProgress`. Nil until
    /// the first poll returns, in which case a neutral "Starting…" state is shown.
    var progress: ProcessingProgressSnapshot? = nil
    /// Called when the user taps the banner (e.g. jump to My Reels).
    var onTap: (() -> Void)? = nil

    @Environment(\.colorScheme) var colorScheme

    private var status: ProcessingStatus { progress?.status ?? .submitting }
    private var fraction: Double { max(progress?.progress ?? 0.08, 0.04) }
    private var tint: Color { status.color }
    private var message: String {
        guard let progress, !progress.message.isEmpty else { return "Starting fact-check…" }
        return progress.message
    }
    private var platformLabel: String {
        platformInfo(for: detectedPlatformFromURL(link)).name
    }

    var body: some View {
        Button {
            HapticManager.lightImpact()
            onTap?()
        } label: {
            VStack(spacing: 10) {
                HStack(spacing: Theme.Spacing.md) {
                    thumbnail

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(status.shortLabel)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                                .contentTransition(.opacity)
                            Text("· \(platformLabel)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        Text(message)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .contentTransition(.opacity)
                    }

                    Spacer(minLength: 8)

                    ring
                }

                // Gradient progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.08))
                        Capsule()
                            .fill(LinearGradient(colors: [status.color, status.secondaryColor],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(geo.size.width * fraction, 8))
                    }
                }
                .frame(height: 5)

                // Stage stepper + countdown
                HStack(spacing: 8) {
                    stageDots
                    Spacer(minLength: 8)
                    countdown
                }
            }
            .padding(Theme.Spacing.lg)
            .background(.ultraThinMaterial)
            .background(Color.cardBackground.opacity(0.6))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous)
                    .stroke(tint.opacity(0.25), lineWidth: 0.75)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous))
            .shadow(
                color: Theme.Shadow.card(for: colorScheme),
                radius: Theme.Shadow.md,
                x: 0,
                y: 5
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: fraction)
        .animation(.easeInOut(duration: 0.25), value: status)
        .accessibilityLabel("Fact-check in progress, \(Int(fraction * 100)) percent, \(message)")
    }

    // MARK: - Pieces

    private var thumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm, style: .continuous)
                .fill(LinearGradient(colors: [status.color.opacity(0.18), status.secondaryColor.opacity(0.10)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            if let thumbnailURL, !isSocialPageURL(thumbnailURL) {
                AsyncImage(url: thumbnailURL) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Image(systemName: status.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(tint)
                    }
                }
            } else {
                Image(systemName: status.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(tint)
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .frame(width: 46, height: 46)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.sm, style: .continuous))
    }

    private var ring: some View {
        ZStack {
            Circle().stroke(tint.opacity(0.18), lineWidth: 3)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(fraction * 100))%")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.primary)
                .contentTransition(.numericText())
        }
        .frame(width: 38, height: 38)
    }

    private var stageDots: some View {
        HStack(spacing: 5) {
            ForEach(Array(ProcessingStatus.pipelineStages.enumerated()), id: \.offset) { idx, name in
                let isDone = idx < status.stageIndex
                let isActive = idx == status.stageIndex
                HStack(spacing: 4) {
                    Circle()
                        .fill(isDone || isActive ? tint : Color.primary.opacity(0.14))
                        .frame(width: 6, height: 6)
                        .overlay(
                            Circle().stroke(tint.opacity(isActive ? 0.35 : 0), lineWidth: 3)
                        )
                    if isActive {
                        Text(name)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(tint)
                            .transition(.opacity.combined(with: .move(edge: .leading)))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var countdown: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.system(size: 9, weight: .semibold))
            if let eta = progress?.etaDate, eta > Date().addingTimeInterval(1), eta < Date().addingTimeInterval(15 * 60) {
                Text(timerInterval: Date()...eta, countsDown: true, showsHours: false)
                    .monospacedDigit()
                    .frame(maxWidth: 40, alignment: .trailing)
                Text("left")
            } else {
                Text("Estimating…")
            }
        }
        .font(.system(size: 11, weight: .medium, design: .rounded))
        .foregroundColor(.secondary)
        .lineLimit(1)
    }

    /// Social page URLs (instagram.com/reel/…) aren't images; don't try to load them.
    private func isSocialPageURL(_ url: URL) -> Bool {
        let s = url.absoluteString.lowercased()
        return ["instagram.com", "tiktok.com", "twitter.com", "x.com", "threads.net", "youtube.com", "youtu.be"]
            .contains(where: { s.contains($0) })
    }
}
