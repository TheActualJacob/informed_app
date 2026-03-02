//
//  FactCheckModels.swift
//  informed
//

import Foundation
import SwiftUI

// MARK: - CredibilityLevel

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

// MARK: - ClaimEntry

struct ClaimEntry: Codable, Equatable {
    let claim: String
    let verdict: String
    let claimAccuracyRating: String
    let explanation: String
    let summary: String
    let sources: [String]
    let category: String?

    // Supports both camelCase (new API) and snake_case (older reels) for the rating key
    enum CodingKeys: String, CodingKey {
        case claim, verdict, explanation, summary, sources, category
        case claimAccuracyRating
        case claimAccuracyRatingSnake = "claim_accuracy_rating"
    }

    init(claim: String, verdict: String, claimAccuracyRating: String,
         explanation: String, summary: String, sources: [String], category: String? = nil) {
        self.claim = claim; self.verdict = verdict
        self.claimAccuracyRating = claimAccuracyRating
        self.explanation = explanation; self.summary = summary
        self.sources = sources; self.category = category
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        claim   = try c.decode(String.self, forKey: .claim)
        verdict = try c.decode(String.self, forKey: .verdict)
        // Accept both camelCase and snake_case for the accuracy rating
        claimAccuracyRating =
            (try? c.decodeIfPresent(String.self, forKey: .claimAccuracyRating)) ??
            (try? c.decodeIfPresent(String.self, forKey: .claimAccuracyRatingSnake)) ??
            "50%"
        explanation = (try? c.decodeIfPresent(String.self, forKey: .explanation)) ?? ""
        summary     = (try? c.decodeIfPresent(String.self, forKey: .summary))     ?? ""
        sources     = (try? c.decodeIfPresent([String].self, forKey: .sources))   ?? []
        category    = try? c.decodeIfPresent(String.self, forKey: .category)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(claim, forKey: .claim)
        try c.encode(verdict, forKey: .verdict)
        try c.encode(claimAccuracyRating, forKey: .claimAccuracyRating)
        try c.encode(explanation, forKey: .explanation)
        try c.encode(summary, forKey: .summary)
        try c.encode(sources, forKey: .sources)
        try c.encodeIfPresent(category, forKey: .category)
    }

    var credibilityScore: Double { calculateCredibilityScore(from: claimAccuracyRating) }
    var credibilityLevel: CredibilityLevel {
        if credibilityScore >= 0.8 { return .high }
        if credibilityScore >= 0.5 { return .medium }
        return .low
    }
    var asFactCheck: FactCheck {
        FactCheck(claim: claim, verdict: verdict, claimAccuracyRating: claimAccuracyRating,
                  explanation: explanation, summary: summary, sources: sources)
    }
}

// MARK: - FactCheck (legacy bridge)

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

// MARK: - FactCheckItem

struct FactCheckItem: Identifiable, Equatable {
    static func == (lhs: FactCheckItem, rhs: FactCheckItem) -> Bool { lhs.id == rhs.id }
    let id = UUID()
    /// The backend uniqueID for this fact check — used to build the shareable web preview URL.
    let reelID: String?
    let sourceName: String
    let sourceIcon: String
    let timeAgo: String
    let title: String
    let summary: String
    let thumbnailURL: URL?
    let credibilityScore: Double
    let sources: String
    let verdict: String
    let claims: [ClaimEntry]
    let originalLink: String?
    let datePosted: String?
    let aiGenerated: String?
    let aiProbability: Double?

    var factCheck: FactCheck { claims[0].asFactCheck }
    var detailedAnalysis: String { claims[0].explanation }
    /// Average of all individual claims' accuracy scores (falls back to credibilityScore for single-claim items)
    var averageCredibilityScore: Double {
        guard !claims.isEmpty else { return credibilityScore }
        let total = claims.reduce(0.0) { $0 + $1.credibilityScore }
        return total / Double(claims.count)
    }
    var averageCredibilityLevel: CredibilityLevel {
        let s = averageCredibilityScore
        if s >= 0.8 { return .high }
        if s >= 0.5 { return .medium }
        return .low
    }
    var credibilityLevel: CredibilityLevel {
        if credibilityScore >= 0.8 { return .high }
        if credibilityScore >= 0.5 { return .medium }
        return .low
    }
    var displaySourceName: String {
        if sourceName == "Fact Check API", let link = originalLink {
            return platformInfo(for: detectedPlatformFromURL(link)).name
        }
        return sourceName
    }
    var displaySourceIcon: String {
        if sourceIcon == "checkmark.seal.fill", let link = originalLink {
            return platformInfo(for: detectedPlatformFromURL(link)).icon
        }
        return sourceIcon
    }
}

// MARK: - Helpers

func platformInfo(for platform: String) -> (name: String, icon: String) {
    switch platform.lowercased() {
    case "tiktok":         return ("TikTok",     "music.note")
    case "youtube_shorts": return ("YouTube",    "play.rectangle.fill")
    case "threads":        return ("Threads",    "bubble.left.and.bubble.right.fill")
    case "twitter":        return ("X / Twitter","bird.fill")
    default:               return ("Instagram",  "camera.fill")
    }
}
func isTextOnlyPlatform(_ platform: String?) -> Bool {
    guard let p = platform?.lowercased() else { return false }
    return p == "twitter" || p == "threads"
}
func detectedPlatformFromURL(_ url: String) -> String {
    let l = url.lowercased()
    if l.contains("tiktok.com") || l.contains("vm.tiktok.com") { return "tiktok" }
    if l.contains("youtube.com/shorts") || l.contains("youtu.be") { return "youtube_shorts" }
    if l.contains("threads.net") || l.contains("threads.com") { return "threads" }
    if l.contains("twitter.com") || l.contains("x.com") { return "twitter" }
    return "instagram"
}
func calculateCredibilityScore(from rating: String) -> Double {
    let s = rating.replacingOccurrences(of: "%", with: "")
    return Double(s).map { $0 / 100.0 } ?? 0.5
}

// MARK: - ReelUser / ReelEngagement

struct ReelUser: Codable, Identifiable {
    let id: String
    let username: String
    enum CodingKeys: String, CodingKey { case id = "userId"; case username }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id       = (try? c.decodeIfPresent(String.self, forKey: .id))       ?? "anonymous"
        username = (try? c.decodeIfPresent(String.self, forKey: .username)) ?? "Anonymous"
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id); try c.encode(username, forKey: .username)
    }
}
struct ReelEngagement: Codable { let viewCount: Int; var shareCount: Int }

// MARK: - PublicReel

struct PublicReel: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let thumbnailUrl: String?
    let videoLink: String
    let claims: [ClaimEntry]
    let checkedAt: String
    let datePosted: String?
    let uploadedBy: ReelUser
    var engagement: ReelEngagement
    let platform: String?
    let aiGenerated: String?
    let aiProbability: Double?

    var claim: String               { claims[0].claim }
    var verdict: String             { claims[0].verdict }
    var claimAccuracyRating: String { claims[0].claimAccuracyRating }
    var explanation: String         { claims[0].explanation }
    var summary: String             { claims[0].summary }
    var sources: [String]           { claims[0].sources }
    var category: String?           { claims[0].category }

    enum CodingKeys: String, CodingKey {
        case id = "uniqueID"
        case title, description, thumbnailUrl, videoLink, claims
        case claim, verdict, explanation, summary, sources, category
        case claimAccuracyRating = "claim_accuracy_rating"
        case checkedAt, datePosted, uploadedBy, engagement, platform
        case aiGenerated, aiProbability
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(String.self, forKey: .id)
        title       = try c.decode(String.self, forKey: .title)
        description = try c.decode(String.self, forKey: .description)
        thumbnailUrl = try c.decodeIfPresent(String.self, forKey: .thumbnailUrl)
        videoLink   = try c.decode(String.self, forKey: .videoLink)
        checkedAt   = try c.decode(String.self, forKey: .checkedAt)
        uploadedBy  = try c.decode(ReelUser.self, forKey: .uploadedBy)
        engagement  = try c.decode(ReelEngagement.self, forKey: .engagement)
        platform    = try c.decodeIfPresent(String.self, forKey: .platform)
        aiGenerated = try c.decodeIfPresent(String.self, forKey: .aiGenerated)
        aiProbability = try c.decodeIfPresent(Double.self, forKey: .aiProbability)
        if let ds = try? c.decodeIfPresent(String.self, forKey: .datePosted) { datePosted = ds }
        else if let di = try? c.decodeIfPresent(Int.self, forKey: .datePosted) { datePosted = String(di) }
        else { datePosted = nil }
        // New API: claims array
        if let arr = try? c.decodeIfPresent([ClaimEntry].self, forKey: .claims), !arr.isEmpty {
            claims = arr
        } else {
            // Legacy flat — backend uses "claim_accuracy_rating" (snake_case)
            let cl  = (try? c.decodeIfPresent(String.self,   forKey: .claim))               ?? ""
            let v   = (try? c.decodeIfPresent(String.self,   forKey: .verdict))             ?? ""
            let car = (try? c.decodeIfPresent(String.self,   forKey: .claimAccuracyRating)) ?? "50%"
            let exp = (try? c.decodeIfPresent(String.self,   forKey: .explanation))         ?? ""
            let sum = (try? c.decodeIfPresent(String.self,   forKey: .summary))             ?? ""
            let src = (try? c.decodeIfPresent([String].self, forKey: .sources))             ?? []
            let cat = try? c.decodeIfPresent(String.self,    forKey: .category)
            claims  = [ClaimEntry(claim: cl, verdict: v, claimAccuracyRating: car,
                                  explanation: exp, summary: sum, sources: src, category: cat)]
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id); try c.encode(title, forKey: .title)
        try c.encode(description, forKey: .description)
        try c.encodeIfPresent(thumbnailUrl, forKey: .thumbnailUrl)
        try c.encode(videoLink, forKey: .videoLink); try c.encode(claims, forKey: .claims)
        try c.encode(checkedAt, forKey: .checkedAt)
        try c.encodeIfPresent(datePosted, forKey: .datePosted)
        try c.encode(uploadedBy, forKey: .uploadedBy); try c.encode(engagement, forKey: .engagement)
        try c.encodeIfPresent(platform, forKey: .platform)
        try c.encodeIfPresent(aiGenerated, forKey: .aiGenerated)
        try c.encodeIfPresent(aiProbability, forKey: .aiProbability)
    }

    var timeAgo: String {
        let f = ISO8601DateFormatter()
        guard let d = f.date(from: checkedAt) else { return "Recently" }
        let r = RelativeDateTimeFormatter(); r.unitsStyle = .abbreviated
        return r.localizedString(for: d, relativeTo: Date())
    }
    var credibilityScore: Double { calculateCredibilityScore(from: claimAccuracyRating) }
    /// Average of all individual claims' accuracy scores
    var averageCredibilityScore: Double {
        guard !claims.isEmpty else { return credibilityScore }
        return claims.reduce(0.0) { $0 + $1.credibilityScore } / Double(claims.count)
    }
    var detectedPlatform: String { platform ?? detectedPlatformFromURL(videoLink) }
    var platformDisplayName: String { platformInfo(for: detectedPlatform).name }
    var platformIcon: String        { platformInfo(for: detectedPlatform).icon }
    var credibilityLevel: CredibilityLevel {
        if credibilityScore >= 0.8 { return .high }
        if credibilityScore >= 0.5 { return .medium }
        return .low
    }
    var averageCredibilityLevel: CredibilityLevel {
        let s = averageCredibilityScore
        if s >= 0.8 { return .high }
        if s >= 0.5 { return .medium }
        return .low
    }
    func toFactCheckItem() -> FactCheckItem {
        FactCheckItem(reelID: id,
                      sourceName: platformDisplayName, sourceIcon: platformIcon,
                      timeAgo: timeAgo, title: title, summary: summary,
                      thumbnailURL: thumbnailUrl.flatMap { URL(string: $0) },
                      credibilityScore: averageCredibilityScore,
                      sources: sources.joined(separator: ", "),
                      verdict: verdict, claims: claims, originalLink: videoLink,
                      datePosted: datePosted, aiGenerated: aiGenerated, aiProbability: aiProbability)
    }
}

struct PublicFeedResponse:       Codable { let reels: [PublicReel]; let pagination: PaginationInfo }
struct CategoryItem:             Identifiable, Codable { var id: String { name }; let name: String; let count: Int }
struct CategoryResponse:         Codable { let categories: [CategoryItem] }
struct SearchResponse:           Codable { let reels: [PublicReel]; let totalCount: Int; let query: String }
struct PersonalizedFeedResponse: Codable { let reels: [PublicReel]; let totalCount: Int; let source: String }
struct PaginationInfo:           Codable { let currentPage, totalPages, totalCount: Int; let hasMore: Bool; let nextCursor: String? }

// MARK: - UserReel

struct UserReel: Identifiable, Codable {
    let id: String
    let title: String
    let link: String
    let status: String
    let thumbnailUrl: String?
    let submittedAt: String
    let claims: [ClaimEntry]
    let engagement: ReelEngagement?
    let errorMessage: String?
    let platform: String?
    let errorType: String?
    let aiGenerated: String?
    let aiProbability: Double?

    var claim: String?               { claims.first?.claim }
    var verdict: String?             { claims.first?.verdict }
    var claimAccuracyRating: String? { claims.first?.claimAccuracyRating }
    var explanation: String?         { claims.first?.explanation }
    var summary: String?             { claims.first?.summary }
    var sources: [String]?           { claims.first?.sources }

    enum CodingKeys: String, CodingKey {
        case id = "uniqueID"
        case title, link, status, thumbnailUrl, submittedAt, claims
        case claim, verdict, explanation, summary, sources
        case claimAccuracyRating = "claim_accuracy_rating"
        case engagement, errorMessage, platform
        case errorType = "error_type"
        case aiGenerated, aiProbability
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id           = try c.decode(String.self, forKey: .id)
        title        = try c.decode(String.self, forKey: .title)
        link         = try c.decode(String.self, forKey: .link)
        status       = try c.decode(String.self, forKey: .status)
        thumbnailUrl = try c.decodeIfPresent(String.self, forKey: .thumbnailUrl)
        submittedAt  = try c.decode(String.self, forKey: .submittedAt)
        engagement   = try c.decodeIfPresent(ReelEngagement.self, forKey: .engagement)
        errorMessage = try c.decodeIfPresent(String.self, forKey: .errorMessage)
        platform     = try c.decodeIfPresent(String.self, forKey: .platform)
        errorType    = try c.decodeIfPresent(String.self, forKey: .errorType)
        aiGenerated  = try c.decodeIfPresent(String.self, forKey: .aiGenerated)
        aiProbability = try c.decodeIfPresent(Double.self, forKey: .aiProbability)
        if let arr = try? c.decodeIfPresent([ClaimEntry].self, forKey: .claims), !arr.isEmpty {
            claims = arr
        } else if let cl  = try? c.decodeIfPresent(String.self,   forKey: .claim),
                  let v   = try? c.decodeIfPresent(String.self,   forKey: .verdict),
                  let car = try? c.decodeIfPresent(String.self,   forKey: .claimAccuracyRating),
                  let sum = try? c.decodeIfPresent(String.self,   forKey: .summary) {
            let exp = (try? c.decodeIfPresent(String.self,   forKey: .explanation)) ?? ""
            let src = (try? c.decodeIfPresent([String].self, forKey: .sources))     ?? []
            claims  = [ClaimEntry(claim: cl, verdict: v, claimAccuracyRating: car,
                                  explanation: exp, summary: sum, sources: src)]
        } else {
            claims = []
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id); try c.encode(title, forKey: .title)
        try c.encode(link, forKey: .link); try c.encode(status, forKey: .status)
        try c.encodeIfPresent(thumbnailUrl, forKey: .thumbnailUrl)
        try c.encode(submittedAt, forKey: .submittedAt); try c.encode(claims, forKey: .claims)
        try c.encodeIfPresent(engagement, forKey: .engagement)
        try c.encodeIfPresent(errorMessage, forKey: .errorMessage)
        try c.encodeIfPresent(platform, forKey: .platform)
        try c.encodeIfPresent(errorType, forKey: .errorType)
        try c.encodeIfPresent(aiGenerated, forKey: .aiGenerated)
        try c.encodeIfPresent(aiProbability, forKey: .aiProbability)
    }

    var timeAgo: String {
        let f = ISO8601DateFormatter()
        guard let d = f.date(from: submittedAt) else { return "Recently" }
        let r = RelativeDateTimeFormatter(); r.unitsStyle = .abbreviated
        return r.localizedString(for: d, relativeTo: Date())
    }
    var displayURL: String { link.count > 50 ? String(link.prefix(47)) + "..." : link }
    var detectedPlatform: String { platform ?? detectedPlatformFromURL(link) }
    var platformDisplayName: String { platformInfo(for: detectedPlatform).name }
    var platformIcon: String        { platformInfo(for: detectedPlatform).icon }
}

struct UserReelsResponse: Codable { let reels: [UserReel]; let totalCount: Int }
