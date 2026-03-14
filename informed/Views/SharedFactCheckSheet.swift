//
//  SharedFactCheckSheet.swift
//  informed
//
//  Presented as a sheet when a universal link (informed-app.com/share/{id})
//  opens the app. Shows a loading skeleton immediately, then transitions to
//  the full FactDetailView once the fact check is fetched from the backend.
//

import SwiftUI

struct SharedFactCheckSheet: View {
    let uniqueId: String

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var reelManager: SharedReelManager

    @State private var factCheckItem: FactCheckItem? = nil
    @State private var loadFailed = false

    var body: some View {
        NavigationView {
            Group {
                if let item = factCheckItem {
                    FactDetailView(item: item)
                } else if loadFailed {
                    failedView
                } else {
                    loadingSkeleton
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .task {
            await loadFactCheck()
        }
    }

    // MARK: - Loading Logic

    private func loadFactCheck() async {
        // Fast path: check the user's own synced reels first (avoids network round-trip)
        if let reel = reelManager.reels.first(where: { $0.id == uniqueId && $0.factCheckData != nil }),
           let data = reel.factCheckData {
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    factCheckItem = data.toFactCheckItem(originalLink: reel.url)
                }
            }
            return
        }

        // Remote fetch: the shared fact check belongs to another user or isn't cached yet
        if let userReel = await reelManager.fetchPublicFactCheck(uniqueId: uniqueId) {
            let storedData = StoredFactCheckData(
                title: userReel.title,
                summary: userReel.summary ?? userReel.claims.first?.summary ?? "",
                thumbnailURL: userReel.thumbnailUrl,
                claims: userReel.claims,
                datePosted: nil,
                platform: userReel.platform,
                aiGenerated: userReel.aiGenerated,
                aiProbability: userReel.aiProbability,
                reelID: userReel.id
            )
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    factCheckItem = storedData.toFactCheckItem(originalLink: userReel.link)
                }
            }
        } else {
            await MainActor.run {
                withAnimation { loadFailed = true }
            }
        }
    }

    // MARK: - Loading Skeleton

    private var loadingSkeleton: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // Hero placeholder
                ZStack {
                    LinearGradient(
                        colors: [Color(.systemGray5), Color(.systemGray4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.4)
                            .tint(.white)
                        Text("Loading fact check…")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .frame(height: 300)
                .overlay(
                    LinearGradient(
                        colors: [.black.opacity(0.4), .clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )

                // Content skeleton
                VStack(alignment: .leading, spacing: 24) {

                    HStack {
                        shimmerRect(width: 120, height: 28, radius: 8)
                        Spacer()
                        shimmerRect(width: 60, height: 16, radius: 4)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        shimmerRect(width: .infinity, height: 24, radius: 6)
                        shimmerRect(width: 220, height: 24, radius: 6)
                    }

                    shimmerRect(width: .infinity, height: 56, radius: 12)

                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 1)

                    HStack {
                        Spacer()
                        Circle()
                            .stroke(Color(.systemGray5), lineWidth: 12)
                            .frame(width: 120, height: 120)
                            .shimmering()
                        Spacer()
                    }

                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 1)

                    VStack(alignment: .leading, spacing: 12) {
                        shimmerRect(width: 100, height: 16, radius: 4)
                        shimmerRect(width: .infinity, height: 60, radius: 10)
                        shimmerRect(width: .infinity, height: 60, radius: 10)
                    }
                }
                .padding(20)
                .background(Color(.systemBackground))
                .cornerRadius(30)
                .offset(y: -40)
                .padding(.bottom, 40)
            }
        }
        .edgesIgnoringSafeArea(.top)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    // MARK: - Failed View

    private var failedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)

            Text("Couldn't load fact check")
                .font(.title3.bold())
                .foregroundColor(.primary)

            Text("This fact check may not exist or the link may be invalid.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                dismiss()
            } label: {
                Text("Dismiss")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.brandBlue)
                    .cornerRadius(12)
            }
        }
        .padding()
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helpers

    private func shimmerRect(width: CGFloat, height: CGFloat, radius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius)
            .fill(Color(.systemGray5))
            .frame(maxWidth: width == .infinity ? .infinity : width, minHeight: height, maxHeight: height)
            .shimmering()
    }
}
