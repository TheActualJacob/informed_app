//
//  FeedView.swift
//  informed
//
//  Displays public feed of reels from all users with infinite scroll
//

import SwiftUI

struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
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
            Image(systemName: "server.rack")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("Backend Not Ready")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("The public feed requires backend endpoints.\n\nShare BACKEND_URGENT_FIX.md with your backend team.")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            Button {
                Task {
                    await viewModel.loadFeed()
                }
            } label: {
                Text("Try Loading Feed")
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
                // Header - match FactResultCard format
                HStack {
                    Image(systemName: "camera.fill")
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
                
                // Summary text
                Text(reel.summary)
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
                        Image(systemName: reel.credibilityLevel.icon)
                        Text(reel.credibilityLevel.rawValue)
                    }
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(reel.credibilityLevel.color)
                }
                
                // Mini progress bar - match FactResultCard format
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.secondary.opacity(0.2))
                        Capsule()
                            .fill(reel.credibilityLevel.color)
                            .frame(width: geo.size.width * reel.credibilityScore)
                    }
                }
                .frame(height: 6)
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
    let viewModel: FeedViewModel
    
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
                
                // Title Area
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    HStack {
                        Label(reel.credibilityLevel.rawValue, systemImage: reel.credibilityLevel.icon)
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.vertical, 6)
                            .padding(.horizontal, Theme.Spacing.md)
                            .background(reel.credibilityLevel.color.opacity(0.1))
                            .foregroundColor(reel.credibilityLevel.color)
                            .cornerRadius(Theme.CornerRadius.sm)
                        
                        Spacer()
                        
                        Text(reel.timeAgo)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(reel.title)
                        .font(.system(size: 26, weight: .bold, design: .serif))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Link Preview - Always show to display the video/content (matching Home format)
                    LinkPreviewView(item: reel.toFactCheckItem())
                    
                    // User attribution
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.brandBlue)
                        Text("Shared by \(reel.uploadedBy.username)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                // Animated Chart
                VStack(alignment: .center, spacing: 0) {
                    DonutChart(score: reel.credibilityScore, color: reel.credibilityLevel.color)
                }
                .frame(maxWidth: .infinity)
                
                // The Claim
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    Text("The Claim")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(reel.claim)
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
                        Text(reel.verdict)
                            .font(.system(size: 18, weight: .bold, design: .default))
                            .foregroundColor(reel.credibilityLevel.color)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Accuracy Rating")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        Text(reel.claimAccuracyRating)
                            .font(.system(size: 18, weight: .bold, design: .default))
                            .foregroundColor(reel.credibilityLevel.color)
                    }
                }
                .padding(Theme.Spacing.lg)
                .background(reel.credibilityLevel.color.opacity(0.08))
                .cornerRadius(Theme.CornerRadius.md)
                
                // Summary
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    Text("Summary")
                        .font(.headline)
                    Text(reel.summary)
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
                    
                    if !reel.explanation.isEmpty {
                        Text(reel.explanation)
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
                if !reel.sources.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        Text("Sources")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(reel.sources.indices, id: \.self) { index in
                                Button(action: {
                                    HapticManager.lightImpact()
                                    if let url = URL(string: reel.sources[index]) {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "link")
                                            .foregroundColor(.brandBlue)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            if let url = URL(string: reel.sources[index]), let host = url.host {
                                                Text(host.replacingOccurrences(of: "www.", with: ""))
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)
                                                    .foregroundColor(.brandBlue)
                                            } else {
                                                Text("Source \(index + 1)")
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)
                                                    .foregroundColor(.brandBlue)
                                            }
                                            
                                            Text(reel.sources[index])
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                                .lineLimit(1)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "arrow.up.right")
                                            .font(.caption)
                                            .foregroundColor(.brandBlue.opacity(0.7))
                                    }
                                    .padding(Theme.Spacing.md)
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
                
                // Share Button
                Button(action: {
                    HapticManager.lightImpact()
                    Task {
                        await viewModel.trackShare(for: reel)
                    }
                    if let url = URL(string: reel.videoLink) {
                        let activityVC = UIActivityViewController(
                            activityItems: [url],
                            applicationActivities: nil
                        )
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let rootVC = windowScene.windows.first?.rootViewController {
                            rootVC.present(activityVC, animated: true)
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share This Fact Check")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [.brandTeal, .brandBlue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(Theme.CornerRadius.md)
                }
            }
            .padding(Theme.Spacing.xl)
        }
        .background(Color.backgroundLight)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("")
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
