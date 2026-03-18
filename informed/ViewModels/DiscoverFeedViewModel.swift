//
//  DiscoverFeedViewModel.swift
//  informed

import Foundation

@MainActor
final class DiscoverFeedViewModel: ObservableObject {

    // MARK: - Published

    @Published var reels: [PublicReel] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isFeedLoadingMore = false
    /// Optimistic reaction state keyed by reel uniqueID.
    /// Kept separate so the immutable PublicReel model is never mutated.
    @Published var reactionState: [String: ReactionCounts] = [:]

    // MARK: - Private

    private var nextCursor: String?
    private var hasMore = false
    private var isFetching = false

    // MARK: - Feed Loading

    func loadFeed() async {
        guard !isFetching else { return }
        isFetching = true
        defer { isFetching = false }

        guard let userId    = UserManager.shared.currentUserId,
              let sessionId = UserManager.shared.currentSessionId else { return }

        if reels.isEmpty { isLoading = true }
        defer { isLoading = false }

        do {
            let response = try await NetworkService.shared.fetchPersonalizedFeed(
                userId: userId,
                sessionId: sessionId,
                limit: 20
            )
            reels      = response.reels
            nextCursor = response.pagination?.nextCursor
            hasMore    = response.pagination?.hasMore ?? false
            seedReactionState(for: response.reels)
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func loadMore() {
        guard hasMore, let cursor = nextCursor, !isFetching else { return }
        Task { await loadMorePage(cursor: cursor) }
    }

    func refresh() async {
        nextCursor = nil
        hasMore    = false
        await loadFeed()
    }

    // MARK: - Reactions

    func react(reelId: String, reaction: ReactionCounts.UserReaction) async {
        guard let userId    = UserManager.shared.currentUserId,
              let sessionId = UserManager.shared.currentSessionId else { return }

        var current  = reactionState[reelId] ?? ReactionCounts(likes: 0, dislikes: 0)
        let toggleOff = current.userReaction == reaction

        // Optimistic update — mutual exclusion
        switch reaction {
        case .like:
            current.likes       = max(0, current.likes + (toggleOff ? -1 : 1))
            if !toggleOff && current.userReaction == .dislike {
                current.dislikes = max(0, current.dislikes - 1)
            }
        case .dislike:
            current.dislikes    = max(0, current.dislikes + (toggleOff ? -1 : 1))
            if !toggleOff && current.userReaction == .like {
                current.likes    = max(0, current.likes - 1)
            }
        }
        current.userReaction = toggleOff ? nil : reaction
        reactionState[reelId] = current

        // Fire-and-forget — only track when setting a reaction, not removing
        guard !toggleOff else { return }
        let interactionType = reaction == .like ? "like" : "dislike"
        Task {
            try? await NetworkService.shared.trackInteraction(
                userId: userId,
                sessionId: sessionId,
                factCheckId: reelId,
                interactionType: interactionType
            )
        }
    }

    // MARK: - Private Helpers

    private func loadMorePage(cursor: String) async {
        guard !isFetching else { return }
        isFetching = true
        defer { isFetching = false }

        guard let userId    = UserManager.shared.currentUserId,
              let sessionId = UserManager.shared.currentSessionId else { return }

        isFeedLoadingMore = true
        defer { isFeedLoadingMore = false }

        do {
            let response = try await NetworkService.shared.fetchPersonalizedFeed(
                userId: userId,
                sessionId: sessionId,
                limit: 20,
                cursor: cursor
            )
            reels.append(contentsOf: response.reels)
            nextCursor = response.pagination?.nextCursor
            hasMore    = response.pagination?.hasMore ?? false
            seedReactionState(for: response.reels)
        } catch {
            // Silent failure for load-more; existing content remains visible
        }
    }

    private func seedReactionState(for newReels: [PublicReel]) {
        for reel in newReels where reactionState[reel.id] == nil {
            reactionState[reel.id] = ReactionCounts(likes: 0, dislikes: 0)
        }
    }
}
