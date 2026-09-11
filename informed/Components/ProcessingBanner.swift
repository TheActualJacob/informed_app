//
//  ProcessingBanner.swift
//  informed
//
//  Loading banner shown during fact-check processing.
//
//  Mirrors the Dynamic Island: headline, stage message, live countdown and the
//  same segmented stage bar. This is the only live progress surface on iPhones
//  without a Dynamic Island while the user is inside the app.
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

    private let tint: Color = .brandBlue
    private var status: ProcessingStatus { progress?.status ?? .submitting }
    private var fraction: Double { progress?.progress ?? 0.06 }
    private var message: String {
        guard let progress, !progress.message.isEmpty else { return "Starting fact-check…" }
        return progress.message
    }
    private var sourceLabel: String {
        switch detectedPlatformFromURL(link) {
        case "instagram":      return "Instagram Reel"
        case "tiktok":         return "TikTok video"
        case "youtube_shorts": return "YouTube Short"
        case "twitter":        return "Post on X"
        case "threads":        return "Threads post"
        default:               return platformInfo(for: detectedPlatformFromURL(link)).name
        }
    }
    private var countdownEnd: Date? {
        guard let eta = progress?.etaDate, eta > Date().addingTimeInterval(1),
              eta < Date().addingTimeInterval(15 * 60) else { return nil }
        return eta
    }

    var body: some View {
        Button {
            HapticManager.lightImpact()
            onTap?()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    thumbnail

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Fact-checking \(sourceLabel)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Text(message)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .contentTransition(.opacity)
                    }

                    Spacer(minLength: 8)

                    countdown
                }

                SegmentedStageBar(status: status, progress: fraction, tint: tint,
                                  track: Color.primary.opacity(0.1), height: 5,
                                  labelColor: .secondary, activeLabelColor: .primary, labelSize: 11)
            }
            .padding(14)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
            )
            .shadow(
                color: Theme.Shadow.card(for: colorScheme),
                radius: Theme.Shadow.md,
                x: 0,
                y: 5
            )
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.4), value: fraction)
        .animation(.easeInOut(duration: 0.25), value: status)
        .accessibilityLabel("Fact-check in progress, \(Int(fraction * 100)) percent, \(message)")
    }

    // MARK: - Pieces

    private var thumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(tint.opacity(0.14))
            if let thumbnailURL, !isSocialPageURL(thumbnailURL) {
                AsyncImage(url: thumbnailURL) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(tint)
                    }
                }
            } else {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(tint)
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    @ViewBuilder
    private var countdown: some View {
        if let end = countdownEnd {
            Text(timerInterval: Date()...end, countsDown: true, showsHours: false)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.primary)
                .frame(width: 46, alignment: .trailing)
        } else {
            ProgressView()
                .controlSize(.small)
                .tint(.secondary)
        }
    }

    /// Social page URLs (instagram.com/reel/…) aren't images; don't try to load them.
    private func isSocialPageURL(_ url: URL) -> Bool {
        let s = url.absoluteString.lowercased()
        return ["instagram.com", "tiktok.com", "twitter.com", "x.com", "threads.net", "youtube.com", "youtu.be"]
            .contains(where: { s.contains($0) })
    }
}
