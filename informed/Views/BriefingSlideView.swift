import SwiftUI

// MARK: - BriefingSlideView
// Each "page" may contain one or more blocks.
// Heading/image blocks are always solo and centered full-screen.
// All other block types (text, editorNote, factCheck) are stacked in a
// scrollable card column so the editor can group related content on one page.

struct BriefingSlideView: View {
    let blocks: [StoryBlock]
    let storyHeadline: String
    var slideIndex: Int = 0
    var totalSlides: Int = 1

    @State private var contentAppeared = false

    private var primaryBlock: StoryBlock { blocks[0] }

    /// Heading/image always fill the screen solo. Everything else stacks.
    private var isSolo: Bool {
        blocks.count == 1 && (primaryBlock.type == .heading || primaryBlock.type == .image)
    }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 58) // chrome clearance

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
    }

    // MARK: - Solo layout (heading / image)

    @ViewBuilder
    private var soloContent: some View {
        switch primaryBlock.type {
        case .heading: headingView(primaryBlock)
        case .image:   imageView(primaryBlock)
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
        default:          EmptyView()
        }
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
                .foregroundColor(.white.opacity(0.93))
                .lineSpacing(6)

            if !links.isEmpty {
                sourcePills(links, accent: Color.brandTeal)
                    .padding(.top, 14)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(.white.opacity(0.07), lineWidth: 1)
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
                .foregroundColor(.white.opacity(0.88))
                .lineSpacing(5)

            if !links.isEmpty {
                sourcePills(links, accent: Color.brandYellow)
                    .padding(.top, 14)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.brandYellow.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.brandYellow.opacity(0.12), lineWidth: 1)
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

                VStack(spacing: 10) {
                    // Verdict strip
                    HStack(spacing: 10) {
                        Image(systemName: verdictIcon(for: verdict))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(vColor)
                        Text(verdict.isEmpty ? "UNVERIFIED" : verdict.uppercased())
                            .font(.custom("GreycliffCF-Bold", size: 20))
                            .foregroundStyle(vColor)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(vColor.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(vColor.opacity(0.18), lineWidth: 1)
                            )
                    )

                    // Details card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.brandTeal)
                            Text("FACT CHECK")
                                .font(.custom("Inter-Bold", size: 10))
                                .tracking(1.2)
                                .foregroundStyle(Color.brandTeal)
                        }
                        Text(reel.title)
                            .font(.custom("Inter-SemiBold", size: 15))
                            .foregroundColor(.white)
                            .lineLimit(3)
                        if let claim = firstClaim, !claim.claim.isEmpty {
                            Text(claim.claim)
                                .font(.custom("Inter-Regular", size: 13))
                                .foregroundStyle(.white.opacity(0.58))
                                .lineLimit(3)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(.white.opacity(0.07), lineWidth: 1)
                            )
                    )
                }
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
    // inline text. The .link attribute is removed so they don't look like bare
    // web hyperlinks — the source pills below serve as the actual tap targets.
    private func styledBodyText(_ block: StoryBlock, accent: Color) -> AttributedString {
        guard let raw = block.text else { return AttributedString() }
        var attributed = (try? AttributedString(
            markdown: raw,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(raw)
        for run in attributed.runs {
            if run.link != nil {
                attributed[run.range].link = nil
                attributed[run.range].foregroundColor = accent
                attributed[run.range].font = .custom("Inter-SemiBold", size: 19)
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
            case .image:     imageBackground
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


