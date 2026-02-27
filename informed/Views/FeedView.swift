//
//  FeedView.swift
//  informed
//
//  Displays public feed of reels from all users with infinite scroll
//

import SwiftUI

struct FeedView: View {
    @EnvironmentObject private var viewModel: FeedViewModel
    @EnvironmentObject var userManager: UserManager
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.backgroundLight.ignoresSafeArea()
                
                if viewModel.isLoading && viewModel.publicReels.isEmpty {
                    // Initial loading state
                    loadingView
                } else if let errorMessage = viewModel.errorMessage, viewModel.publicReels.isEmpty {
                    // Error state
                    errorView(message: errorMessage)
                } else if viewModel.publicReels.isEmpty {
                    // Empty state
                    emptyStateView
                } else {
                    // Feed content with infinite scroll
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.publicReels) { reel in
                                PublicReelCard(reel: reel, viewModel: viewModel)
                                    .onAppear {
                                        // Load more when reaching the last few items
                                        if reel.id == viewModel.publicReels.last?.id {
                                            Task {
                                                await viewModel.loadMoreReels()
                                            }
                                        }
                                    }
                            }
                            
                            // Loading more indicator
                            if viewModel.isLoadingMore {
                                ProgressView()
                                    .padding()
                            }
                            
                            // End of feed message
                            if !viewModel.hasMore && !viewModel.publicReels.isEmpty {
                                Text("You're all caught up!")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .padding()
                            }
                        }
                        .padding()
                    }
                    .refreshable {
                        await viewModel.refresh()
                    }
                }
            }
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.large)
            .onChange(of: userManager.isAuthenticated) { _, isAuthenticated in
                if isAuthenticated && viewModel.publicReels.isEmpty {
                    Task { await viewModel.loadFeed() }
                }
            }
            .onChange(of: userManager.currentSessionId) { _, sessionId in
                // Session ID arrived after initial load (e.g. Keychain read was delayed)
                if sessionId != nil && viewModel.errorMessage != nil {
                    Task { await viewModel.loadFeed() }
                }
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading feed...")
                .font(.body)
                .foregroundColor(.gray)
        }
    }
    
    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))

            Text("Nothing Here Yet")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            Text("The Discover feed fills up as people fact-check reels. Check back soon!")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)

            Button {
                Task {
                    await viewModel.loadFeed()
                }
            } label: {
                Text("Refresh")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [.brandTeal, .brandBlue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
            }
        }
        .padding()
    }
    
    // MARK: - Error View
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: message.contains("Session expired") ? "person.crop.circle.badge.exclamationmark" : "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.brandRed.opacity(0.7))
            
            Text(message.contains("Session expired") ? "Session Expired" : "Oops!")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(message)
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                // Show logout button if session expired
                if message.contains("Session expired") || message.contains("log out and log back in") {
                    Button {
                        userManager.logout()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.right.square")
                            Text("Log Out & Log In Again")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.brandRed)
                        .cornerRadius(12)
                    }
                }
                
                // Regular try again button
                Button {
                    Task {
                        await viewModel.loadFeed()
                    }
                } label: {
                    Text("Try Again")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [.brandTeal, .brandBlue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                }
            }
        }
        .padding()
    }
}

// MARK: - Public Reel Card

struct PublicReelCard: View {
    let reel: PublicReel
    let viewModel: FeedViewModel
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationLink(destination: PublicReelDetailView(reel: reel, viewModel: viewModel)) {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                // Header - match FactResultCard format with platform-specific icon
                HStack {
                    Image(systemName: reel.platformIcon)
                        .foregroundColor(.brandBlue)
                        .padding(Theme.Spacing.sm)
                        .background(Color.brandBlue.opacity(0.1))
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading) {
                        Text("Verified by AI + Humans")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        Text(reel.timeAgo)
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.5))
                }
                
                // Link Preview - match Home format exactly
                LinkPreviewView(item: reel.toFactCheckItem())
                
                // Claim text
                Text(reel.claims.first?.claim ?? reel.summary)
                    .font(.system(size: 15))
                    .foregroundColor(.primary.opacity(0.8))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                
                // Credibility section - match FactResultCard format
                HStack {
                    Text("Credibility:")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: reel.averageCredibilityLevel.icon)
                        Text(reel.averageCredibilityLevel.rawValue)
                    }
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(reel.averageCredibilityLevel.color)
                }
                
                // Mini progress bar - match FactResultCard format
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.secondary.opacity(0.2))
                        Capsule()
                            .fill(reel.averageCredibilityLevel.color)
                            .frame(width: geo.size.width * reel.averageCredibilityScore)
                    }
                }
                .frame(height: 6)
                
                // AI Generation Badge (only show when flagged and AI detection applies)
                if reel.aiGenerated == "true" && !isTextOnlyPlatform(reel.detectedPlatform) {
                    HStack(spacing: 5) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Possibly AI-generated")
                            .font(.system(size: 12, weight: .semibold))
                        if let prob = reel.aiProbability {
                            Text("(\(Int(prob * 100))%)")
                                .font(.system(size: 11))
                        }
                    }
                    .foregroundColor(Color.orange)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(Capsule())
                }
            }
            .padding(Theme.Spacing.xl)
            .background(Color.cardBackground)
            .cornerRadius(Theme.CornerRadius.xl)
            .shadow(
                color: Theme.Shadow.card(for: colorScheme),
                radius: Theme.Shadow.lg,
                x: 0,
                y: 8
            )
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(TapGesture().onEnded {
            Task {
                await viewModel.trackView(for: reel)
            }
        })
    }
}
// MARK: - Public Reel Detail View

struct PublicReelDetailView: View {
    let reel: PublicReel
    // viewModel kept for backward compat with FeedView callers but no longer required
    var viewModel: FeedViewModel? = nil
    
    @Environment(\.presentationMode) var presentationMode
    
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
                Button(action: {
                    HapticManager.lightImpact()
                    if let viewModel = viewModel { Task { await viewModel.trackShare(for: reel) } }
                    let shareURL = URL(string: Config.Endpoints.shareBase + reel.id)
                        ?? URL(string: reel.videoLink)
                    let items: [Any] = shareURL != nil ? [shareURL!] : [reel.title]
                    let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let rootVC = windowScene.windows.first?.rootViewController {
                        rootVC.present(activityVC, animated: true)
                    }
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

// MARK: - Preview

struct FeedView_Previews: PreviewProvider {
    static var previews: some View {
        FeedView()
            .environmentObject(UserManager())
    }
}
