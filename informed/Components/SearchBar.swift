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
    
    private var leadingColor: Color {
        if isValidSocialURL { return .brandGreen }
        if isTextSearch     { return .brandBlue }
        return .secondary
    }
    
    private var borderColor: Color {
        if isValidSocialURL { return .brandGreen }
        if isTextSearch     { return .brandBlue }
        return .clear
    }
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: leadingIcon)
                .foregroundColor(leadingColor)
                .font(.system(size: 18, weight: .medium))
                .animation(Theme.Animation.quick, value: leadingIcon)
            
            TextField("Search or paste a link (Instagram, TikTok, YouTube, X, Threads)…", text: $text)
                .foregroundColor(.primary)
                .focused($isFocused)
                .submitLabel(.search)
                .onSubmit { isFocused = false }
            
            if !text.isEmpty {
                Button(action: { text = ""; HapticManager.lightImpact() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(Theme.CornerRadius.lg)
        .shadow(
            color: Theme.Shadow.card(for: colorScheme),
            radius: Theme.Shadow.sm,
            x: 0,
            y: 2
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                .stroke(borderColor, lineWidth: 2)
        )
        .animation(Theme.Animation.quick, value: isValidSocialURL)
        .animation(Theme.Animation.quick, value: isTextSearch)
    }
}
