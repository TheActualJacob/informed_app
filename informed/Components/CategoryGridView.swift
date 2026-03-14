//
//  CategoryGridView.swift
//  informed
//
//  Elegant category grid for exploring fact-checked content
//

import SwiftUI

// MARK: - Category Metadata

struct CategoryMeta {
    let icon: String
    let gradient: [Color]
    
    static let map: [String: CategoryMeta] = [
        "Current Events":              CategoryMeta(icon: "newspaper.fill",          gradient: [Color(red:0.18,green:0.48,blue:0.96), Color(red:0.10,green:0.28,blue:0.80)]),
        "Politics & Government":       CategoryMeta(icon: "building.columns.fill",   gradient: [Color(red:0.60,green:0.18,blue:0.90), Color(red:0.40,green:0.10,blue:0.70)]),
        "Geopolitics & International": CategoryMeta(icon: "globe.americas.fill",     gradient: [Color(red:0.18,green:0.66,blue:0.96), Color(red:0.10,green:0.42,blue:0.80)]),
        "Health & Medicine":           CategoryMeta(icon: "cross.case.fill",         gradient: [Color(red:0.98,green:0.35,blue:0.44), Color(red:0.85,green:0.18,blue:0.30)]),
        "Science & Technology":        CategoryMeta(icon: "cpu.fill",                gradient: [Color(red:0.20,green:0.76,blue:0.64), Color(red:0.10,green:0.54,blue:0.46)]),
        "Environment & Climate":       CategoryMeta(icon: "leaf.fill",               gradient: [Color(red:0.22,green:0.78,blue:0.38), Color(red:0.12,green:0.58,blue:0.26)]),
        "Economy & Finance":           CategoryMeta(icon: "chart.line.uptrend.xyaxis",gradient:[Color(red:0.98,green:0.70,blue:0.15), Color(red:0.85,green:0.50,blue:0.08)]),
        "Entertainment & Celebrities": CategoryMeta(icon: "star.fill",               gradient: [Color(red:0.98,green:0.42,blue:0.70), Color(red:0.80,green:0.22,blue:0.55)]),
        "Sports":                      CategoryMeta(icon: "sportscourt.fill",         gradient: [Color(red:0.96,green:0.46,blue:0.20), Color(red:0.80,green:0.28,blue:0.08)]),
        "Social Media & Viral":        CategoryMeta(icon: "antenna.radiowaves.left.and.right", gradient: [Color(red:0.55,green:0.40,blue:0.98), Color(red:0.38,green:0.22,blue:0.84)]),
        "History":                     CategoryMeta(icon: "books.vertical.fill",     gradient: [Color(red:0.64,green:0.52,blue:0.38), Color(red:0.46,green:0.36,blue:0.24)]),
        "Other":                       CategoryMeta(icon: "square.grid.2x2.fill",    gradient: [Color(red:0.50,green:0.50,blue:0.55), Color(red:0.35,green:0.35,blue:0.40)])
    ]
    
    static func get(for name: String) -> CategoryMeta {
        map[name] ?? CategoryMeta(icon: "tag.fill", gradient: [.brandBlue, .brandTeal])
    }
}

// MARK: - Category Card

struct CategoryCard: View {
    let category: CategoryItem
    let onTap: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    private var meta: CategoryMeta { CategoryMeta.get(for: category.name) }
    
    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                // Gradient background
                LinearGradient(
                    colors: meta.gradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Decorative icon (large, faded, top-right)
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: meta.icon)
                            .font(.system(size: 44, weight: .bold))
                            .foregroundColor(.white.opacity(0.18))
                            .offset(x: 8, y: -8)
                    }
                    Spacer()
                }
                .padding(8)
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Image(systemName: meta.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(category.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    if category.count > 0 {
                        Text("\(category.count) checks")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.75))
                    }
                }
                .padding(12)
            }
            .frame(height: 105)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.md))
            .shadow(
                color: meta.gradient.first?.opacity(colorScheme == .dark ? 0.5 : 0.3) ?? .clear,
                radius: 8, x: 0, y: 4
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Scale Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(Theme.Animation.quick, value: configuration.isPressed)
    }
}

// MARK: - Category Grid View

struct CategoryGridView: View {
    let categories: [CategoryItem]
    let isLoading: Bool
    let onCategoryTap: (CategoryItem) -> Void
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Section header
            HStack {
                Text("Explore Topics")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                Spacer()
            }
            
            if isLoading {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(0..<6, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                            .fill(Color.cardBackground)
                            .frame(height: 105)
                            .shimmering()
                    }
                }
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(categories) { category in
                        CategoryCard(category: category) {
                            HapticManager.lightImpact()
                            onCategoryTap(category)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Shimmer modifier

extension View {
    func shimmering() -> some View {
        self.modifier(ShimmerModifier())
    }
}

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [.clear,
                             Color.white.opacity(0.25),
                             .clear],
                    startPoint: UnitPoint(x: phase, y: 0.5),
                    endPoint: UnitPoint(x: phase + 0.5, y: 0.5)
                )
                .blendMode(.plusLighter)
            )
            .onAppear {
                withAnimation(
                    .linear(duration: 1.2)
                    .repeatForever(autoreverses: false)
                ) { phase = 1.5 }
            }
    }
}

// MARK: - Glass Category Pill

struct CategoryPill: View {
    let category: CategoryItem
    let onTap: () -> Void
    @Environment(\.colorScheme) var colorScheme
    private var meta: CategoryMeta { CategoryMeta.get(for: category.name) }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: meta.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(meta.gradient.first ?? .brandBlue)

                Text(category.name)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                if category.count > 0 {
                    Text("\(category.count)")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(.primary.opacity(0.8))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.primary.opacity(0.08)))
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 40)
            .background(
                ZStack {
                    Capsule().fill(.ultraThinMaterial)
                    Capsule().fill((meta.gradient.first ?? .clear).opacity(colorScheme == .dark ? 0.15 : 0.1))
                }
            )
            .overlay(
                Capsule()
                    .stroke(
                        (meta.gradient.first ?? .clear).opacity(colorScheme == .dark ? 0.3 : 0.25),
                        lineWidth: 0.5
                    )
            )
            .shadow(
                color: (meta.gradient.first ?? .clear).opacity(colorScheme == .dark ? 0.2 : 0.15),
                radius: 8, x: 0, y: 4
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Premium Horizontal Category Scroll

struct CategoryFlowView: View {
    let categories: [CategoryItem]
    let isLoading: Bool
    let onCategoryTap: (CategoryItem) -> Void

    private let shimmerWidths: [CGFloat] = [120, 90, 140, 110, 130, 100, 125, 105]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Explore Topics")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    if isLoading {
                        ForEach(Array(shimmerWidths.enumerated()), id: \.offset) { _, width in
                            Capsule()
                                .fill(Color.cardBackground)
                                .frame(width: width, height: 40)
                                .shimmering()
                        }
                    } else {
                        ForEach(categories) { category in
                            CategoryPill(category: category) {
                                HapticManager.lightImpact()
                                onCategoryTap(category)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
    }
}
