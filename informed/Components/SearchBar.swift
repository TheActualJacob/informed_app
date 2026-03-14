//
//  SearchBar.swift
//  informed
//
//  Reusable search bar component with link detection and text search
//

import SwiftUI

struct SearchBarView: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    @Environment(\.colorScheme) var colorScheme
    
    private var isValidSocialURL: Bool {
        guard let url = URL(string: text),
              url.scheme != nil,
              url.host != nil else { return false }
        let lower = text.lowercased()
        let isInstagram = lower.contains("instagram.com") || lower.contains("instagr.am")
        let isTikTok    = lower.contains("tiktok.com") || lower.contains("vm.tiktok.com")
        let isYouTube   = lower.contains("youtube.com/shorts") || lower.contains("youtu.be")
        let isThreads   = lower.contains("threads.net") || lower.contains("threads.com")
        let isTwitter   = lower.contains("twitter.com") || lower.contains("x.com")
        return isInstagram || isTikTok || isYouTube || isThreads || isTwitter
    }
    
    private var isTextSearch: Bool {
        !text.isEmpty && !isValidSocialURL
    }
    
    private var leadingIcon: String {
        if isValidSocialURL { return "link.circle.fill" }
        if isTextSearch     { return "magnifyingglass.circle.fill" }
        return "magnifyingglass"
    }
    
    private var accentColor: Color {
        if isValidSocialURL { return .brandGreen }
        if isTextSearch     { return .brandBlue }
        return .secondary
    }
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: leadingIcon)
                .foregroundColor(accentColor)
                .font(.system(size: 24, weight: .medium))
                .animation(Theme.Animation.quick, value: leadingIcon)
            
            TextField("Paste a link or search…", text: $text)
                .foregroundColor(.primary)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .focused($isFocused)
                .submitLabel(.search)
                .onSubmit { isFocused = false }
            
            if !text.isEmpty {
                Button(action: { text = ""; HapticManager.lightImpact() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 20))
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: Theme.CornerRadius.xl)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: Theme.CornerRadius.xl)
                    .fill(accentColor.opacity(text.isEmpty ? 0 : 0.08))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.xl)
                .stroke(
                    text.isEmpty
                        ? Color.white.opacity(colorScheme == .dark ? 0.15 : 0.6)
                        : accentColor.opacity(0.5),
                    lineWidth: text.isEmpty ? 0.5 : 1.5
                )
        )
        .shadow(
            color: accentColor.opacity(text.isEmpty ? 0 : 0.3),
            radius: text.isEmpty ? 0 : 16,
            x: 0, y: 0
        )
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.08),
            radius: 16,
            x: 0, y: 6
        )
        .animation(Theme.Animation.quick, value: isValidSocialURL)
        .animation(Theme.Animation.quick, value: isTextSearch)
    }
}
