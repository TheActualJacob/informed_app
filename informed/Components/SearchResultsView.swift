//
//  SearchResultsView.swift
//  informed
//
//  Search results with category filter chips
//

import SwiftUI

// MARK: - Category Filter Chips

struct CategoryFilterChips: View {
    let categories: [CategoryItem]
    @Binding var selectedCategory: String?
    let onSelect: (String?) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" chip
                FilterChip(label: "All", isSelected: selectedCategory == nil) {
                    onSelect(nil)
                }
                
                ForEach(categories.filter { $0.count > 0 || selectedCategory == $0.name }) { cat in
                    FilterChip(
                        label: cat.name,
                        isSelected: selectedCategory == cat.name
                    ) {
                        onSelect(selectedCategory == cat.name ? nil : cat.name)
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, 4)
        }
    }
}

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: { HapticManager.lightImpact(); onTap() }) {
            Text(label)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Color.brandBlue : Color.cardBackground)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.3), lineWidth: 1)
                )
        }
        .animation(Theme.Animation.quick, value: isSelected)
    }
}

// MARK: - Search Results View

struct SearchResultsView: View {
    let query: String
    let results: [PublicReel]
    let totalCount: Int
    let isSearching: Bool
    let categories: [CategoryItem]
    @Binding var selectedCategory: String?
    let onCategoryFilter: (String?) -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Result count header
            HStack(spacing: 6) {
                if isSearching {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.brandBlue)
                }
                
                Group {
                    if isSearching {
                        Text("Searching…")
                            .foregroundColor(.secondary)
                    } else {
                        Text("\(totalCount > 0 ? "\(totalCount)" : "No") result\(totalCount == 1 ? "" : "s") for ")
                            .foregroundColor(.secondary) +
                        Text("\"\(query)\"")
                            .foregroundColor(.primary)
                            .fontWeight(.semibold)
                    }
                }
                .font(.system(size: 14))
                
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
            
            // Category filter chips (only show if we have categories)
            if !categories.isEmpty {
                CategoryFilterChips(
                    categories: categories,
                    selectedCategory: $selectedCategory,
                    onSelect: onCategoryFilter
                )
                .padding(.bottom, Theme.Spacing.sm)
            }
            
            if isSearching && results.isEmpty {
                // Skeleton loading
                VStack(spacing: 12) {
                    ForEach(0..<4, id: \.self) { _ in
                        SearchResultSkeleton()
                            .padding(.horizontal, Theme.Spacing.lg)
                    }
                }
                .padding(.top, Theme.Spacing.sm)
            } else if results.isEmpty && !isSearching {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("No results found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Try a different search term or remove filters.")
                        .font(.subheadline)
                        .foregroundColor(.secondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 50)
                .padding(.horizontal)
            } else {
                // Results list
                LazyVStack(spacing: 12) {
                    ForEach(results) { reel in
                        NavigationLink(destination: PublicReelDetailView(reel: reel)) {
                            SearchReelRow(reel: reel)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal, Theme.Spacing.lg)
                    }
                }
                .padding(.top, Theme.Spacing.sm)
            }
        }
    }
}

// MARK: - Search Result Row

struct SearchReelRow: View {
    let reel: PublicReel
    @Environment(\.colorScheme) var colorScheme
    
    private var isTikTok: Bool { reel.detectedPlatform == "tiktok" }
    
    private var hasRealThumbnail: Bool {
        guard let urlStr = reel.thumbnailUrl else { return false }
        let s = urlStr.lowercased()
        let isSocialPage = s.contains("instagram.com/reel") ||
                           s.contains("instagram.com/p/") ||
                           s.contains("tiktok.com/@") ||
                           s.contains("vm.tiktok.com") ||
                           (s.contains("instagram.com") && !s.contains("cdninstagram") && !s.contains("fbcdn")) ||
                           (s.contains("tiktok.com") && !s.contains("tiktokcdn") && !s.contains("muscdn"))
        return !isSocialPage
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Thumbnail
            Group {
                if hasRealThumbnail, let urlStr = reel.thumbnailUrl, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        case .failure:
                            ThumbnailPlaceholder(isTikTok: isTikTok)
                        default:
                            Color.secondary.opacity(0.15).shimmering()
                        }
                    }
                } else {
                    ThumbnailPlaceholder(isTikTok: isTikTok)
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.sm))
            
            // Content
            VStack(alignment: .leading, spacing: 5) {
                // Platform + category badge row
                HStack(spacing: 6) {
                    Label(reel.platformDisplayName, systemImage: reel.platformIcon)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    if let cat = reel.category {
                        Text("·")
                            .foregroundColor(.secondary)
                            .font(.system(size: 11))
                        Text(cat)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.brandBlue)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                
                Text(reel.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                Text(reel.summary)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                // Verdict badge
                VerdictBadge(verdict: reel.verdict)
            }
            
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.cardBackground)
        .cornerRadius(Theme.CornerRadius.md)
        .shadow(
            color: Theme.Shadow.card(for: colorScheme),
            radius: Theme.Shadow.sm, x: 0, y: 2
        )
    }
}

// MARK: - Verdict Badge

struct VerdictBadge: View {
    let verdict: String
    
    private var color: Color {
        switch verdict.lowercased() {
        case "true":                    return .brandGreen
        case "false":                   return .brandRed
        case "misleading", "mixed":     return .brandYellow
        default:                        return .secondary
        }
    }
    
    private var icon: String {
        switch verdict.lowercased() {
        case "true":    return "checkmark.circle.fill"
        case "false":   return "xmark.circle.fill"
        default:        return "exclamationmark.circle.fill"
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(verdict)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }
}

// MARK: - Search Result Skeleton

struct SearchResultSkeleton: View {
    @State private var shimmer: Bool = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                .fill(Color.secondary.opacity(0.15))
                .frame(width: 72, height: 72)
            
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(height: 12)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.12))
                    .frame(height: 12)
                    .padding(.trailing, 40)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.10))
                    .frame(height: 10)
                    .padding(.trailing, 80)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color.cardBackground)
        .cornerRadius(Theme.CornerRadius.md)
        .shimmering()
    }
}
