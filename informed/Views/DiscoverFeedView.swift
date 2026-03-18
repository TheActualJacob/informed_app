//
//  DiscoverFeedView.swift
//  informed

import SwiftUI

struct DiscoverFeedView: View {

    @EnvironmentObject private var viewModel: DiscoverFeedViewModel
    @State private var selectedReel: PublicReel?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                feedContent
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: Binding(
                get: { selectedReel != nil },
                set: { if !$0 { selectedReel = nil } }
            )) {
                if let reel = selectedReel {
                    PublicReelDetailView(reel: reel)
                }
            }
            .task {
                await viewModel.loadFeedIfNeeded()
            }
        }
    }

    // MARK: - Feed Content

    @ViewBuilder
    private var feedContent: some View {
        if viewModel.isLoading {
            ProgressView()
                .tint(.white)
        } else if viewModel.reels.isEmpty {
            DiscoverEmptyView()
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.reels) { reel in
                        DiscoverCardView(reel: reel, viewModel: viewModel, onTap: { selectedReel = reel })
                            .containerRelativeFrame([.horizontal, .vertical])
                            .onAppear {
                                if reel.id == viewModel.reels.last?.id {
                                    viewModel.loadMore()
                                }
                            }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .ignoresSafeArea(.container, edges: .top)
        }
    }
}

// MARK: - Empty state (dedicated subview per performance rules)

private struct DiscoverEmptyView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "safari")
                .font(.system(size: 52))
                .foregroundStyle(.white.opacity(0.4))

            Text("Nothing to discover yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white.opacity(0.8))

            Text("Be the first to share a video for fact-checking.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}
