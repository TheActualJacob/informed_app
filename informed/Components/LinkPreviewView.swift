//
//  LinkPreviewView.swift
//  informed
//
//  Preview card for external links with thumbnail
//

import SwiftUI

// MARK: - Thumbnail Image Loader
//
// Replaces AsyncImage to avoid two problems:
//  1. AsyncImage honours HTTP failure responses cached by URLSession — a previously
//     expired CDN URL (403) stays "failed" for the whole session even after the URL
//     is refreshed.
//  2. AsyncImage doesn't expose a way to force a reload when the URL identity changes
//     inside the same SwiftUI view tree.
//
// This loader:
//  • Uses .returnCacheDataElseLoad so valid cached images show instantly.
//  • On a load failure it retries once with .reloadIgnoringLocalCacheData so a
//    stale 403 cached response never permanently blocks a valid CDN URL.
//  • Exposes an `.id(url)` on the Task so SwiftUI recreates it whenever the URL
//    changes.

struct ThumbnailImage: View {
    let url: URL
    let isTikTok: Bool

    @State private var image: UIImage? = nil
    @State private var failed = false

    var body: some View {
        Group {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if failed {
                ThumbnailPlaceholder(isTikTok: isTikTok)
            } else {
                Color.secondary.opacity(0.15)
            }
        }
        .task(id: url) {
            await load(url: url)
        }
    }

    private func load(url: URL) async {
        // Reset state when URL changes
        image = nil
        failed = false

        if let img = await fetchImage(url: url, ignoreCache: false) {
            image = img
            return
        }
        // First attempt failed — retry ignoring any cached (possibly stale) response
        if let img = await fetchImage(url: url, ignoreCache: true) {
            image = img
            return
        }
        failed = true
    }

    private func fetchImage(url: URL, ignoreCache: Bool) async -> UIImage? {
        var request = URLRequest(url: url)
        request.cachePolicy = ignoreCache ? .reloadIgnoringLocalCacheData : .returnCacheDataElseLoad
        request.timeoutInterval = 15
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else { return nil }
            return UIImage(data: data)
        } catch {
            return nil
        }
    }
}

// MARK: - Link Preview View

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
        if hasRealThumbnail, let url = item.thumbnailURL {
            ThumbnailImage(url: url, isTikTok: isTikTok)
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
