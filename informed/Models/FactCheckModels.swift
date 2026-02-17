//
//  FactCheckModels.swift
//  informed
//
//  Data models for fact-checking functionality
//

import Foundation
import SwiftUI

// MARK: - Credibility Level

enum CredibilityLevel: String {
    case high = "Verified"
    case medium = "Debated"
    case low = "Misleading"

    var color: Color {
        switch self {
        case .high: return .brandGreen
        case .medium: return .brandYellow
        case .low: return .brandRed
        }
    }

    var icon: String {
        switch self {
        case .high: return "checkmark.seal.fill"
        case .medium: return "exclamationmark.triangle.fill"
        case .low: return "xmark.octagon.fill"
        }
    }
}

// MARK: - Fact Check

struct FactCheck: Codable {
    let claim: String
    let verdict: String
    let claimAccuracyRating: String
    let explanation: String
    let summary: String
    let sources: [String]

    enum CodingKeys: String, CodingKey {
        case claim, verdict, explanation, summary, sources
        case claimAccuracyRating = "claim_accuracy_rating"
    }
}

// MARK: - Fact Check Item

struct FactCheckItem: Identifiable {
    let id = UUID()
    let sourceName: String
    let sourceIcon: String
    let timeAgo: String
    let title: String
    let summary: String
    let thumbnailURL: URL?
    let credibilityScore: Double // 0.0 to 1.0
    let sources: String
    let verdict: String
    let factCheck: FactCheck
    let originalLink: String?  // Original video/post link
    let datePosted: String?    // Date the content was posted

    // Computed property for detailed analysis
    var detailedAnalysis: String {
        return factCheck.explanation
    }

    // Computed property for credibility level
    var credibilityLevel: CredibilityLevel {
        if credibilityScore >= 0.8 { return .high }
        if credibilityScore >= 0.5 { return .medium }
        return .low
    }
}

// MARK: - Helper Functions

func calculateCredibilityScore(from rating: String) -> Double {
    // Extract percentage from rating string like "100%" or "5%"
    let numericString = rating.replacingOccurrences(of: "%", with: "")
    if let percentage = Double(numericString) {
        return percentage / 100.0
    }
    return 0.5 // Default to 50% if parsing fails
}
