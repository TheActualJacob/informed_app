//
//  HomeView.swift
//  informed
//
//  Main home view: search bar, category grid, personalized feed, and search results
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var viewModel: HomeViewModel
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var reelManager: SharedReelManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @FocusState private var isSearchFocused: Bool

    // Namespace for scroll-to-top
    private let scrollTopID = "homeScrollTop"

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                // ── Animated Liquid Glass Background ──────────────────────
                LiquidGlassBackground(isPro: subscriptionManager.isPro)

                VStack(spacing: 0) {
                    // ── Glass Header ─────────────────────────────────────
                    glassHeader

                    // ── Error Banner ─────────────────────────────────────
                    if let errorMessage = viewModel.errorMessage {
                        glassErrorBanner(errorMessage)
                    }

                    // ── Main Content ─────────────────────────────────────────
                    ScrollViewReader { scrollProxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {

                                // Invisible scroll anchor at the very top
                                Color.clear.frame(height: 0).id(scrollTopID)

                                if viewModel.isSearchMode {
                                    searchModeContent
                                } else {
                                    defaultModeContent
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
                        // Dismiss keyboard when the viewmodel detects a valid social link
                        .onChange(of: viewModel.dismissKeyboard) { _, shouldDismiss in
                            if shouldDismiss {
                                isSearchFocused = false
                                viewModel.dismissKeyboard = false
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
            .onAppear {
                if let userId = userManager.currentUserId { viewModel.userId = userId }
                if let sessionId = userManager.currentSessionId { viewModel.sessionId = sessionId }
                SharedReelManager.shared.homeViewModel = viewModel
                isSearchFocused = false
                viewModel.loadInitialData()
            }
        }
    }
    
    // MARK: - Glass Header

    private var glassHeader: some View {
        HStack {
            if viewModel.isSearchMode && viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let catName = viewModel.selectedCategory {
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
                    Text(subscriptionManager.isPro ? "+informed" : "informed")
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.brandTeal, .brandBlue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                Spacer()
                UsageCounterView()
                    .environmentObject(subscriptionManager)
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .animation(Theme.Animation.smooth, value: viewModel.isSearchMode)
    }

    // MARK: - Default Mode Content

    private var defaultModeContent: some View {
        VStack(spacing: 0) {
            // Category pills moved to above hero
            CategoryFlowView(
                categories: viewModel.categories.isEmpty
                    ? HomeViewModel.staticCategories
                    : viewModel.categories,
                isLoading: viewModel.isCategoriesLoading,
                onCategoryTap: { cat in
                    viewModel.selectCategory(cat.name)
                    isSearchFocused = false
                }
            )
            .padding(.top, 16)

            // Hero section with centered search bar
            VStack(spacing: 24) {
                if subscriptionManager.isPro {
                    HStack(spacing: 6) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 11, weight: .black))
                        Text("PRO MEMBER")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .tracking(1.5)
                    }
                    .foregroundColor(.brandGold)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.brandGold.opacity(0.4), lineWidth: 0.5))
                    .shadow(color: Color.brandGold.opacity(0.15), radius: 8, x: 0, y: 2)
                    .padding(.bottom, -8)
                } else {
                    Button {
                        HapticManager.lightImpact()
                        subscriptionManager.showPaywall = true
                    } label: {
                        HStack(spacing: 6) {
                            let checksLeft = max(0, subscriptionManager.usage.dailyLimit - subscriptionManager.usage.dailyUsed)
                            Text("\(checksLeft) checks left today")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.primary.opacity(0.8))
                            
                            HStack(spacing: 2) {
                                Text("UPGRADE")
                                    .font(.system(size: 10, weight: .black, design: .rounded))
                                    .tracking(0.5)
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 8, weight: .bold))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(LinearGradient(colors: [.brandTeal, .brandBlue], startPoint: .leading, endPoint: .trailing))
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                            .padding(.leading, 2)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.primary.opacity(0.15), lineWidth: 0.5))
                        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.bottom, -8)
                }

                Text(subscriptionManager.isPro ? "What would you like to verify?" : "Search or Paste a Link")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.primary, .primary.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)

                VStack(spacing: 12) {
                    SearchBarView(text: $viewModel.searchText, isFocused: $isSearchFocused)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.brandGreen)
                            .font(.system(size: 12))
                        Text("Supports Instagram, TikTok, YouTube, X, & Threads")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 8)
            }
            .padding(.horizontal)
            .padding(.top, 32)
            .padding(.bottom, 32)

            // Personalized Feed
            if viewModel.isFeedLoading {
                feedSkeletonSection
            } else if !viewModel.personalizedFeed.isEmpty {
                personalizedFeedSection
            }
        }
    }

    // MARK: - Search Mode Content

    private var searchModeContent: some View {
        VStack(spacing: 0) {
            if !(viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                 && viewModel.selectedCategory != nil) {
                SearchBarView(text: $viewModel.searchText, isFocused: $isSearchFocused)
                    .padding(.horizontal)
                    .padding(.top, 4)
                    .padding(.bottom, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

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
        }
    }

    // MARK: - Glass Error Banner

    private func glassErrorBanner(_ errorMessage: String) -> some View {
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
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .stroke(Color.brandYellow.opacity(0.3), lineWidth: 0.5)
        )
        .cornerRadius(Theme.CornerRadius.md)
        .padding(.horizontal)
        .padding(.top, Theme.Spacing.sm)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Personalized Feed Section
    
    private var personalizedFeedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: viewModel.feedSource == "personalized" ? "sparkles" : "flame.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(colors: [.brandTeal, .brandBlue], startPoint: .leading, endPoint: .trailing)
                    )
                Text(viewModel.feedSource == "personalized" ? "For You" : "Trending Fact-Checks")
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

// MARK: - Liquid Glass Background

struct LiquidGlassBackground: View {
    var isPro: Bool = false
    @State private var animate = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            Color.backgroundLight.ignoresSafeArea()

            GeometryReader { geo in
                if isPro {
                    Circle()
                        .fill(Color.brandGold.opacity(colorScheme == .dark ? 0.04 : 0.08))
                        .blur(radius: 100)
                        .frame(width: geo.size.width * 0.9, height: geo.size.width * 0.9)
                        .offset(x: animate ? -30 : 30, y: animate ? 20 : -20)
                        .position(x: geo.size.width * 0.5, y: geo.size.height * 0.3)
                }

                Circle()
                    .fill(Color.brandTeal.opacity(colorScheme == .dark ? 0.07 : 0.12))
                    .blur(radius: 90)
                    .frame(width: geo.size.width * 0.8, height: geo.size.width * 0.8)
                    .offset(x: animate ? 20 : -20, y: animate ? -15 : 15)
                    .position(x: geo.size.width * 0.25, y: geo.size.height * 0.2)

                Circle()
                    .fill(Color.brandBlue.opacity(colorScheme == .dark ? 0.05 : 0.09))
                    .blur(radius: 80)
                    .frame(width: geo.size.width * 0.7, height: geo.size.width * 0.7)
                    .offset(x: animate ? -15 : 15, y: animate ? 10 : -10)
                    .position(x: geo.size.width * 0.75, y: geo.size.height * 0.35)

                Circle()
                    .fill(Color.brandTeal.opacity(colorScheme == .dark ? 0.03 : 0.06))
                    .blur(radius: 60)
                    .frame(width: geo.size.width * 0.5, height: geo.size.width * 0.5)
                    .offset(x: animate ? 10 : -10, y: animate ? -8 : 8)
                    .position(x: geo.size.width * 0.5, y: geo.size.height * 0.6)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}
