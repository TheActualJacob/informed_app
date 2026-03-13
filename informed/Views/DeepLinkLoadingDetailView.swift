//
//  DeepLinkLoadingDetailView.swift
//  informed
//
//  Wrapper view that opens immediately when the user taps a completed
//  Dynamic Island / Live Activity. Shows a loading skeleton that matches
//  the FactDetailView layout, then crossfades to the real content once
//  the backend data resolves.
//

import SwiftUI
import ActivityKit

struct DeepLinkLoadingDetailView: View {
    @EnvironmentObject var reelManager: SharedReelManager
    @Environment(\.presentationMode) var presentationMode

    @State private var resolvedItem: FactCheckItem? = nil
    @State private var failed = false

    var body: some View {
        Group {
            if let item = resolvedItem {
                FactDetailView(item: item)
            } else if failed {
                failedView
            } else {
                loadingSkeleton
            }
        }
        .onChange(of: reelManager.pendingDeepLinkItem) { _, item in
            guard let item else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                resolvedItem = item
            }
            reelManager.pendingDeepLinkItem = nil
            reelManager.deepLinkLoading = false
        }
        .onChange(of: reelManager.deepLinkLoading) { _, loading in
            // If loading was reset to false without an item, resolution failed
            if !loading && resolvedItem == nil {
                withAnimation { failed = true }
            }
        }
        .onAppear {
            // Pick up item if it was already resolved before this view mounted
            if let item = reelManager.pendingDeepLinkItem {
                resolvedItem = item
                reelManager.pendingDeepLinkItem = nil
                reelManager.deepLinkLoading = false
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

                    // Credibility badge placeholder
                    HStack {
                        shimmerRect(width: 120, height: 28, radius: 8)
                        Spacer()
                        shimmerRect(width: 60, height: 16, radius: 4)
                    }

                    // Title placeholders
                    VStack(alignment: .leading, spacing: 8) {
                        shimmerRect(width: .infinity, height: 24, radius: 6)
                        shimmerRect(width: 220, height: 24, radius: 6)
                    }

                    // Link preview placeholder
                    shimmerRect(width: .infinity, height: 56, radius: 12)

                    // Divider
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 1)

                    // Donut chart placeholder
                    HStack {
                        Spacer()
                        Circle()
                            .stroke(Color(.systemGray5), lineWidth: 12)
                            .frame(width: 120, height: 120)
                            .shimmering()
                        Spacer()
                    }

                    // Divider
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 1)

                    // Claims placeholder
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { Text("") }
        }
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

            Text("The result may still be processing.\nCheck the My Reels tab shortly.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                presentationMode.wrappedValue.dismiss()
            } label: {
                Text("Go Back")
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
