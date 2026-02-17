//
//  ProcessingBanner.swift
//  informed
//
//  Loading banner shown during fact-check processing
//

import SwiftUI

struct ProcessingBanner: View {
    let link: String
    let thumbnailURL: URL?
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Thumbnail or placeholder
            if let thumbnailURL = thumbnailURL {
                AsyncImage(url: thumbnailURL) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Rectangle()
                            .fill(Color.brandBlue.opacity(0.1))
                    }
                }
                .frame(width: 50, height: 50)
                .cornerRadius(Theme.CornerRadius.sm)
                .clipped()
            } else {
                ZStack {
                    Rectangle()
                        .fill(Color.brandBlue.opacity(0.1))
                    Image(systemName: "link")
                        .foregroundColor(.brandBlue)
                }
                .frame(width: 50, height: 50)
                .cornerRadius(Theme.CornerRadius.sm)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Processing...")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                }
                
                Text(extractDomainName(from: link))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Image(systemName: "hourglass")
                .foregroundColor(.brandBlue)
                .font(.title3)
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(Theme.CornerRadius.lg)
        .shadow(
            color: Theme.Shadow.card(for: colorScheme),
            radius: Theme.Shadow.md,
            x: 0,
            y: 5
        )
    }
}
