//
//  FactDetailView.swift
//  informed
//
//  Detailed view for fact-check results
//

import SwiftUI
import SafariServices
import ActivityKit

struct FactDetailView: View {
    let item: FactCheckItem
    @Environment(\.presentationMode) var presentationMode

    private var hasRealThumbnail: Bool {
        guard let url = item.thumbnailURL else { return false }
        let s = url.absoluteString.lowercased()
        let isSocialPage = s.contains("instagram.com/reel") ||
                           s.contains("instagram.com/p/") ||
                           s.contains("tiktok.com/@") ||
                           s.contains("vm.tiktok.com") ||
                           (s.contains("instagram.com") && !s.contains("cdninstagram") && !s.contains("fbcdn")) ||
                           (s.contains("tiktok.com") && !s.contains("tiktokcdn") && !s.contains("muscdn")) ||
                           s.contains("youtube.com/shorts") ||
                           s.contains("youtu.be") ||
                           s.contains("threads.net") ||
                           s.contains("threads.com") ||
                           (s.contains("twitter.com") && !s.contains("pbs.twimg")) ||
                           (s.contains("x.com") && !s.contains("pbs.twimg"))
        return !isSocialPage
    }

    private var platform: String {
        detectedPlatformFromURL((item.originalLink ?? "").lowercased())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // MARK: Hero
                GeometryReader { geo in
                    Group {
                        if hasRealThumbnail, let url = item.thumbnailURL {
                            ThumbnailImage(url: url, platform: platform)
                        } else {
                            heroPlaceholder
                        }
                    }
                    .frame(width: geo.size.width, height: 300)
                    .clipped()
                    .overlay(
                        LinearGradient(
                            colors: [.black.opacity(0.4), .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                }
                .frame(height: 300)
            }

            // MARK: Content card
            VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {

                // Title + credibility badge + link preview
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    HStack {
                        Label(item.credibilityLevel.rawValue, systemImage: item.credibilityLevel.icon)
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.vertical, 6)
                            .padding(.horizontal, Theme.Spacing.md)
                            .background(item.credibilityLevel.color.opacity(0.1))
                            .foregroundColor(item.credibilityLevel.color)
                            .cornerRadius(Theme.CornerRadius.sm)

                        Spacer()

                        Text(item.timeAgo)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text(item.title)
                        .font(.system(size: 26, weight: .bold, design: .serif))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    LinkPreviewView(item: item)
                }

                Divider()

                // Credibility donut — averaged across all claims
                DonutChart(score: item.averageCredibilityScore, color: item.averageCredibilityLevel.color)
                    .frame(maxWidth: .infinity)

                // AI Detection — shown here, right after the chart
                if !isTextOnlyPlatform(platform) || item.aiGenerated != nil {
                    aiDetectionCard
                }

                Divider()

                // Multi-claim swipe hint — shown before the pager so users see it immediately
                if item.claims.count > 1 {
                    swipeHintBanner
                }

                // Claims pager — swipeable when 2-3 claims are present
                ClaimsPagerView(claims: item.claims)
            }
            .padding(Theme.Spacing.xl)
            .background(Color.backgroundLight)
            .cornerRadius(30)
            .offset(y: -40)
            .padding(.bottom, 40)
        }
        .edgesIgnoringSafeArea(.top)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { Text("") }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    HapticManager.lightImpact()
                    let shareURL: URL? = {
                        if let rid = item.reelID {
                            return URL(string: Config.Endpoints.shareBase + rid)
                        }
                        return item.originalLink.flatMap { URL(string: $0) }
                    }()
                    let items: [Any] = shareURL != nil ? [shareURL!] : [item.title]
                    let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let rootVC = windowScene.windows.first?.rootViewController {
                        if let popover = activityVC.popoverPresentationController {
                            popover.sourceView = rootVC.view
                            popover.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
                            popover.permittedArrowDirections = []
                        }
                        rootVC.present(activityVC, animated: true)
                    }
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 34, height: 34)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        // Swipe right anywhere outside the claims pager to go back
        .gesture(
            DragGesture(minimumDistance: 30, coordinateSpace: .local)
                .onEnded { value in
                    let isRightSwipe = value.translation.width > 80
                        && abs(value.translation.height) < 80
                    if isRightSwipe {
                        HapticManager.lightImpact()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
        )
        .onAppear {
            // Dismiss any completed Live Activities now that the user is
            // actually viewing their result. This is the only correct place
            // to dismiss — earlier hooks (tab switch, My Reels onAppear) all
            // fire before the user has seen anything.
            if #available(iOS 16.1, *) {
                Task {
                    for activity in Activity<ReelProcessingActivityAttributes>.activities
                    where activity.content.state.status == .completed
                       || activity.content.state.status == .failed {
                        await activity.end(
                            ActivityContent(state: activity.content.state, staleDate: nil),
                            dismissalPolicy: .immediate
                        )
                    }
                }
            }
        }
    }

    // MARK: - Swipe Hint Banner

    private var swipeHintBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.draw.fill")
                .font(.system(size: 16))
                .foregroundColor(.brandBlue)

            VStack(alignment: .leading, spacing: 1) {
                Text("\(item.claims.count) claims fact-checked")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Text("Swipe left to see each one")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 4) {
                ForEach(0..<item.claims.count, id: \.self) { i in
                    Capsule()
                        .fill(item.claims[i].credibilityLevel.color)
                        .frame(width: 18, height: 5)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(Color.brandBlue.opacity(0.07))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .stroke(Color.brandBlue.opacity(0.2), lineWidth: 1)
        )
        .cornerRadius(Theme.CornerRadius.md)
    }

    // MARK: - AI Detection Card

    private var aiDetectionCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("AI Detection")
                .font(.headline)

            if let aiGen = item.aiGenerated {
                HStack(spacing: Theme.Spacing.md) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AI-Generated Content")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        HStack(spacing: 5) {
                            Image(systemName: aiGen == "true" ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(aiGen == "true" ? .orange : .brandGreen)
                            Text(aiGen == "true" ? "Yes" : "No")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(aiGen == "true" ? .orange : .brandGreen)
                        }
                    }

                    Spacer()

                    if let prob = item.aiProbability {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Confidence")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                            Text("\(Int(prob * 100))%")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(aiGen == "true" ? .orange : .brandGreen)
                        }
                    }
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "questionmark.circle.fill")
                        .foregroundColor(.secondary)
                    Text("AI detection was not performed for this content.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Color.orange.opacity(0.07))
        .cornerRadius(Theme.CornerRadius.md)
    }

    // MARK: - Hero Placeholder

    private var heroPlaceholder: some View {
        let info = platformInfo(for: platform)
        let gradientColors: [Color] = {
            switch platform.lowercased() {
            case "tiktok":
                return [Color(red:0.01,green:0.01,blue:0.01), Color(red:0.12,green:0.12,blue:0.12)]
            case "youtube_shorts":
                return [Color(red:0.86,green:0.07,blue:0.07), Color(red:0.60,green:0.04,blue:0.04)]
            case "threads":
                return [Color(red:0.08,green:0.08,blue:0.08), Color(red:0.22,green:0.22,blue:0.22)]
            case "twitter":
                return [Color(red:0.11,green:0.63,blue:0.95), Color(red:0.06,green:0.42,blue:0.72)]
            default:
                return [Color(red:0.83,green:0.12,blue:0.53), Color(red:0.40,green:0.05,blue:0.70)]
            }
        }()
        return ZStack {
            LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 10) {
                Image(systemName: info.icon)
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                Text(info.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
}
