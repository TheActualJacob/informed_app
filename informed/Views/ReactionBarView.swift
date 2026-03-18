//
//  ReactionBarView.swift
//  informed

import SwiftUI

struct ReactionBarView: View {

    let reactionCounts: ReactionCounts
    let onLike:    () -> Void
    let onDislike: () -> Void
    let onComment: () -> Void
    let onShare:   () -> Void

    var body: some View {
        HStack(spacing: 24) {
            // Like
            Button(action: onLike) {
                VStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(reactionCounts.userReaction == .like ? Color.brandTeal : Color.white)
                    Text("\(reactionCounts.likes)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }

            // Dislike
            Button(action: onDislike) {
                VStack(spacing: 4) {
                    Image(systemName: "hand.thumbsdown.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(reactionCounts.userReaction == .dislike ? Color.brandRed : Color.white)
                    Text("\(reactionCounts.dislikes)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }

            // Comment
            Button(action: onComment) {
                VStack(spacing: 4) {
                    Image(systemName: "bubble.left.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.white)
                    Text("Comments")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }

            Spacer()

            // Share
            Button(action: onShare) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.white)
            }
        }
    }
}
