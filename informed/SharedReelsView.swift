//
//  SharedReelsView.swift
//  informed
//
//  Displays a list of shared Instagram reels and their fact-checking status

import ActivityKit
//

import SwiftUI

struct SharedReelsView: View {
    @EnvironmentObject var reelManager: SharedReelManager
    @EnvironmentObject var userManager: UserManager

    // Deep-link: set by ContentView when user taps a completed Live Activity
    @State private var deepLinkItem: FactCheckItem? = nil
    @State private var showDeepLink = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.backgroundLight.ignoresSafeArea()

                // Hidden NavigationLink — fired programmatically by deep-link
                if let item = deepLinkItem {
                    NavigationLink(
                        destination: FactDetailView(item: item),
                        isActive: $showDeepLink
                    ) { EmptyView() }
                    .opacity(0)
                    .frame(width: 0, height: 0)
                }

                if reelManager.reels.isEmpty && !reelManager.isSyncing {
                    emptyStateView
                } else if reelManager.isSyncing && reelManager.reels.isEmpty {
                    syncingView
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Sync status banner
                            if let lastSync = reelManager.lastSyncDate {
                                HStack {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .foregroundColor(.brandGreen)
                                    
                                    Text("Last synced \(timeAgo(from: lastSync))")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.top, 8)
                            }
                            
                            ForEach(reelManager.reels) { reel in
                                ReelStatusCard(reel: reel)
                                    .id(reel.id)
                            }
                        }
                        .padding()
                    }
                    .refreshable {
                        await reelManager.syncHistoryFromBackend()
                    }
                }
            }
            .navigationTitle("Shared Reels")
            .navigationBarTitleDisplayMode(.large)
            .onChange(of: reelManager.pendingDeepLinkItem) { _, item in
                guard let item else { return }
                deepLinkItem = item
                reelManager.pendingDeepLinkItem = nil
                // Small delay so the NavigationLink has time to mount
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    showDeepLink = true
                }
            }
            .onAppear {
                // Handle deep-link that arrived before this view was mounted
                if let item = reelManager.pendingDeepLinkItem {
                    deepLinkItem = item
                    reelManager.pendingDeepLinkItem = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showDeepLink = true
                    }
                }

                // Auto-sync from backend when view appears so new completions show up
                Task {
                    await reelManager.syncHistoryFromBackend()
                }

                // Dismiss any completed Live Activities since user is now viewing the results
                if #available(iOS 16.1, *) {
                    Task {
                        print("🎬 User opened My Reels tab - dismissing completed Live Activities")
                        await dismissCompletedActivities()
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !reelManager.reels.isEmpty {
                        Menu {
                            Button(role: .destructive) {
                                withAnimation {
                                    reelManager.clearAllReels()
                                }
                            } label: {
                                Label("Clear All", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                                .foregroundColor(.brandBlue)
                        }
                    }
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No Shared Content")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("Share Instagram Reels or TikTok videos\nto this app to start fact-checking them")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding()
        .onAppear {
            // Auto-sync from backend when empty state appears
            Task {
                await reelManager.syncHistoryFromBackend()
            }
        }
    }
    
    private var syncingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Syncing your reels...")
                .font(.body)
                .foregroundColor(.gray)
        }
    }
    
    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    @available(iOS 16.1, *)
    private func dismissCompletedActivities() async {
        let terminalIds = reelManager.reels
            .filter { $0.status == .completed || $0.status == .failed }
            .map { $0.id }
        for submissionId in terminalIds {
            await ReelProcessingActivityManager.shared.endActivity(
                submissionId: submissionId,
                dismissalPolicy: .immediate
            )
        }
    }
}

struct ReelStatusCard: View {
    let reel: SharedReel
    
    @Environment(\.colorScheme) var colorScheme
    @State private var showDetail = false
    
    var body: some View {
        ZStack {
            // Hidden NavigationLink
            if reel.status == .completed, let factCheckData = reel.factCheckData {
                NavigationLink(
                    destination: FactDetailView(item: factCheckData.toFactCheckItem(originalLink: reel.url)),
                    isActive: $showDetail
                ) {
                    EmptyView()
                }
                .opacity(0)
                .frame(width: 0, height: 0)
            }
            
            // Visible card content
            if reel.status == .completed {
                Button(action: {
                    showDetail = true
                }) {
                    cardContent
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                cardContent
            }
        }
    }
    
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Show fact check card matching Home format for completed reels
            if reel.status == .completed, let factCheckData = reel.factCheckData {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    // Header - match FactResultCard format with platform-specific icon
                    HStack {
                        Image(systemName: reel.detectedPlatform == "tiktok" ? "music.note" : reel.detectedPlatform == "tiktok" ? "music.note" : reel.detectedPlatform == "tiktok" ? "music.note" : reel.detectedPlatform == "tiktok" ? "music.note" : "camera.fill")
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
                    LinkPreviewView(item: factCheckData.toFactCheckItem(originalLink: reel.url))
                    
                    // Summary text
                    Text(factCheckData.summary)
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
                        
                        let credibilityScore: Double = {
                            let s = factCheckData.claimAccuracyRating.replacingOccurrences(of: "%", with: "")
                            return Double(s).map { $0 / 100.0 } ?? 0.5
                        }()
                        let credibilityLevel: CredibilityLevel = {
                            if credibilityScore >= 0.8 { return .high }
                            if credibilityScore >= 0.5 { return .medium }
                            return .low
                        }()
                        
                        HStack(spacing: 4) {
                            Image(systemName: credibilityLevel.icon)
                            Text(credibilityLevel.rawValue)
                        }
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(credibilityLevel.color)
                    }
                    
                    // Mini progress bar - match FactResultCard format
                    GeometryReader { geo in
                        let credibilityScore: Double = {
                            let s = factCheckData.claimAccuracyRating.replacingOccurrences(of: "%", with: "")
                            return Double(s).map { $0 / 100.0 } ?? 0.5
                        }()
                        let credibilityLevel: CredibilityLevel = {
                            if credibilityScore >= 0.8 { return .high }
                            if credibilityScore >= 0.5 { return .medium }
                            return .low
                        }()
                        
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.secondary.opacity(0.2))
                            Capsule()
                                .fill(credibilityLevel.color)
                                .frame(width: geo.size.width * credibilityScore)
                        }
                    }
                    .frame(height: 6)
                    
                    // AI Generation Badge (only show when flagged)
                    if factCheckData.aiGenerated == "true" {
                        HStack(spacing: 5) {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Possibly AI-generated")
                                .font(.system(size: 12, weight: .semibold))
                            if let prob = factCheckData.aiProbability {
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
                
            } else {
                // Show status-based card for non-completed reels
                VStack(alignment: .leading, spacing: 12) {
                    // Header with status
                    HStack {
                        Image(systemName: reel.status.icon)
                            .font(.title3)
                            .foregroundColor(reel.status.color)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(reel.status.rawValue)
                                .font(.headline)
                                .foregroundColor(reel.status.color)
                            
                            Text(reel.timeAgo)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        if reel.status == .processing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .brandBlue))
                        }
                    }
                    
                    Divider()
                    
                    if reel.status != .completed {
                        // Show URL for non-completed reels
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Instagram URL")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.gray)
                            
                            Text(reel.displayURL)
                                .font(.footnote)
                                .foregroundColor(.primary)
                                .lineLimit(2)
                        }
                    }
                    
                    // Error message if failed
                    if let errorMessage = reel.errorMessage, reel.status == .failed {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.brandRed)
                                    .font(.caption)
                                
                                Text("Error")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.brandRed)
                            }
                            
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(8)
                        .background(Color.brandRed.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding(Theme.Spacing.xl)
            }
        }
        .background(Color.cardBackground)
        .cornerRadius(Theme.CornerRadius.xl)
        .shadow(
            color: Theme.Shadow.card(for: colorScheme),
            radius: Theme.Shadow.lg,
            x: 0,
            y: 8
        )
    }
}

struct SharedReelsView_Previews: PreviewProvider {
    static var previews: some View {
        SharedReelsView()
            .environmentObject(UserManager())
            .environmentObject(SharedReelManager.shared)
    }
}
