//
//  FactResultCard.swift
//  informed
//
//  Card displaying fact-check results in the feed
//

import SwiftUI

struct FactResultCard: View {
    let item: FactCheckItem
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            HStack {
                Image(systemName: item.displaySourceIcon)
                    .foregroundColor(.brandBlue)
                    .padding(Theme.Spacing.sm)
                    .background(Color.brandBlue.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading) {
                    Text("Verified by AI + Humans")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    Text(item.timeAgo)
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.8))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.5))
            }
            
            LinkPreviewView(item: item)
            
            Text(item.summary)
                .font(.system(size: 15))
                .foregroundColor(.primary.opacity(0.8))
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            
            HStack {
                Text("Credibility:")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: item.credibilityLevel.icon)
                    Text(item.credibilityLevel.rawValue)
                }
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(item.credibilityLevel.color)
            }
            
            // Mini Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.2))
                    Capsule()
                        .fill(item.credibilityLevel.color)
                        .frame(width: geo.size.width * item.credibilityScore)
                }
            }
            .frame(height: 6)
            
            // AI Generation Badge (only show when flagged)
            if item.aiGenerated == "true" {
                HStack(spacing: 5) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Possibly AI-generated")
                        .font(.system(size: 12, weight: .semibold))
                    if let prob = item.aiProbability {
                        Text("(\(Int(prob * 100))%)")
                            .font(.system(size: 11))
                    }
                }
                .foregroundColor(Color.orange)
                .padding(.vertical, 5)
                .padding(.horizontal, 10)
                .background(Color.orange.opacity(0.12))
                .clipShape(Capsule())
            }
        }
        .padding(Theme.Spacing.xl)
        .background(Color.cardBackground)
        .cornerRadius(Theme.CornerRadius.xl)
        .shadow(
            color: Theme.Shadow.card(for: colorScheme),
            radius: Theme.Shadow.lg,
            x: 0,
            y: 8
        )
    }
}
