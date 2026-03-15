//
//  FeedView.swift
//  informed
//
//  News feed — published editorial story walkthroughs
//

import SwiftUI

// MARK: - Feed View

struct FeedView: View {
    @EnvironmentObject private var viewModel: FeedViewModel
    @EnvironmentObject var userManager: UserManager

    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()

                if viewModel.isLoading && viewModel.stories.isEmpty {
                    loadingView
                } else if let errorMessage = viewModel.errorMessage,
                          viewModel.stories.isEmpty {
                    errorView(message: errorMessage)
                } else if viewModel.stories.isEmpty {
                    emptyStateView
                } else {
                    mainFeed
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: userManager.isAuthenticated) { _, isAuthenticated in
                if isAuthenticated && viewModel.stories.isEmpty {
                    Task { await viewModel.loadFeed() }
                }
            }
            .onChange(of: userManager.currentSessionId) { _, sessionId in
                if sessionId != nil && viewModel.errorMessage != nil {
                    Task { await viewModel.loadFeed() }
                }
            }
        }
    }

    // MARK: - Main Feed

    private var mainFeed: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                // Published stories — full-screen swipe cards
                ForEach(Array(viewModel.stories.enumerated()), id: \.element.id) { _, story in
                    StoryCardView(story: story)
                        .containerRelativeFrame(.vertical)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .refreshable {
            await viewModel.refresh()
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.brandTeal)
            Text("Loading news...")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "newspaper")
                .font(.system(size: 56))
                .foregroundStyle(.secondary.opacity(0.4))

            Text("No Stories Yet")
                .font(.system(size: 22, weight: .bold))

            Text("Curated walkthroughs appear here as editors publish them.")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                Task { await viewModel.loadFeed() }
            } label: {
                Text("Refresh")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(colors: [.brandTeal, .brandBlue],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: message.contains("Session expired")
                  ? "person.crop.circle.badge.exclamationmark"
                  : "exclamationmark.triangle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.brandRed.opacity(0.7))

            Text(message.contains("Session expired") ? "Session Expired" : "Something Went Wrong")
                .font(.system(size: 22, weight: .bold))

            Text(message)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(spacing: 12) {
                if message.contains("Session expired") || message.contains("log out") {
                    Button {
                        userManager.logout()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.right.square")
                            Text("Log Out & Log In Again")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.brandRed)
                        .clipShape(Capsule())
                    }
                }

                Button {
                    Task { await viewModel.loadFeed() }
                } label: {
                    Text("Try Again")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(colors: [.brandTeal, .brandBlue],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(Capsule())
                }
            }
        }
    }
}

// MARK: - Story Card (Full-Screen Cover)

struct StoryCardView: View {
    let story: Story

    private var accentColor: Color {
        switch story.category?.lowercased() {
        case "politics", "politics & government": return .brandBlue
        case "health", "health & medicine": return .brandGreen
        case "technology": return .brandTeal
        case "conflict", "military": return .brandRed
        default: return .brandBlue
        }
    }

    var body: some View {
        GeometryReader { geo in
            NavigationLink(destination: StoryWalkthroughView(story: story)) {
                ZStack(alignment: .bottom) {
                    // Cover image or gradient background
                    if let urlStr = story.coverImageUrl, let url = URL(string: urlStr) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: geo.size.width, height: geo.size.height)
                                    .clipped()
                            default:
                                gradientBackground(geo: geo)
                            }
                        }
                    } else {
                        gradientBackground(geo: geo)
                    }

                    // Bottom text overlay with gradient scrim
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.3), .black.opacity(0.85)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: geo.size.height * 0.55)

                    // Content
                    VStack(alignment: .leading, spacing: 12) {
                        Spacer()

                        // Category pill
                        if let cat = story.category {
                            Text(cat.uppercased())
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(accentColor)
                                .clipShape(Capsule())
                        }

                        // Headline
                        Text(story.headline)
                            .font(.system(size: 28, weight: .bold, design: .serif))
                            .foregroundStyle(.white)
                            .lineLimit(4)
                            .shadow(color: .black.opacity(0.3), radius: 4, y: 2)

                        // Summary
                        if let summary = story.summary, !summary.isEmpty {
                            Text(summary)
                                .font(.system(size: 15))
                                .foregroundStyle(.white.opacity(0.85))
                                .lineLimit(3)
                                .lineSpacing(2)
                        }

                        // Author + block count
                        HStack {
                            if let author = story.author {
                                Text("By \(author)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            Spacer()
                            HStack(spacing: 4) {
                                Text("Read walkthrough")
                                    .font(.system(size: 13, weight: .semibold))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundStyle(.white.opacity(0.9))
                        }
                    }
                    .padding(24)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private func gradientBackground(geo: GeometryProxy) -> some View {
        LinearGradient(
            colors: [accentColor.opacity(0.15), accentColor.opacity(0.4)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .frame(width: geo.size.width, height: geo.size.height)
    }
}

// MARK: - Story Walkthrough (Full Detail)

struct StoryWalkthroughView: View {
    let story: Story
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Hero header
                storyHeader

                // Blocks
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(story.blocks) { block in
                        storyBlockView(block)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 48)
            }
        }
        .background(Color(UIColor.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    // MARK: Header

    private var storyHeader: some View {
        ZStack(alignment: .bottomLeading) {
            if let urlStr = story.coverImageUrl, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 320)
                            .clipped()
                    default:
                        Rectangle()
                            .fill(Color.brandBlue.opacity(0.15))
                            .frame(height: 320)
                    }
                }
            } else {
                Rectangle()
                    .fill(
                        LinearGradient(colors: [.brandTeal.opacity(0.2), .brandBlue.opacity(0.3)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(height: 320)
            }

            // Gradient scrim
            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .center,
                endPoint: .bottom
            )
            .frame(height: 320)

            // Title overlay
            VStack(alignment: .leading, spacing: 8) {
                if let cat = story.category {
                    Text(cat.uppercased())
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.brandBlue)
                        .clipShape(Capsule())
                }

                Text(story.headline)
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundStyle(.white)

                HStack(spacing: 12) {
                    if let author = story.author {
                        Label(author, systemImage: "person.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    Text(story.formattedDate)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(20)
        }
    }

    // MARK: Block Renderer

    @ViewBuilder
    private func storyBlockView(_ block: StoryBlock) -> some View {
        switch block.type {
        case .heading:
            Text(block.text ?? "")
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundStyle(.primary)
                .padding(.top, 8)

        case .text:
            Text(block.attributedText)
                .font(.system(size: 16))
                .foregroundStyle(.primary.opacity(0.85))
                .lineSpacing(5)

        case .image:
            VStack(alignment: .leading, spacing: 6) {
                if let urlStr = block.imageUrl, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(maxWidth: .infinity)
                                .frame(height: 220)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.md))
                        default:
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                                .fill(Color.secondary.opacity(0.08))
                                .frame(height: 220)
                                .overlay(ProgressView())
                        }
                    }
                }
                if let caption = block.caption, !caption.isEmpty {
                    Text(caption)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .italic()
                }
            }

        case .factCheck:
            if let reel = block.factCheck {
                NavigationLink(destination: PublicReelDetailView(reel: reel)) {
                    EmbeddedFactCheckCard(reel: reel)
                }
                .buttonStyle(PlainButtonStyle())
            }

        case .editorNote:
            HStack(alignment: .top, spacing: 12) {
                Rectangle()
                    .fill(Color.brandBlue)
                    .frame(width: 3)

                VStack(alignment: .leading, spacing: 4) {
                    Text("EDITOR'S NOTE")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.brandBlue)
                    Text(block.attributedText)
                        .font(.system(size: 15))
                        .foregroundStyle(.primary.opacity(0.85))
                        .lineSpacing(3)
                        .italic()
                }
            }
            .padding(16)
            .background(Color.brandBlue.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.md))

        case .inDepth:
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.indigo)
                    Text("IN-DEPTH")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.indigo)
                }
                Text(block.attributedText)
                    .font(.system(size: 16))
                    .foregroundStyle(.primary.opacity(0.88))
                    .lineSpacing(5)
            }
            .padding(16)
            .background(Color.indigo.opacity(0.07))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                    .strokeBorder(Color.indigo.opacity(0.20), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.md))
        }
    }
}

// MARK: - Embedded Fact-Check Card

struct EmbeddedFactCheckCard: View {
    let reel: PublicReel

    private var verdictColor: Color { reel.averageCredibilityLevel.color }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(verdictColor)
                Text("FACT-CHECK")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(verdictColor)
                Spacer()
                Image(systemName: reel.platformIcon)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(reel.platformDisplayName)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            // Thumbnail + claim
            HStack(alignment: .top, spacing: 12) {
                if let thumb = reel.thumbnailUrl, let url = URL(string: thumb) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 72, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        default:
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.secondary.opacity(0.1))
                                .frame(width: 72, height: 72)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(reel.claims.first?.claim ?? reel.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(3)

                    Text(reel.claims.first?.summary ?? reel.description)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            // Verdict bar
            HStack(spacing: 8) {
                Image(systemName: reel.averageCredibilityLevel.icon)
                    .font(.system(size: 14, weight: .bold))
                Text(reel.averageCredibilityLevel.rawValue.uppercased())
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                Spacer()
                Text("\(Int(reel.averageCredibilityScore * 100))%")
                    .font(.system(size: 20, weight: .black, design: .rounded))
            }
            .foregroundStyle(verdictColor)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(verdictColor.opacity(0.12))
                    Capsule()
                        .fill(verdictColor)
                        .frame(width: geo.size.width * reel.averageCredibilityScore)
                }
            }
            .frame(height: 5)

            // Tap hint
            HStack {
                Spacer()
                HStack(spacing: 4) {
                    Text("Full analysis")
                        .font(.system(size: 12, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(verdictColor)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                .stroke(verdictColor.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Story Date Formatting

extension Story {
    var formattedDate: String {
        let f = ISO8601DateFormatter()
        if let d = f.date(from: publishedAt) {
            let df = DateFormatter()
            df.dateStyle = .medium
            return df.string(from: d)
        }
        return publishedAt
    }
}

// MARK: - Public Reel Detail View

struct PublicReelDetailView: View {
    let reel: PublicReel

    @EnvironmentObject var userManager: UserManager
    @Environment(\.presentationMode) var presentationMode
    @State private var showReportSheet = false
    @State private var reportSubmitted = false
    @State private var reportError: String?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {

                // Title + credibility badge + link preview + attribution
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    HStack {
                        Label(reel.averageCredibilityLevel.rawValue, systemImage: reel.averageCredibilityLevel.icon)
                            .font(.caption).fontWeight(.bold)
                            .padding(.vertical, 6).padding(.horizontal, Theme.Spacing.md)
                            .background(reel.averageCredibilityLevel.color.opacity(0.1))
                            .foregroundColor(reel.averageCredibilityLevel.color)
                            .cornerRadius(Theme.CornerRadius.sm)
                        Spacer()
                        Text(reel.timeAgo).font(.caption).foregroundColor(.secondary)
                    }

                    Text(reel.title)
                        .font(.system(size: 26, weight: .bold, design: .serif))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    LinkPreviewView(item: reel.toFactCheckItem())

                    HStack {
                        Image(systemName: "person.circle.fill").foregroundColor(.brandBlue)
                        Text("Shared by \(reel.uploadedBy.username)")
                            .font(.subheadline).foregroundColor(.secondary)
                    }
                }

                Divider()

                // Credibility donut — averaged across all claims
                DonutChart(score: reel.averageCredibilityScore, color: reel.averageCredibilityLevel.color)
                    .frame(maxWidth: .infinity)

                // AI Detection — right after the chart
                if !isTextOnlyPlatform(reel.detectedPlatform) || reel.aiGenerated != nil {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        Text("AI Detection").font(.headline)
                        if let aiGen = reel.aiGenerated {
                            HStack(spacing: Theme.Spacing.md) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("AI-Generated Video")
                                        .font(.caption).fontWeight(.bold).foregroundColor(.secondary)
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
                                if let prob = reel.aiProbability {
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text("Confidence")
                                            .font(.caption).fontWeight(.bold).foregroundColor(.secondary)
                                        Text("\(Int(prob * 100))%")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(aiGen == "true" ? .orange : .brandGreen)
                                    }
                                }
                            }
                        } else {
                            HStack(spacing: 8) {
                                Image(systemName: "questionmark.circle.fill").foregroundColor(.secondary)
                                Text("AI detection was not performed for this content.")
                                    .font(.body).foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(Theme.Spacing.lg)
                    .background(Color.orange.opacity(0.07))
                    .cornerRadius(Theme.CornerRadius.md)
                }

                Divider()

                // Multi-claim swipe hint
                if reel.claims.count > 1 {
                    HStack(spacing: 10) {
                        Image(systemName: "hand.draw.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.brandBlue)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(reel.claims.count) claims fact-checked")
                                .font(.caption).fontWeight(.bold).foregroundColor(.primary)
                            Text("Swipe left to see each one")
                                .font(.caption2).foregroundColor(.secondary)
                        }
                        Spacer()
                        HStack(spacing: 4) {
                            ForEach(0..<reel.claims.count, id: \.self) { i in
                                Capsule()
                                    .fill(reel.claims[i].credibilityLevel.color)
                                    .frame(width: 18, height: 5)
                            }
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    .padding(.vertical, 10).padding(.horizontal, 14)
                    .background(Color.brandBlue.opacity(0.07))
                    .overlay(RoundedRectangle(cornerRadius: Theme.CornerRadius.md).stroke(Color.brandBlue.opacity(0.2), lineWidth: 1))
                    .cornerRadius(Theme.CornerRadius.md)
                }

                // Claims pager — swipeable when 2-3 claims present
                ClaimsPagerView(claims: reel.claims)
            }
            .padding(Theme.Spacing.xl)
        }
        .background(Color.backgroundLight)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { Text("") }
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button(action: {
                        HapticManager.lightImpact()
                        showReportSheet = true
                    }) {
                        Image(systemName: "flag")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    Button(action: {
                        HapticManager.lightImpact()
                        let shareURL = URL(string: Config.Endpoints.shareBase + reel.id)
                            ?? URL(string: reel.videoLink)
                        let items: [Any] = shareURL != nil ? [shareURL!] : [reel.title]
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
                    }
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .confirmationDialog("Content Actions", isPresented: $showReportSheet, titleVisibility: .visible) {
            Button("Report: Inappropriate or harmful") {
                submitReport(reason: "inappropriate")
            }
            Button("Report: Misinformation") {
                submitReport(reason: "misinformation")
            }
            Button("Report: Spam") {
                submitReport(reason: "spam")
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("What would you like to do with this content?")
        }
        .alert(reportSubmitted ? "Report Submitted" : "Report Failed",
               isPresented: Binding(
                   get: { reportSubmitted || reportError != nil },
                   set: { if !$0 { reportSubmitted = false; reportError = nil } }
               )) {
            Button("OK", role: .cancel) {
                reportSubmitted = false
                reportError = nil
            }
        } message: {
            if reportSubmitted {
                Text("Thanks for the report. Our team will review this content.")
            } else if let error = reportError {
                Text(error)
            }
        }
    }

    private func submitReport(reason: String) {
        guard let userId = userManager.currentUserId,
              let sessionId = userManager.currentSessionId else { return }
        Task {
            do {
                try await NetworkService.shared.reportContent(
                    userId: userId,
                    sessionId: sessionId,
                    factCheckId: reel.id,
                    reason: reason
                )
                reportSubmitted = true
            } catch {
                reportError = "Could not submit report. Please try again."
            }
        }
    }
}

// MARK: - Preview

struct FeedView_Previews: PreviewProvider {
    static var previews: some View {
        FeedView()
            .environmentObject(UserManager())
    }
}
