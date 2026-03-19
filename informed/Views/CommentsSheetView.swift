//
//  CommentsSheetView.swift
//  informed

import SwiftUI

struct CommentsSheetView: View {

    @StateObject private var viewModel: CommentsViewModel
    @FocusState  private var composerFocused: Bool
    @State       private var selectedDetent: PresentationDetent = .medium
    @Environment(\.dismiss) private var dismiss

    init(factCheckId: String) {
        _viewModel = StateObject(wrappedValue: CommentsViewModel(factCheckId: factCheckId))
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeaderView(count: viewModel.comments.count, dismiss: { dismiss() })
            Divider()
            commentsScrollView
            Divider()
            ComposerView(text: $viewModel.newCommentText,
                         isPosting: viewModel.isPosting,
                         isFocused: $composerFocused,
                         onSubmit: {
                             Task {
                                 await viewModel.postComment()
                                 composerFocused = false
                             }
                         })
        }
        .presentationDetents([.medium, .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
        .task { await viewModel.loadComments() }
        .onChange(of: composerFocused) { _, focused in
            if focused { selectedDetent = .large }
        }
        .sheet(isPresented: $viewModel.requiresEmailVerification) {
            VerifyEmailPromptView()
        }
    }

    // MARK: Comment list

    private var commentsScrollView: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView()
                    .padding(.top, 40)
                    .frame(maxWidth: .infinity)
            } else if viewModel.comments.isEmpty {
                Text("No comments yet. Be the first!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 40)
                    .frame(maxWidth: .infinity)
            } else {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(viewModel.comments) { comment in
                        CommentRowView(comment: comment)
                        Divider()
                            .padding(.leading, 16)
                    }
                }
            }
        }
        .scrollDismissesKeyboard(.never)
    }
}

// MARK: - Sheet Header (dedicated subview)

private struct SheetHeaderView: View {
    let count: Int
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text("Comments")
                .font(.system(size: 17, weight: .semibold))
            Text("(\(count))")
                .font(.system(size: 17))
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: dismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color(UIColor.tertiaryLabel))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }
}

// MARK: - Comment Row (dedicated subview)

private struct CommentRowView: View {
    let comment: Comment

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(comment.username)
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                let date = ISO8601DateFormatter().date(from: comment.createdAt)
                Text(date ?? .now, format: .relative(presentation: .named))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(comment.text)
                .font(.system(size: 15))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Composer (dedicated subview)

private struct ComposerView: View {
    @Binding var text: String
    let isPosting: Bool
    var isFocused: FocusState<Bool>.Binding
    let onSubmit: () -> Void

    private var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(spacing: 12) {
            TextField("Add a comment…", text: $text, axis: .vertical)
                .lineLimit(4)
                .focused(isFocused)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(Capsule())

            Button(action: onSubmit) {
                Image(systemName: isPosting ? "circle.dotted" : "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(isEmpty ? Color.secondary : Color.brandBlue)
            }
            .disabled(isEmpty || isPosting)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .padding(.bottom, 4)
    }
}
