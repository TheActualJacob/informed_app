//
//  NewsFeedItem.swift
//  informed
//

import Foundation

// MARK: - Story (curated editorial walkthrough)

struct Story: Identifiable, Codable {
    let storyId: String
    let headline: String
    let summary: String?
    let coverImageUrl: String?
    let category: String?
    let author: String?
    let publishedAt: String
    let blocks: [StoryBlock]

    var id: String { storyId }
}

// MARK: - Story Block

enum StoryBlockType: String, Codable {
    case text
    case heading
    case image
    case factCheck = "fact_check"
    case editorNote = "editor_note"
    case inDepth = "in_depth"
    case diagram
}

struct StoryBlock: Identifiable, Codable {
    let blockId: String
    let position: Int
    let type: StoryBlockType

    // Text / Heading / Editor note
    let text: String?

    // Image
    let imageUrl: String?
    let caption: String?

    // Fact check embed
    let factCheck: PublicReel?

    // Page break hint — if true, this block always starts a new page
    let pageBreakBefore: Bool

    // Grouping hint — if true, this block is stacked onto the same slide as the block above it
    let attachToPrevious: Bool

    var id: String { blockId }

    /// Parses inline markdown links ([label](url)) so the iOS app can render
    /// citation links as tappable text. Falls back to plain text if parsing fails.
    var attributedText: AttributedString {
        guard let raw = text?.replacingOccurrences(of: "\\n", with: "\n") else { return AttributedString("") }
        if let full = try? AttributedString(markdown: raw, options: .init(interpretedSyntax: .full)) {
            return full
        }
        return (try? AttributedString(
            markdown: raw,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(raw)
    }

    enum CodingKeys: String, CodingKey {
        case blockId, position, type, text, imageUrl, caption, factCheck, pageBreakBefore, attachToPrevious
    }

    init(blockId: String, position: Int, type: StoryBlockType, text: String? = nil,
         imageUrl: String? = nil, caption: String? = nil, factCheck: PublicReel? = nil,
         pageBreakBefore: Bool = false, attachToPrevious: Bool = false) {
        self.blockId = blockId
        self.position = position
        self.type = type
        self.text = text
        self.imageUrl = imageUrl
        self.caption = caption
        self.factCheck = factCheck
        self.pageBreakBefore = pageBreakBefore
        self.attachToPrevious = attachToPrevious
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        blockId  = try c.decode(String.self, forKey: .blockId)
        position = try c.decode(Int.self, forKey: .position)
        type     = try c.decode(StoryBlockType.self, forKey: .type)
        text     = try c.decodeIfPresent(String.self, forKey: .text)
        imageUrl = try c.decodeIfPresent(String.self, forKey: .imageUrl)
        caption  = try c.decodeIfPresent(String.self, forKey: .caption)
        factCheck = try c.decodeIfPresent(PublicReel.self, forKey: .factCheck)
        pageBreakBefore = (try? c.decodeIfPresent(Bool.self, forKey: .pageBreakBefore)) ?? false
        attachToPrevious = (try? c.decodeIfPresent(Bool.self, forKey: .attachToPrevious)) ?? false
    }
}

struct StoriesResponse: Codable {
    let stories: [Story]
}

struct StoryDetailResponse: Codable {
    let story: Story
}

// MARK: - Legacy types kept for existing code

enum NewsFeedItemType: String, Codable {
    case curatedFactCheck = "curated_fact_check"
    case article = "article"
}

struct ArticleData: Codable, Equatable {
    let title: String
    let summary: String
    let body: String
    let author: String
    let headerImageUrl: String?
}

struct NewsFeedItem: Identifiable, Codable {
    let id: String
    let type: NewsFeedItemType
    let publishedAt: Date

    let reelData: PublicReel?
    let articleData: ArticleData?

    init(id: String = UUID().uuidString, type: NewsFeedItemType, publishedAt: Date = Date(), reelData: PublicReel? = nil, articleData: ArticleData? = nil) {
        self.id = id
        self.type = type
        self.publishedAt = publishedAt
        self.reelData = reelData
        self.articleData = articleData
    }
}
