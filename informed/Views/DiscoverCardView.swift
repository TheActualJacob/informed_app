//
//  DiscoverCardView.swift
//  informed

import SwiftUI
import UIKit

struct DiscoverCardView: View {

    let reel: PublicReel
    @ObservedObject var viewModel: DiscoverFeedViewModel
    let onTap: () -> Void

    @State private var showSources   = false
    @State private var showComments  = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // Background thumbnail fills the card
            CardThumbnailView(reel: reel)

            // Bottom scrim — makes claim text readable
            LinearGradient(
                colors: [.clear, .black.opacity(0.85)],
                startPoint: UnitPoint(x: 0.5, y: 0.35),
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            // Top scrim — behind platform label
            LinearGradient(
                colors: [.black.opacity(0.55), .clear],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.25)
            )
            .frame(maxHeight: .infinity, alignment: .top)
            .allowsHitTesting(false)

            // Top bar: platform + time ago
            CardTopBar(reel: reel)
                .frame(maxHeight: .infinity, alignment: .top)
                .allowsHitTesting(false)

            // Bottom content: claim section + reaction bar
            // Sits above the tab bar using safeAreaInset so it's never hidden.
            VStack(spacing: 0) {
                CardClaimSection(reel: reel, showSources: $showSources)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)

                ReactionBarView(
                    reactionCounts: viewModel.reactionState[reel.id] ?? ReactionCounts(likes: 0, dislikes: 0),
                    onLike:    { Task { await viewModel.react(reelId: reel.id, reaction: .like) } },
                    onDislike: { Task { await viewModel.react(reelId: reel.id, reaction: .dislike) } },
                    onComment: { showComments = true },
                    onShare:   { presentShareSheet() }
                )
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 16)
            .safeAreaPadding(.bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        // Tap anywhere that isn't a button → navigate to detail
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .sheet(isPresented: $showSources) {
            SourcesSheetView(sources: reel.sources)
        }
        .sheet(isPresented: $showComments) {
            CommentsSheetView(factCheckId: reel.id)
        }
    }

    private func presentShareSheet() {
        guard let url = URL(string: Config.Endpoints.shareBase + reel.id) else { return }
        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root  = scene.windows.first?.rootViewController else { return }
        if let popover = av.popoverPresentationController {
            popover.sourceView = root.view
            popover.sourceRect = CGRect(x: root.view.bounds.midX, y: root.view.bounds.midY,
                                        width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        root.present(av, animated: true)
    }
}

// MARK: - Card Thumbnail (dedicated subview)

private struct CardThumbnailView: View {
    let reel: PublicReel

    var body: some View {
        // Color.clear anchors the size to the proposed bounds;
        // the image is an overlay so it never participates in layout.
        Color.clear
            .overlay {
                if let urlStr = reel.thumbnailUrl, let url = URL(string: urlStr) {
                    ThumbnailImage(url: url, platform: reel.detectedPlatform)
                        .scaledToFill()
                } else {
                    ThumbnailPlaceholder(platform: reel.detectedPlatform)
                }
            }
            .clipped()
    }
}

// MARK: - Top Bar (dedicated subview)

private struct CardTopBar: View {
    let reel: PublicReel

    var body: some View {
        HStack {
            Label(reel.platformDisplayName, systemImage: reel.platformIcon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())

            Spacer()

            Text(reel.timeAgo)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(.horizontal, 16)
        .padding(.top, 60)
    }
}

// MARK: - Claim Section (dedicated subview)

private struct CardClaimSection: View {
    let reel: PublicReel
    @Binding var showSources: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Verdict pill + credibility percentage
            HStack {
                let level = reel.averageCredibilityLevel
                Label(level.rawValue, systemImage: level.icon)
                    .font(.caption.weight(.bold))
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                    .background(level.color.opacity(0.18))
                    .foregroundStyle(level.color)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(level.color.opacity(0.35), lineWidth: 1))

                Spacer()

                Text("\(Int(reel.averageCredibilityScore * 100))%")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            // Claim — prominent, 3 lines max
            Text(reel.claim)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Platform name + Sources chip
            HStack {
                Label(reel.platformDisplayName, systemImage: reel.platformIcon)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)

                Spacer()

                Button("Sources ›") { showSources = true }
                    .font(.caption.weight(.semibold))
                    .padding(.vertical, 5)
                    .padding(.horizontal, 12)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .foregroundStyle(.white)
            }

            // Summary — 2 lines
            Text(reel.summary)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.35))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                }
        }
    }
}

// MARK: - Sources Sheet (dedicated subview)

private struct SourcesSheetView: View {
    let sources: [String]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if sources.isEmpty {
                    Text("No sources listed.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(sources, id: \.self) { source in
                        if let url = URL(string: source) {
                            Link(destination: url) {
                                Text(url.host ?? source)
                                    .lineLimit(1)
                            }
                        } else {
                            Text(source)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Sources")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
