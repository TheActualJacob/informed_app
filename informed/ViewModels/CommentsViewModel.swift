//
//  CommentsViewModel.swift
//  informed

import Foundation
import Combine

@MainActor
final class CommentsViewModel: ObservableObject {

    // MARK: - Published

    @Published var comments: [Comment] = []
    @Published var isLoading = false
    @Published var isPosting = false
    @Published var newCommentText = ""
    @Published var errorMessage: String?

    // MARK: - Properties

    let factCheckId: String

    init(factCheckId: String) {
        self.factCheckId = factCheckId
    }

    // MARK: - Load

    func loadComments() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await NetworkService.shared.fetchComments(factCheckId: factCheckId)
            comments     = response.comments
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    // MARK: - Post

    func postComment() async {
        let trimmed = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isPosting else { return }

        guard let userId    = UserManager.shared.currentUserId,
              let sessionId = UserManager.shared.currentSessionId else {
            errorMessage = "Sign in to post a comment."
            return
        }

        isPosting = true
        defer { isPosting = false }

        do {
            let comment = try await NetworkService.shared.postComment(
                factCheckId: factCheckId,
                text: trimmed,
                userId: userId,
                sessionId: sessionId
            )
            comments.insert(comment, at: 0)
            newCommentText = ""
            errorMessage   = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
