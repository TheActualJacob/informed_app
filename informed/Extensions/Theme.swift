//
//  Theme.swift
//  informed
//
//  Design system tokens for consistent styling
//

import SwiftUI

struct Theme {
    // MARK: - Spacing
    
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 30
    }
    
    // MARK: - Corner Radius
    
    struct CornerRadius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
    }
    
    // MARK: - Shadow
    
    struct Shadow {
        static let sm: CGFloat = 5
        static let md: CGFloat = 8
        static let lg: CGFloat = 15
        
        static func card(for colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.08)
        }
    }
    
    // MARK: - Typography
    
    struct Typography {
        // Sizes
        static let largeTitle: CGFloat = 32
        static let title: CGFloat = 28
        static let title2: CGFloat = 26
        static let headline: CGFloat = 18
        static let body: CGFloat = 15
        static let subheadline: CGFloat = 14
        static let caption: CGFloat = 12
        static let caption2: CGFloat = 10
        
        // Weights
        static let bold: Font.Weight = .bold
        static let semibold: Font.Weight = .semibold
        static let regular: Font.Weight = .regular
    }
    
    // MARK: - Animation
    
    struct Animation {
        static let spring = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.8)
        static let smooth = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let quick = SwiftUI.Animation.easeOut(duration: 0.2)
    }
    
    // MARK: - Icon Sizes
    
    struct IconSize {
        static let sm: CGFloat = 20
        static let md: CGFloat = 30
        static let lg: CGFloat = 40
        static let xl: CGFloat = 60
        static let xxl: CGFloat = 80
    }
}

// MARK: - Reusable Shape

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
