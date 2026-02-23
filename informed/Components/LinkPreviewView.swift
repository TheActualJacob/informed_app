//
//  LinkPreviewView.swift
//  informed
//
//  Preview card for external links with thumbnail
//

import SwiftUI

struct LinkPreviewView: View {
    let item: FactCheckItem
    
    // True only when thumbnailURL is a real CDN image, not a social page URL
    private var hasRealThumbnail: Bool {
        guard let url = item.thumbnailURL else { return false }
        let s = url.absoluteString.lowercased()
        let isSocialPage = s.contains("instagram.com/reel") ||
                           s.contains("instagram.com/p/") ||
                           s.contains("tiktok.com/@") ||
                           s.contains("vm.tiktok.com") ||
                           (s.contains("instagram.com") && !s.contains("cdninstagram") && !s.contains("fbcdn")) ||
                           (s.contains("tiktok.com") && !s.contains("tiktokcdn") && !s.contains("muscdn"))
        return !isSocialPage
    }
    
    private var isTikTok: Bool {
        (item.originalLink ?? "").lowercased().contains("tiktok")
    }
    
    var body: some View {
        Button(action: {
            HapticManager.lightImpact()
            if let originalLink = item.originalLink, let url = URL(string: originalLink) {
                UIApplication.shared.open(url)
            }
        }) {
            HStack(spacing: 0) {
                // Thumbnail — fixed 90x90 on the left
                thumbnailView
                    .frame(width: 90, height: 90)
                    .clipped()
                
                // Text on the right
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.system(size: 14, weight: .bold, design: .serif))
                        .lineLimit(2)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 4) {
                        Text(item.displaySourceName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        if item.originalLink != nil {
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption2)
                                .foregroundColor(.brandBlue)
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, minHeight: 90)
            .background(Color.secondary.opacity(0.05))
            .cornerRadius(Theme.CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                    .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    @ViewBuilder
    private var thumbnailView: some View {
        if hasRealThumbnail {
            AsyncImage(url: item.thumbnailURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                case .failure:
                    ThumbnailPlaceholder(isTikTok: isTikTok)
                default:
                    Color.secondary.opacity(0.15)
                }
            }
        } else {
            ThumbnailPlaceholder(isTikTok: isTikTok)
        }
    }
}

// MARK: - Thumbnail Placeholder

struct ThumbnailPlaceholder: View {
    let isTikTok: Bool
    
    private var gradient: [Color] {
        isTikTok
            ? [Color(red: 0.01, green: 0.01, blue: 0.01), Color(red: 0.15, green: 0.15, blue: 0.15)]
            : [Color(red: 0.83, green: 0.12, blue: 0.53), Color(red: 0.50, green: 0.05, blue: 0.75)]
    }
    
    var body: some View {
        ZStack {
            LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 3) {
                Image(systemName: isTikTok ? "music.note" : "camera.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                Text("Watch")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
}
