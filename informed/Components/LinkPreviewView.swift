//
//  LinkPreviewView.swift
//  informed
//
//  Preview card for external links with thumbnail
//

import SwiftUI

struct LinkPreviewView: View {
    let item: FactCheckItem
    
    var body: some View {
        Button(action: {
            HapticManager.lightImpact()
            if let originalLink = item.originalLink, let url = URL(string: originalLink) {
                UIApplication.shared.open(url)
            }
        }) {
            HStack(spacing: 0) {
                AsyncImage(url: item.thumbnailURL) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Rectangle().fill(Color.secondary.opacity(0.2))
                    }
                }
                .frame(width: 90, height: 90)
                .clipped()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.system(size: 14, weight: .bold, design: .serif))
                        .lineLimit(2)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 4) {
                        Text(item.sourceName)
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
            .frame(maxWidth: .infinity)
            .background(Color.secondary.opacity(0.05))
            .cornerRadius(Theme.CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                    .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
