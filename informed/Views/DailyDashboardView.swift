import SwiftUI

struct DailyDashboardView: View {
    @EnvironmentObject private var viewModel: FeedViewModel
    @EnvironmentObject var userManager: UserManager

    @State private var activeStory: Story?
    @State private var headerAppeared = false

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Late night reads"
        }
    }

    private var todayFormatted: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: Date())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Rich dark gradient background
                LinearGradient(
                    colors: [Color(white: 0.06), Color(white: 0.02)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                if viewModel.isLoading && viewModel.stories.isEmpty {
                    loadingView
                } else if let errorMessage = viewModel.errorMessage,
                          viewModel.stories.isEmpty {
                    errorView(message: errorMessage)
                } else if viewModel.stories.isEmpty {
                    emptyStateView
                } else {
                    storiesContent
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(item: $activeStory) { story in
                DailyStoryPlayerView(story: story, onDismiss: { activeStory = nil })
            }
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
            .task {
                if viewModel.stories.isEmpty {
                    await viewModel.loadFeed()
                }
                withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
                    headerAppeared = true
                }
            }
        }
    }

    // MARK: - Stories Content

    private var storiesContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text(greeting)
                        .font(.custom("Inter-Medium", size: 15))
                        .foregroundStyle(.secondary)

                    Text("Your Daily Briefing")
                        .font(.custom("GreycliffCF-Bold", size: 32))
                        .foregroundColor(.white)

                    Text(todayFormatted.uppercased())
                        .font(.custom("Inter-Bold", size: 11))
                        .tracking(1.4)
                        .foregroundStyle(Color.brandTeal)
                        .padding(.top, 2)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 28)
                .opacity(headerAppeared ? 1 : 0)
                .offset(y: headerAppeared ? 0 : 12)

                // Featured story (first)
                if let featured = viewModel.stories.first {
                    Button { activeStory = featured } label: {
                        FeaturedStoryCard(story: featured)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }

                // Remaining stories
                if viewModel.stories.count > 1 {
                    Text("MORE STORIES")
                        .font(.custom("Inter-Bold", size: 11))
                        .tracking(1.4)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)

                    VStack(spacing: 12) {
                        ForEach(Array(viewModel.stories.dropFirst())) { story in
                            Button { activeStory = story } label: {
                                CompactStoryCard(story: story)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }

                Spacer(minLength: 40)
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.brandTeal.opacity(0.1))
                    .frame(width: 80, height: 80)
                ProgressView()
                    .tint(.brandTeal)
                    .scaleEffect(1.3)
            }
            Text("Preparing your briefing…")
                .font(.custom("Inter-Medium", size: 15))
                .foregroundStyle(.secondary)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "sun.haze.fill")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(
                    LinearGradient(colors: [.brandYellow, .orange], startPoint: .top, endPoint: .bottom)
                )
                .symbolEffect(.pulse.byLayer, options: .repeating)

            Text("No Briefings Yet")
                .font(.custom("GreycliffCF-Bold", size: 26))
                .foregroundColor(.white)

            Text("Check back later for today's\nsummary of the news.")
                .font(.custom("Inter-Regular", size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Task { await viewModel.refresh() }
            } label: {
                Text("Refresh")
                    .font(.custom("Inter-SemiBold", size: 15))
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 36)
                    .background(Color.brandBlue, in: Capsule())
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 40)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color.brandRed)

            Text("Couldn't Load Briefing")
                .font(.custom("GreycliffCF-Bold", size: 24))
                .foregroundColor(.white)

            Text(message)
                .font(.custom("Inter-Regular", size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                Task { await viewModel.refresh() }
            } label: {
                Text("Try Again")
                    .font(.custom("Inter-SemiBold", size: 15))
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 36)
                    .background(Color.brandBlue, in: Capsule())
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - Featured Story Card

private struct FeaturedStoryCard: View {
    let story: Story

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Cover image or gradient
            Group {
                if let urlStr = story.coverImageUrl, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            defaultGradient
                        }
                    }
                } else {
                    defaultGradient
                }
            }
            .frame(maxWidth: .infinity, minHeight: 340, maxHeight: 340)
            .clipped()

            // Scrim
            LinearGradient(
                colors: [.clear, .black.opacity(0.85)],
                startPoint: .center,
                endPoint: .bottom
            )

            // Content
            VStack(alignment: .leading, spacing: 8) {
                if let category = story.category {
                    Text(category.uppercased())
                        .font(.custom("Inter-Bold", size: 10))
                        .tracking(1.2)
                        .foregroundColor(.brandTeal)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.12), in: Capsule())
                }

                Text(story.headline)
                    .font(.custom("GreycliffCF-Bold", size: 24))
                    .foregroundColor(.white)
                    .lineLimit(3)

                if let summary = story.summary {
                    Text(summary)
                        .font(.custom("Inter-Regular", size: 14))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(2)
                }

                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10))
                    Text("Read story")
                        .font(.custom("Inter-SemiBold", size: 13))
                }
                .foregroundColor(.brandTeal)
                .padding(.top, 4)
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var defaultGradient: some View {
        LinearGradient(
            colors: [Color.brandBlue, Color.brandTeal.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Compact Story Card

private struct CompactStoryCard: View {
    let story: Story

    var body: some View {
        HStack(spacing: 14) {
            // Thumbnail
            Group {
                if let urlStr = story.coverImageUrl, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            smallGradient
                        }
                    }
                } else {
                    smallGradient
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                if let category = story.category {
                    Text(category.uppercased())
                        .font(.custom("Inter-Bold", size: 9))
                        .tracking(1)
                        .foregroundStyle(Color.brandTeal)
                }
                Text(story.headline)
                    .font(.custom("Inter-SemiBold", size: 15))
                    .foregroundColor(.white)
                    .lineLimit(2)
                if let summary = story.summary {
                    Text(summary)
                        .font(.custom("Inter-Regular", size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private var smallGradient: some View {
        LinearGradient(
            colors: [Color.brandBlue.opacity(0.6), Color.brandTeal.opacity(0.4)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
