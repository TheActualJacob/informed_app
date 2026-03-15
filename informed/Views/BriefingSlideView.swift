import SwiftUI

// MARK: - BriefingSlideView
// Each page is always exactly one block (matching CMS slide order 1:1).
// Heading/image blocks are solo full-screen. Text/factCheck/editorNote
// are shown as a scrollable card so long content can be read in full.

struct BriefingSlideView: View {
    let blocks: [StoryBlock]
    let storyHeadline: String
    var storyId: String = ""
    var slideIndex: Int = 0
    var totalSlides: Int = 1

    @State private var contentAppeared = false
    @State private var selectedReel: PublicReel?

    private var primaryBlock: StoryBlock { blocks[0] }

    /// Only headings fill the screen solo. Everything else (including images) stacks.
    private var isSolo: Bool {
        blocks.count == 1 && primaryBlock.type == .heading
    }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 72) // chrome clearance (progress bar + safe area)

                // Faint story watermark
                Text(storyHeadline.uppercased())
                    .font(.custom("Inter-Bold", size: 9))
                    .tracking(1.8)
                    .foregroundStyle(.white.opacity(0.30))
                    .lineLimit(1)
                    .padding(.horizontal, 20)

                if isSolo {
                    Spacer()
                    soloContent
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 10)
                    Spacer()
                    Spacer().frame(height: 90)
                } else {
                    stackedContent
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 28)
                }
            }
        }
        .onAppear {
            contentAppeared = false
            withAnimation(.spring(response: 0.5, dampingFraction: 0.84).delay(0.06)) {
                contentAppeared = true
            }
        }
        .sheet(item: $selectedReel) { reel in
            NavigationStack { PublicReelDetailView(reel: reel) }
        }
    }

    // MARK: - Solo layout (heading / image)

    @ViewBuilder
    private var soloContent: some View {
        switch primaryBlock.type {
        case .heading: headingView(primaryBlock)
        default:       EmptyView()
        }
    }

    // MARK: - Stacked scrollable layout

    private var stackedContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
                ForEach(blocks) { block in
                    blockCard(block)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 114)
        }
    }

    @ViewBuilder
    private func blockCard(_ block: StoryBlock) -> some View {
        switch block.type {
        case .text:       textCard(block)
        case .editorNote: editorNoteCard(block)
        case .factCheck:  factCheckCard(block)
        case .inDepth:    inDepthCard(block)
        case .image:      imageCard(block)
        case .diagram:    DiagramCardView(storyId: storyId, articleText: block.text ?? "", preloadedSvg: block.svgContent)
        default:          EmptyView()
        }
    }

    // MARK: - Image card (inline supplementary)

    private func imageCard(_ block: StoryBlock) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let urlStr = block.imageUrl, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Rectangle().fill(.white.opacity(0.06))
                            .overlay(ProgressView().tint(.white.opacity(0.35)))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .clipped()
            }
            if let caption = block.caption, !caption.isEmpty {
                Text(caption)
                    .font(.custom("Inter-Regular", size: 12))
                    .foregroundStyle(.white.opacity(0.48))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.09), lineWidth: 1)
        )
    }

    // MARK: - In-depth card

    private func inDepthCard(_ block: StoryBlock) -> some View {
        let links = extractLinks(from: block.text ?? "")
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.indigo)
                Text("IN-DEPTH")
                    .font(.custom("Inter-Bold", size: 10))
                    .tracking(1.5)
                    .foregroundStyle(Color.indigo)
                Spacer()
            }
            .padding(.bottom, 14)

            Text(styledBodyText(block, accent: Color.indigo))
                .font(.custom("Inter-Regular", size: 17))
                .tint(Color.indigo) // Ensure links get colored correctly
                .foregroundColor(.white.opacity(0.93))
                .lineSpacing(8)

            if !links.isEmpty {
                sourcePills(links, accent: Color.indigo)
                    .padding(.top, 16)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.indigo.opacity(0.12))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.indigo.opacity(0.30), lineWidth: 1)
                )
        )
    }

    // MARK: - Text card

    private func textCard(_ block: StoryBlock) -> some View {
        let links = extractLinks(from: block.text ?? "")
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Capsule()
                    .fill(Color.brandTeal)
                    .frame(width: 3, height: 18)
                Text("BRIEFING")
                    .font(.custom("Inter-Bold", size: 10))
                    .tracking(1.5)
                    .foregroundStyle(Color.brandTeal)
            }
            .padding(.bottom, 14)

            Text(styledBodyText(block, accent: Color.brandTeal))
                .font(.custom("Inter-Regular", size: 19))
                .tint(Color.brandTeal) // Ensure links get colored correctly
                .foregroundColor(.white.opacity(0.93))
                .lineSpacing(8)

            if !links.isEmpty {
                sourcePills(links, accent: Color.brandTeal)
                    .padding(.top, 16)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(.white.opacity(0.15), lineWidth: 1.5)
                )
        )
    }

    // MARK: - Editor Note card

    private func editorNoteCard(_ block: StoryBlock) -> some View {
        let links = extractLinks(from: block.text ?? "")
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: "pencil.and.outline")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.brandYellow.opacity(0.85))
                Text("EDITOR'S NOTE")
                    .font(.custom("Inter-Bold", size: 10))
                    .tracking(1.4)
                    .foregroundStyle(Color.brandYellow.opacity(0.85))
                Spacer()
            }
            .padding(.bottom, 14)

            Text(styledBodyText(block, accent: Color.brandYellow))
                .font(.custom("Inter-Regular", size: 18))
                .italic()
                .tint(Color.brandYellow) // Ensure links get colored correctly
                .foregroundColor(.white.opacity(0.88))
                .lineSpacing(7)

            if !links.isEmpty {
                sourcePills(links, accent: Color.brandYellow)
                    .padding(.top, 16)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.brandYellow.opacity(0.10))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.brandYellow.opacity(0.25), lineWidth: 1)
                )
        )
    }

    // MARK: - Fact Check card

    private func factCheckCard(_ block: StoryBlock) -> some View {
        Group {
            if let reel = block.factCheck {
                let firstClaim = reel.claims.first
                let verdict = firstClaim?.verdict ?? ""
                let vColor = verdictColor(for: verdict)

                Button { selectedReel = reel } label: {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header row
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.brandTeal)
                            Text("FACT CHECK")
                                .font(.custom("Inter-Bold", size: 10))
                                .tracking(1.2)
                                .foregroundStyle(Color.brandTeal)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.30))
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        .padding(.bottom, 10)

                        // Thumbnail
                        if let thumbStr = reel.thumbnailUrl, let thumbUrl = URL(string: thumbStr) {
                            AsyncImage(url: thumbUrl) { phase in
                                switch phase {
                                case .success(let img):
                                    img.resizable().scaledToFill()
                                default:
                                    Rectangle().fill(.white.opacity(0.04))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 168)
                            .clipped()
                        }

                        // Title + claim
                        VStack(alignment: .leading, spacing: 6) {
                            Text(reel.title)
                                .font(.custom("Inter-SemiBold", size: 15))
                                .foregroundColor(.white)
                                .lineLimit(3)
                            if let claim = firstClaim, !claim.claim.isEmpty {
                                Text(claim.claim)
                                    .font(.custom("Inter-Regular", size: 13))
                                    .foregroundStyle(.white.opacity(0.55))
                                    .lineLimit(2)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 14)

                        // Verdict strip — bottom
                        HStack(spacing: 8) {
                            Image(systemName: verdictIcon(for: verdict))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(vColor)
                            Text(verdict.isEmpty ? "UNVERIFIED" : verdict.uppercased())
                                .font(.custom("GreycliffCF-Bold", size: 15))
                                .foregroundStyle(vColor)
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)
                            Spacer()
                            Text("TAP FOR DETAILS")
                                .font(.custom("Inter-Bold", size: 9))
                                .tracking(1.2)
                                .foregroundStyle(.white.opacity(0.28))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .background(vColor.opacity(0.09))
                    }
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(vColor.opacity(0.22), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            } else {
                Text("Fact check unavailable")
                    .font(.custom("Inter-Regular", size: 14))
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
    }

    // MARK: - Solo views

    private func headingView(_ block: StoryBlock) -> some View {
        VStack(spacing: 22) {
            Text(block.text ?? "")
                .font(.custom("GreycliffCF-Bold", size: 36))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.55)
                .lineSpacing(4)
                .shadow(color: .black.opacity(0.15), radius: 10, y: 5)

            RoundedRectangle(cornerRadius: 1.5)
                .fill(.white.opacity(0.28))
                .frame(width: 40, height: 3)
        }
        .padding(.horizontal, 30)
    }

    private func imageView(_ block: StoryBlock) -> some View {
        VStack(spacing: 14) {
            if let text = block.text, !text.isEmpty {
                Text(text)
                    .font(.custom("GreycliffCF-Bold", size: 30))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.6), radius: 8, y: 4)
                    .minimumScaleFactor(0.6)
            }
            if let caption = block.caption, !caption.isEmpty {
                Text(caption)
                    .font(.custom("Inter-Regular", size: 13))
                    .foregroundStyle(.white.opacity(0.62))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Inline citation styling
    // Converts markdown link runs ([label](url)) into accent-coloured, semi-bold
    // inline text. The links remain natively clickable.
    private func styledBodyText(_ block: StoryBlock, accent: Color) -> AttributedString {
        guard var raw = block.text else { return AttributedString() }

        // Ensure literal escaped "\n" sequences are turned into real newlines
        raw = raw.replacingOccurrences(of: "\\n", with: "\n")

        // Use full markdown parsing so double-newlines become paragraph breaks;
        // fall back to inline-only, then plain text.
        var attributed: AttributedString
        if let full = try? AttributedString(markdown: raw, options: .init(interpretedSyntax: .full)) {
            attributed = full
        } else if let inline = try? AttributedString(markdown: raw, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            attributed = inline
        } else {
            attributed = AttributedString(raw)
        }
        
        // Process in reverse to safely modify string lengths without invalidating ranges
        let linkRanges = attributed.runs.compactMap { $0.link != nil ? $0.range : nil }.reversed()
        
        for range in linkRanges {
            // Remove background highlights & underlines
            attributed[range].backgroundColor = nil
            attributed[range].underlineStyle = nil
            attributed[range].foregroundColor = accent
            attributed[range].font = .custom("Inter-SemiBold", size: 17)
            
            // If the link text is just a number (like [1]), put a circle around it (①)
            let textStr = String(attributed.characters[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if let num = Int(textStr), num >= 1, num <= 20 {
                if let scalar = UnicodeScalar(0x245F + num) {
                    var circledRep = AttributedString(String(Character(scalar)))
                    circledRep.link = attributed[range].link
                    circledRep.foregroundColor = accent
                    circledRep.font = .custom("Inter-SemiBold", size: 18)
                    attributed.replaceSubrange(range, with: circledRep)
                }
            }
        }
        
        return attributed
    }

    // MARK: - Source Pills

    private func sourcePills(_ links: [(label: String, url: URL)], accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(height: 1)
            Text("SOURCES")
                .font(.custom("Inter-Bold", size: 9))
                .tracking(1.4)
                .foregroundStyle(.white.opacity(0.35))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(links.enumerated()), id: \.offset) { _, link in
                        Link(destination: link.url) {
                            HStack(spacing: 5) {
                                Image(systemName: "link")
                                    .font(.system(size: 9, weight: .semibold))
                                Text(link.label)
                                    .font(.custom("Inter-SemiBold", size: 12))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(accent.opacity(0.9))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(accent.opacity(0.08), in: Capsule())
                            .overlay(Capsule().stroke(accent.opacity(0.18), lineWidth: 1))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Link Extraction

    private func extractLinks(from raw: String) -> [(label: String, url: URL)] {
        guard raw.contains("[") else { return [] }
        guard let pattern = try? NSRegularExpression(pattern: #"\[([^\]]+)\]\(([^)]+)\)"#) else { return [] }
        var result: [(label: String, url: URL)] = []
        for match in pattern.matches(in: raw, range: NSRange(raw.startIndex..., in: raw)) {
            guard let labelRange = Range(match.range(at: 1), in: raw),
                  let urlRange   = Range(match.range(at: 2), in: raw),
                  let url        = URL(string: String(raw[urlRange])) else { continue }
            result.append((label: String(raw[labelRange]), url: url))
        }
        return result
    }

    // MARK: - Backgrounds

    @ViewBuilder
    private var background: some View {
        // Mixed pages always get the neutral dark gradient.
        if blocks.count == 1 {
            switch primaryBlock.type {
            case .image:     darkBase
            case .heading:   headingBackground
            case .factCheck: factCheckBackground
            case .editorNote:
                ZStack {
                    Color(red: 0.06, green: 0.05, blue: 0.02)
                    LinearGradient(
                        colors: [Color.brandYellow.opacity(0.07), .clear],
                        startPoint: .top, endPoint: .center
                    )
                }
            case .inDepth:
                ZStack {
                    Color(red: 0.04, green: 0.04, blue: 0.10)
                    LinearGradient(
                        colors: [Color.indigo.opacity(0.14), .clear],
                        startPoint: .top, endPoint: .center
                    )
                }
            default:
                darkBase
            }
        } else {
            darkBase
        }
    }

    @ViewBuilder
    private var imageBackground: some View {
        if let urlStr = primaryBlock.imageUrl, let url = URL(string: urlStr) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                        .overlay(
                            LinearGradient(
                                colors: [.black.opacity(0.15), .black.opacity(0.65)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                default:
                    darkBase
                }
            }
        } else {
            darkBase
        }
    }

    private var headingBackground: some View {
        ZStack {
            LinearGradient(
                colors: [Color.brandTeal.opacity(0.88), Color.brandBlue],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            Circle()
                .fill(.white.opacity(0.04))
                .frame(width: 380, height: 380)
                .offset(x: 140, y: -140)
            Circle()
                .fill(.white.opacity(0.025))
                .frame(width: 260, height: 260)
                .offset(x: -90, y: 240)
        }
    }

    private var factCheckBackground: some View {
        let c = verdictColor(for: primaryBlock.factCheck?.claims.first?.verdict)
        return ZStack {
            Color(white: 0.03)
            LinearGradient(
                colors: [c.opacity(0.2), .clear],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.55)
            )
        }
    }

    private var darkBase: some View {
        LinearGradient(
            colors: [Color(white: 0.08), Color(white: 0.02)],
            startPoint: .top, endPoint: .bottom
        )
    }

    // MARK: - Helpers

    private func verdictColor(for verdict: String?) -> Color {
        let v = (verdict ?? "").lowercased()
        if v.contains("true") || v.contains("correct")     { return .brandGreen  }
        if v.contains("false") || v.contains("incorrect")  { return .brandRed    }
        if v.contains("misleading") || v.contains("context") { return .brandYellow }
        return .brandTeal
    }

    private func verdictIcon(for verdict: String?) -> String {
        let v = (verdict ?? "").lowercased()
        if v.contains("true") || v.contains("correct")     { return "checkmark.circle.fill"         }
        if v.contains("false") || v.contains("incorrect")  { return "xmark.circle.fill"             }
        if v.contains("misleading") || v.contains("context") { return "exclamationmark.triangle.fill" }
        return "questionmark.circle.fill"
    }
}


