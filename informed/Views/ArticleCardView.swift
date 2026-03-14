//
//  ArticleCardView.swift
//  informed
//

import SwiftUI

struct ArticleCardView: View {
    let article: ArticleData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: "Curated Article" or Author name
            HStack {
                Image(systemName: "newspaper.fill")
                    .foregroundColor(.brandBlue)
                    .padding(8)
                    .background(Color.brandBlue.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading) {
                    Text("Editor's Pick")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    Text("By \(article.author)")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.8))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.5))
            }
            
            // Image (if any)
            if let imageUrlString = article.headerImageUrl, let url = URL(string: imageUrlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 150)
                            .cornerRadius(12)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 150)
                            .cornerRadius(12)
                            .clipped()
                    case .failure:
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 150)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                            )
                            .cornerRadius(12)
                    @unknown default:
                        EmptyView()
                    }
                }
            }
            
            // Title
            Text(article.title)
                .font(.headline)
                .foregroundColor(.primary)
                .lineLimit(2)
            
            // Summary
            Text(article.summary)
                .font(.subheadline)
                .foregroundColor(.primary.opacity(0.8))
                .lineLimit(3)
        }
        .glassCardStyle()
    }
}
