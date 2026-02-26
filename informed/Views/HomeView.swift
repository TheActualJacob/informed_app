//
//  HomeView.swift
//  informed
//
//  Main home view: search bar, category grid, personalized feed, and search results
//

import SwiftUI

struct HomeView: View {
    @StateObject var viewModel = HomeViewModel()
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var reelManager: SharedReelManager
    @FocusState private var isSearchFocused: Bool

    // Namespace for scroll-to-top
    private let scrollTopID = "homeScrollTop"

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                Color.backgroundLight.ignoresSafeArea()

                VStack(spacing: 0) {
                    // ── Header ───────────────────────────────────────────────
                    VStack(spacing: 0) {
                        // Title row — switches between normal title and category header
                        HStack {
                            if viewModel.isSearchMode && viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                               let catName = viewModel.selectedCategory {
                                // Category browse header: back chevron + category name
                                Button {
                                    HapticManager.lightImpact()
                                    viewModel.clearSearch()
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "chevron.left")
                                            .font(.system(size: 17, weight: .semibold))
                                        Text(catName)
                                            .font(.system(size: 22, weight: .bold))
                                    }
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.brandTeal, .brandBlue],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                }
                                Spacer()
                                Button {
                                    HapticManager.lightImpact()
                                    viewModel.clearSearch()
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("informed")
                                        .font(.system(size: 28, weight: .black))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [.brandTeal, .brandBlue],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                    if !viewModel.isSearchMode {
                                        Text(viewModel.feedSource == "personalized" ? "Your personalized feed" : "Explore fact-checks")
                                            .font(.system(size: 13))
                                            .foregroundColor(.secondary)
                                            .transition(.opacity)
                                    }
                                }
                                Spacer()
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                        .animation(Theme.Animation.smooth, value: viewModel.isSearchMode)

                        // Search bar — hide when browsing a category (no text query)
                        if !(viewModel.isSearchMode && viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                            SearchBarView(text: $viewModel.searchText, isFocused: $isSearchFocused)
                                .padding(.horizontal)
                                .padding(.bottom, 10)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                    .background(Color.backgroundLight)
                    .onAppear {
                        if let userId = userManager.currentUserId {
                            viewModel.userId = userId
                        }
                        if let sessionId = userManager.currentSessionId {
                            viewModel.sessionId = sessionId
                        }
                        SharedReelManager.shared.homeViewModel = viewModel
                        isSearchFocused = false
                        viewModel.loadInitialData()
                    }

                    // ── Error Banner ─────────────────────────────────────────
                    if let errorMessage = viewModel.errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.brandYellow)
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.primary)
                            Spacer()
                            Button {
                                viewModel.errorMessage = nil
                                HapticManager.lightImpact()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color.brandYellow.opacity(0.1))
                        .cornerRadius(Theme.CornerRadius.md)
                        .padding(.horizontal)
                        .padding(.top, Theme.Spacing.sm)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // ── Main Content ─────────────────────────────────────────
                    ScrollViewReader { scrollProxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {

                                // Invisible scroll anchor at the very top
                                Color.clear.frame(height: 0).id(scrollTopID)

                                if viewModel.isSearchMode {
                                    // ── Search / Category Results ───────────
                                    SearchResultsView(
                                        query: viewModel.searchText,
                                        results: viewModel.searchResults,
                                        totalCount: viewModel.searchResultCount,
                                        isSearching: viewModel.isSearching,
                                        categories: viewModel.categories,
                                        selectedCategory: $viewModel.selectedCategory,
                                        onCategoryFilter: { cat in
                                            viewModel.filterSearchByCategory(cat)
                                        }
                                    )
                                    .padding(.top, Theme.Spacing.sm)
                                    // Swipe right to exit category browse
                                    .gesture(
                                        DragGesture(minimumDistance: 30, coordinateSpace: .local)
                                            .onEnded { value in
                                                let isRightSwipe = value.translation.width > 80 && abs(value.translation.height) < 60
                                                if isRightSwipe,
                                                   viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                                    HapticManager.lightImpact()
                                                    viewModel.clearSearch()
                                                }
                                            }
                                    )

                                } else {
                                    // ── Category Grid ────────────────────────
                                    CategoryGridView(
                                        categories: viewModel.categories.isEmpty
                                            ? HomeViewModel.staticCategories
                                            : viewModel.categories,
                                        isLoading: viewModel.isCategoriesLoading,
                                        onCategoryTap: { cat in
                                            viewModel.selectCategory(cat.name)
                                            isSearchFocused = false
                                        }
                                    )
                                    .padding(.horizontal)
                                    .padding(.top, Theme.Spacing.lg)

                                    // ── Personalized Feed ────────────────────
                                    if viewModel.isFeedLoading {
                                        feedSkeletonSection
                                    } else if !viewModel.personalizedFeed.isEmpty {
                                        personalizedFeedSection
                                    }
                                }
                            }
                            .padding(.bottom, (viewModel.processingLink != nil || reelManager.activeProcessingURL != nil) ? 140 : 100)
                        }
                        .refreshable {
                            HapticManager.lightImpact()
                            viewModel.refresh()
                        }
                        .simultaneousGesture(
                            DragGesture().onChanged { _ in
                                isSearchFocused = false
                            }
                        )
                        // Scroll to top whenever search mode activates (text search or category)
                        .onChange(of: viewModel.isSearchMode) { _, isSearch in
                            if isSearch {
                                withAnimation {
                                    scrollProxy.scrollTo(scrollTopID, anchor: .top)
                                }
                            }
                        }
                        // Also scroll to top when the search query itself changes (new search)
                        .onChange(of: viewModel.searchText) { _, _ in
                            if viewModel.isSearchMode {
                                withAnimation {
                                    scrollProxy.scrollTo(scrollTopID, anchor: .top)
                                }
                            }
                        }
                    }
                }
                
                // ── Processing Banner ─────────────────────────────────────
                // Show for in-app fact checks (processingLink) OR share-extension
                // fact checks that are still running (reelManager.activeProcessingURL).
                let bannerLink = viewModel.processingLink ?? reelManager.activeProcessingURL
                if let link = bannerLink {
                    VStack(spacing: 0) {
                        Spacer()
                        ProcessingBanner(
                            link: link,
                            thumbnailURL: viewModel.processingLink != nil ? viewModel.processingThumbnailURL : nil
                        )
                        .padding(.horizontal, Theme.Spacing.xl)
                        .padding(.bottom, Theme.Spacing.xl)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .onTapGesture { isSearchFocused = false }
            .animation(Theme.Animation.spring, value: viewModel.processingLink != nil || reelManager.activeProcessingURL != nil)
            .animation(Theme.Animation.smooth, value: viewModel.errorMessage != nil)
            .animation(Theme.Animation.smooth, value: viewModel.isSearchMode)
            .navigationBarHidden(true)
        }
    }
    
    // MARK: - Personalized Feed Section
    
    private var personalizedFeedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: viewModel.feedSource == "personalized" ? "sparkles" : "clock.arrow.circlepath")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.brandBlue)
                Text(viewModel.feedSource == "personalized" ? "For You" : "Recent Fact-Checks")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, Theme.Spacing.xl)
            
            LazyVStack(spacing: 12) {
                ForEach(viewModel.personalizedFeed) { reel in
                    NavigationLink(destination: PublicReelDetailView(reel: reel)) {
                        SearchReelRow(reel: reel)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal)
                    .onTapGesture { HapticManager.lightImpact() }
                }
            }
        }
    }
    
    // MARK: - Feed Skeleton
    
    private var feedSkeletonSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.15)).frame(width: 100, height: 20)
            }
            .padding(.horizontal)
            .padding(.top, Theme.Spacing.xl)
            
            VStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { _ in
                    SearchResultSkeleton()
                        .padding(.horizontal)
                }
            }
        }
    }
}
