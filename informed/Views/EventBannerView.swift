//
//  EventBannerView.swift
//  informed
//

import SwiftUI

struct EventBannerView: View {
    let event: ArticleData
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Background Image
            if let imageUrlString = event.headerImageUrl, let url = URL(string: imageUrlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        Color.brandTeal.opacity(0.8)
                    }
                }
            } else {
                Color.brandTeal.opacity(0.8)
            }
            
            // Dark gradient overlay
            LinearGradient(
                colors: [Color.black.opacity(0.8), Color.black.opacity(0.2), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            
            VStack(alignment: .leading, spacing: 8) {
                Text("UPCOMING EVENT")
                    .font(.caption)
                    .fontWeight(.black)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.brandBlue)
                    .clipShape(Capsule())
                
                Text(event.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                Text(event.summary)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(2)
            }
            .padding()
        }
        .frame(height: 160)
        .cornerRadius(20)
        .padding(.horizontal)
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
}
