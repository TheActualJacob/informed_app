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

struct FactCheckItem: Identifiable, Equatable {
    static func == (lhs: FactCheckItem, rhs: FactCheckItem) -> Bool {
        lhs.id == rhs.id
    }
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
    
    // Dynamic platform detection for backward compatibility with old data
    var displaySourceName: String {
        // If it's the old generic name, detect from URL
        if sourceName == "Fact Check API", let link = originalLink {
            if link.lowercased().contains("tiktok") {
                return "TikTok"
            } else if link.lowercased().contains("instagram") {
                return "Instagram"
            }
        }
        return sourceName
    }
    
    var displaySourceIcon: String {
        // If it's the old generic icon, detect from URL
        if sourceIcon == "checkmark.seal.fill", let link = originalLink {
            if link.lowercased().contains("tiktok") {
                return "music.note"
            } else if link.lowercased().contains("instagram") {
                return "camera.fill"
            }
        }
        return sourceIcon
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

// MARK: - Public Reel Models

struct ReelUser: Codable, Identifiable {
    let id: String
    let username: String
    
    enum CodingKeys: String, CodingKey {
        case id = "userId"
        case username
    }
    
    // Custom decoder to handle null userId
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle null userId by defaulting to "anonymous"
        if let userId = try? container.decodeIfPresent(String.self, forKey: .id) {
            id = userId ?? "anonymous"
        } else {
            id = "anonymous"
        }
        
        // Handle null username by defaulting to "Anonymous"
        if let usernameValue = try? container.decodeIfPresent(String.self, forKey: .username) {
            username = usernameValue ?? "Anonymous"
        } else {
            username = "Anonymous"
        }
    }
}

struct ReelEngagement: Codable {
    let viewCount: Int
    let shareCount: Int
    
    enum CodingKeys: String, CodingKey {
        case viewCount
        case shareCount
    }
}

struct PublicReel: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let thumbnailUrl: String?
    let videoLink: String
    let claim: String
    let verdict: String
    let claimAccuracyRating: String
    let explanation: String
    let summary: String
    let sources: [String]
    let checkedAt: String
    let datePosted: String?
    let category: String?
    let uploadedBy: ReelUser
    let engagement: ReelEngagement
    let platform: String? // "instagram" or "tiktok"
    
    enum CodingKeys: String, CodingKey {
        case id = "uniqueID"
        case title, description, thumbnailUrl, videoLink
        case claim, verdict, claimAccuracyRating
        case explanation, summary, sources, checkedAt, datePosted
        case category
        case uploadedBy, engagement, platform
    }
    
    // Custom decoder to handle datePosted as either String or Int
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        thumbnailUrl = try container.decodeIfPresent(String.self, forKey: .thumbnailUrl)
        videoLink = try container.decode(String.self, forKey: .videoLink)
        claim = try container.decode(String.self, forKey: .claim)
        verdict = try container.decode(String.self, forKey: .verdict)
        claimAccuracyRating = try container.decode(String.self, forKey: .claimAccuracyRating)
        explanation = try container.decodeIfPresent(String.self, forKey: .explanation) ?? ""
        summary = try container.decode(String.self, forKey: .summary)
        sources = try container.decode([String].self, forKey: .sources)
        checkedAt = try container.decode(String.self, forKey: .checkedAt)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        uploadedBy = try container.decode(ReelUser.self, forKey: .uploadedBy)
        engagement = try container.decode(ReelEngagement.self, forKey: .engagement)
        platform = try container.decodeIfPresent(String.self, forKey: .platform)
        
        // Handle datePosted as either String or Int
        if let dateString = try? container.decodeIfPresent(String.self, forKey: .datePosted) {
            datePosted = dateString
        } else if let dateInt = try? container.decodeIfPresent(Int.self, forKey: .datePosted) {
            // Convert timestamp to string
            datePosted = String(dateInt)
        } else {
            datePosted = nil
        }
    }
    
    // Computed properties
    var timeAgo: String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: checkedAt) {
            let relativeFormatter = RelativeDateTimeFormatter()
            relativeFormatter.unitsStyle = .abbreviated
            return relativeFormatter.localizedString(for: date, relativeTo: Date())
        }
        return "Recently"
    }
    
    var credibilityScore: Double {
        return calculateCredibilityScore(from: claimAccuracyRating)
    }
    
    // Detect platform from URL if not explicitly set
    var detectedPlatform: String {
        if let platform = platform {
            return platform
        }
        // Detect from URL
        if videoLink.contains("tiktok.com") || videoLink.contains("vm.tiktok.com") {
            return "tiktok"
        } else if videoLink.contains("instagram.com") {
            return "instagram"
        }
        return "instagram" // Default fallback
    }
    
    // Platform-specific display properties
    var platformDisplayName: String {
        return detectedPlatform == "tiktok" ? "TikTok" : "Instagram"
    }
    
    var platformIcon: String {
        return detectedPlatform == "tiktok" ? "music.note" : "camera.fill"
    }
    
    var credibilityLevel: CredibilityLevel {
        if credibilityScore >= 0.8 { return .high }
        if credibilityScore >= 0.5 { return .medium }
        return .low
    }
    
    // Convert to FactCheckItem for reusability with existing components
    func toFactCheckItem() -> FactCheckItem {
        let factCheck = FactCheck(
            claim: claim,
            verdict: verdict,
            claimAccuracyRating: claimAccuracyRating,
            explanation: explanation,
            summary: summary,
            sources: sources
        )
        
        return FactCheckItem(
            sourceName: platformDisplayName,
            sourceIcon: platformIcon,
            timeAgo: timeAgo,
            title: title,
            summary: summary,
            thumbnailURL: thumbnailUrl != nil ? URL(string: thumbnailUrl!) : nil,
            credibilityScore: credibilityScore,
            sources: sources.joined(separator: ", "),
            verdict: verdict,
            factCheck: factCheck,
            originalLink: videoLink,
            datePosted: datePosted
        )
    }
}

struct PublicFeedResponse: Codable {
    let reels: [PublicReel]
    let pagination: PaginationInfo
}

// MARK: - Category Models

struct CategoryItem: Identifiable, Codable {
    var id: String { name }
    let name: String
    let count: Int
}

struct CategoryResponse: Codable {
    let categories: [CategoryItem]
}

// MARK: - Search Response

struct SearchResponse: Codable {
    let reels: [PublicReel]
    let totalCount: Int
    let query: String
}

// MARK: - Personalized Feed Response

struct PersonalizedFeedResponse: Codable {
    let reels: [PublicReel]
    let totalCount: Int
    let source: String // "personalized" or "chronological"
}

struct PaginationInfo: Codable {
    let currentPage: Int
    let totalPages: Int
    let totalCount: Int
    let hasMore: Bool
    let nextCursor: String?
}

// MARK: - User Reel History Models

struct UserReel: Identifiable, Codable {
    let id: String
    let title: String
    let link: String
    let status: String // "completed", "processing", "pending", "failed"
    let thumbnailUrl: String?
    let submittedAt: String
    let claim: String?
    let verdict: String?
    let claimAccuracyRating: String?
    let explanation: String?
    let summary: String?
    let sources: [String]?
    let engagement: ReelEngagement?
    let errorMessage: String?
    let platform: String? // "instagram" or "tiktok"
    let errorType: String? // For enhanced error handling (age_restricted, unavailable, invalid_url, etc.)
    
    enum CodingKeys: String, CodingKey {
        case id = "uniqueID"
        case title, link, status, thumbnailUrl, submittedAt
        case claim, verdict, claimAccuracyRating, explanation, summary, sources
        case engagement, errorMessage, platform
        case errorType = "error_type"
    }
    
    var timeAgo: String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: submittedAt) {
            let relativeFormatter = RelativeDateTimeFormatter()
            relativeFormatter.unitsStyle = .abbreviated
            return relativeFormatter.localizedString(for: date, relativeTo: Date())
        }
        return "Recently"
    }
    
    var displayURL: String {
        if link.count > 50 {
            return String(link.prefix(47)) + "..."
        }
        return link
    }
    
    // Detect platform from URL if not explicitly set
    var detectedPlatform: String {
        if let platform = platform {
            return platform
        }
        // Detect from URL
        if link.contains("tiktok.com") || link.contains("vm.tiktok.com") {
            return "tiktok"
        } else if link.contains("instagram.com") {
            return "instagram"
        }
        return "instagram" // Default fallback
    }
    
    // Platform-specific display properties
    var platformDisplayName: String {
        return detectedPlatform == "tiktok" ? "TikTok" : "Instagram"
    }
    
    var platformIcon: String {
        return detectedPlatform == "tiktok" ? "music.note" : "camera.fill"
    }
}

struct UserReelsResponse: Codable {
    let reels: [UserReel]
    let totalCount: Int
}
