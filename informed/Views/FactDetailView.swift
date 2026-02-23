//
//  FactDetailView.swift
//  informed
//
//  Detailed view for fact-check results
//

import SwiftUI
import SafariServices

struct FactDetailView: View {
    let item: FactCheckItem
    @Environment(\.presentationMode) var presentationMode
    @State private var showSafari = false
    
    private var hasRealThumbnail: Bool {
        guard let url = item.thumbnailURL else { return false }
        let s = url.absoluteString.lowercased()
        let isSocialPage = s.contains("instagram.com/reel") ||
                           s.contains("instagram.com/p/") ||
                           s.contains("tiktok.com/@") ||
                           s.contains("vm.tiktok.com") ||
                           (s.contains("instagram.com") && !s.contains("cdninstagram") && !s.contains("fbcdn")) ||
                           (s.contains("tiktok.com") && !s.contains("tiktokcdn") && !s.contains("muscdn"))
        return !isSocialPage
    }
    
    private var isTikTok: Bool {
        (item.originalLink ?? "").lowercased().contains("tiktok")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // Hero Section
                ZStack(alignment: .topLeading) {
                    GeometryReader { geo in
                        Group {
                            if hasRealThumbnail {
                                AsyncImage(url: item.thumbnailURL) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    default:
                                        heroPlaceholder
                                    }
                                }
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

                    // Top Bar: Back & Share
                    HStack {
                        Button(action: {
                            HapticManager.lightImpact()
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "arrow.left")
                                .foregroundColor(.white)
                                .padding(Theme.Spacing.md)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }

                        Spacer()

                        Button(action: {
                            HapticManager.lightImpact()
                            let activityVC = UIActivityViewController(
                                activityItems: [item.title, item.summary],
                                applicationActivities: nil
                            )
                            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let rootVC = windowScene.windows.first?.rootViewController {
                                rootVC.present(activityVC, animated: true)
                            }
                        }) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.white)
                                .padding(Theme.Spacing.md)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                    }
                    .padding(.top, 60)
                    .padding(.horizontal, Theme.Spacing.xl)
                }
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {

                // Title Area
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
                    
                    // Link Preview - Always show to display the video/content
                    LinkPreviewView(item: item)
                }

                Divider()

                // Animated Chart
                VStack(alignment: .center, spacing: 0) {
                    DonutChart(score: item.credibilityScore, color: item.credibilityLevel.color)
                }
                .frame(maxWidth: .infinity)

                // The Claim
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    Text("The Claim")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(item.factCheck.claim)
                        .font(.body)
                        .foregroundColor(.primary.opacity(0.8))
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Theme.Spacing.lg)
                .background(Color.blue.opacity(0.08))
                .cornerRadius(Theme.CornerRadius.md)

                // Verdict Badge
                HStack(spacing: Theme.Spacing.md) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Verdict")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        Text(item.factCheck.verdict)
                            .font(.system(size: 18, weight: .bold, design: .default))
                            .foregroundColor(item.credibilityLevel.color)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Accuracy Rating")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        Text(item.factCheck.claimAccuracyRating)
                            .font(.system(size: 18, weight: .bold, design: .default))
                            .foregroundColor(item.credibilityLevel.color)
                    }
                }
                .padding(Theme.Spacing.lg)
                .background(item.credibilityLevel.color.opacity(0.08))
                .cornerRadius(Theme.CornerRadius.md)

                // Summary
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    Text("Summary")
                        .font(.headline)
                    Text(item.factCheck.summary)
                        .font(.body)
                        .foregroundColor(.primary.opacity(0.8))
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Theme.Spacing.lg)
                .background(Color.green.opacity(0.08))
                .cornerRadius(Theme.CornerRadius.md)

                // Explanation
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    Text("Explanation")
                        .font(.headline)
                    
                    if !item.factCheck.explanation.isEmpty {
                        Text(item.factCheck.explanation)
                            .font(.body)
                            .foregroundColor(.primary.opacity(0.8))
                            .lineSpacing(6)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("No detailed explanation available for this fact check.")
                            .font(.body)
                            .foregroundColor(.gray.opacity(0.8))
                            .italic()
                    }
                }
                .padding(Theme.Spacing.lg)
                .background(Color.cardBackground)
                .cornerRadius(Theme.CornerRadius.md)

                // Sources
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    Text("Sources")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(item.factCheck.sources.indices, id: \.self) { index in
                            Button(action: {
                                HapticManager.lightImpact()
                                if let url = URL(string: item.factCheck.sources[index]) {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                HStack(spacing: Theme.Spacing.sm) {
                                    Image(systemName: "link.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(.brandBlue)

                                    Text(extractDomainName(from: item.factCheck.sources[index]))
                                        .font(.caption)
                                        .foregroundColor(.brandBlue)
                                        .lineLimit(1)

                                    Spacer()

                                    Image(systemName: "arrow.up.right")
                                        .font(.caption2)
                                        .foregroundColor(.brandBlue.opacity(0.6))
                                }
                                .padding(.vertical, Theme.Spacing.sm)
                                .padding(.horizontal, Theme.Spacing.md)
                                .background(Color.brandBlue.opacity(0.05))
                                .cornerRadius(Theme.CornerRadius.sm)
                            }
                        }
                    }
                }
                .padding(Theme.Spacing.lg)
                .background(Color.cardBackground)
                .cornerRadius(Theme.CornerRadius.md)
            }
            .padding(Theme.Spacing.xl)
            .background(Color.backgroundLight)
            .cornerRadius(30)
            .offset(y: -40)
            .padding(.bottom, 40)
        }
        .edgesIgnoringSafeArea(.top)
        .navigationBarHidden(true)
    }
    
    // MARK: - Hero Placeholder
    
    private var heroPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: isTikTok
                    ? [Color(red:0.01,green:0.01,blue:0.01), Color(red:0.12,green:0.12,blue:0.12)]
                    : [Color(red:0.83,green:0.12,blue:0.53), Color(red:0.40,green:0.05,blue:0.70)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 10) {
                Image(systemName: isTikTok ? "music.note" : "camera.fill")
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                Text(isTikTok ? "TikTok" : "Instagram")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
}
