//
//  HomeView.swift
//  informed
//
//  Main feed view for fact-checking content
//

import SwiftUI

struct HomeView: View {
    @StateObject var viewModel = HomeViewModel()
    @EnvironmentObject var userManager: UserManager
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                Color.backgroundLight
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    // Header with search
                    VStack {
                        SearchBarView(text: $viewModel.searchText, isFocused: $isSearchFocused)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(Color.backgroundLight)
                    .onAppear {
                        // Set the userId and sessionId when view appears
                        if let userId = userManager.currentUserId {
                            viewModel.userId = userId
                        }
                        if let sessionId = userManager.currentSessionId {
                            viewModel.sessionId = sessionId
                        }
                        
                        // Connect SharedReelManager to this ViewModel for integrated UI
                        SharedReelManager.shared.homeViewModel = viewModel
                        
                        // Dismiss keyboard when returning to this view
                        isSearchFocused = false
                    }
                    
                    // Error message banner
                    if let errorMessage = viewModel.errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.brandYellow)
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.primary)
                            Spacer()
                            Button(action: {
                                viewModel.errorMessage = nil
                                HapticManager.lightImpact()
                            }) {
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
                    
                    // Main content
                    ScrollView {
                        LazyVStack(spacing: Theme.Spacing.xl) {
                            ForEach(viewModel.items) { item in
                                NavigationLink(destination: FactDetailView(item: item)
                                    .onAppear {
                                        // Dismiss keyboard when navigating to detail
                                        isSearchFocused = false
                                    }
                                ) {
                                    FactResultCard(item: item)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .onTapGesture {
                                    HapticManager.lightImpact()
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                        .padding(.bottom, viewModel.processingLink != nil ? 140 : 100)
                    }
                    .refreshable {
                        HapticManager.lightImpact()
                        viewModel.refresh()
                    }
                    .simultaneousGesture(
                        DragGesture().onChanged { _ in
                            // Dismiss keyboard when user starts scrolling
                            isSearchFocused = false
                        }
                    )
                }
                
                // Processing Banner at Bottom
                if let processingLink = viewModel.processingLink {
                    VStack(spacing: 0) {
                        Spacer()
                        ProcessingBanner(
                            link: processingLink,
                            thumbnailURL: viewModel.processingThumbnailURL
                        )
                        .padding(.horizontal, Theme.Spacing.xl)
                        .padding(.bottom, Theme.Spacing.xl)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .onTapGesture {
                isSearchFocused = false
            }
            .animation(Theme.Animation.spring, value: viewModel.processingLink != nil)
            .animation(Theme.Animation.smooth, value: viewModel.errorMessage != nil)
            .navigationBarHidden(true)
        }
    }
}
