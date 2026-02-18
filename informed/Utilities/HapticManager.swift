//
//  HapticManager.swift
//  informed
//
//  Centralized haptic feedback management
//

import UIKit

struct HapticManager {
    // MARK: - Impact Feedback
    
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    static func lightImpact() {
        impact(.light)
    }
    
    static func mediumImpact() {
        impact(.medium)
    }
    
    static func heavyImpact() {
        impact(.heavy)
    }
    
    // MARK: - Notification Feedback
    
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
    
    static func success() {
        notification(.success)
    }
    
    static func warning() {
        notification(.warning)
    }
    
    static func error() {
        notification(.error)
    }
    
    // Convenience aliases
    static func successImpact() {
        success()
    }
    
    static func errorImpact() {
        error()
    }
    
    // MARK: - Selection Feedback
    
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}
