//
//  ColorPalette.swift
//  informed
//
//  Centralized color definitions for the app
//  Supports both light and dark modes
//

import SwiftUI

extension Color {
    // MARK: - Primary Brand Colors
    
    /// Teal accent color - used for highlights and secondary actions
    static let brandTeal = Color(red: 0.0, green: 0.75, blue: 0.85)
    
    /// Blue primary color - main brand color for primary actions
    static let brandBlue = Color(red: 0.15, green: 0.35, blue: 0.95)
    
    // MARK: - Semantic Colors
    
    /// Green for verified/true/positive states
    static let brandGreen = Color(red: 0.2, green: 0.75, blue: 0.45)
    
    /// Yellow for warnings/debated/mixed states
    static let brandYellow = Color(red: 0.98, green: 0.75, blue: 0.15)
    
    /// Red for false/negative/error states
    static let brandRed = Color(red: 0.95, green: 0.3, blue: 0.3)
    
    // MARK: - Adaptive Background Colors
    
    /// Main background color - adapts to light/dark mode
    static let backgroundLight = Color(UIColor.systemGroupedBackground)
    
    /// Card/container background - adapts to light/dark mode
    static let cardBackground = Color(UIColor.secondarySystemGroupedBackground)
    
    /// Subtle shadow for cards - adapts to light/dark mode
    static let cardShadow = Color.black.opacity(0.06)
    
    // MARK: - Gradient Presets
    
    /// Primary brand gradient (Teal to Blue)
    static func brandGradient(startPoint: UnitPoint = .topLeading, endPoint: UnitPoint = .bottomTrailing) -> LinearGradient {
        LinearGradient(
            colors: [.brandTeal, .brandBlue],
            startPoint: startPoint,
            endPoint: endPoint
        )
    }
}
