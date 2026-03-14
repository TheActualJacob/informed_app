import SwiftUI

struct BriefingSlideView: View {
    let block: StoryBlock
    let storyHeadline: String
    var slideIndex: Int = 0
    var totalSlides: Int = 1

    @State private var contentAppeared = false

    // Text and fact-check cards sit at the bottom; heading/image are centered
    private var isBottomAnchored: Bool {
        block.type == .text || block.type == .editorNote || block.type == .factCheck
    }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Space for chrome (progress bar + close button)
                Spacer().frame(height: 58)

                // Faint story watermark
                Text(storyHeadline.uppercased())
                    .font(.custom("Inter-Bold", size: 9))
                    .tracking(1.8)
                    .foregroundStyle(.white.opacity(0.30))
                    .lineLimit(1)
                    .padding(.horizontal, 20)

                if isBottomAnchored {
                    Spacer()
                    contentView
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 30)
                    Spacer().frame(height: 100)
                } else {
                    Spacer()
                    contentView
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 10)
                    Spacer()
                    Spacer().frame(height: 90)
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

    // MARK: - Backgrounds

    @ViewBuilder
    private var background: some View {
        switch block.type {
        case .image:
            imageBackground
        case .heading:
            headingBackground
        case .factCheck:
            factCheckBackground
        case .editorNote:
            ZStack {
                Color(red: 0.06, green: 0.05, blue: 0.02)
                LinearGradient(
                    colors: [Color.brandYellow.opacity(0.07), .clear],
                    startPoint: .top, endPoint: .center
                )
            }
        default:
            LinearGradient(
                colors: [Color(white: 0.08), Color(white: 0.02)],
                startPoint: .top, endPoint: .bottom
            )
        }
    }

    @ViewBuilder
    private var imageBackground: some View {
        if let urlStr = block.imageUrl, let url = URL(string: urlStr) {
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
        let c = verdictColor(for: block.factCheck?.claims.first?.verdict)
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

    // MARK: - Content Routing

    @ViewBuilder
    private var contentView: some View {
        switch block.type {
        case .heading:    headingSlide
        case .text:       textSlide
        case .editorNote: editorNoteSlide
        case .image:      imageSlide
        case .factCheck:  factCheckSlide
        }
    }

    // MARK: Heading — centered, large display

    private var headingSlide: some View {
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

    // MARK: Text — bottom frosted card

    private var textSlide: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Capsule()
                    .fill(Color.brandTeal)
                    .frame(width: 3, height: 18)
                Text("BRIEFING")
                    .font(.custom("Inter-Bold", size: 10))
                    .tracking(1.5)
                    .foregroundStyle(Color.brandTeal)
            }
            .padding(.bottom, 16)

            Text(block.attributedText)
                .font(.custom("Inter-Regular", size: 21))
                .foregroundColor(.white.opacity(0.93))
                .lineSpacing(7)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.white.opacity(0.07), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
    }

    // MARK: Editor Note — warm bottom card

    private var editorNoteSlide: some View {
        VStack(alignment: .leading, spacing: 0) {
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
            .padding(.bottom, 16)

            Text(block.attributedText)
                .font(.custom("Inter-Regular", size: 19))
                .italic()
                .foregroundColor(.white.opacity(0.88))
                .lineSpacing(6)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.brandYellow.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.brandYellow.opacity(0.12), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
    }

    // MARK: Image — centered title over full-bleed

    private var imageSlide: some View {
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

    // MARK: Fact Check — verdict hero + details card

    private var factCheckSlide: some View {
        Group {
            if let reel = block.factCheck {
                let firstClaim = reel.claims.first
                let verdict = firstClaim?.verdict ?? ""
                let vColor = verdictColor(for: verdict)

                VStack(spacing: 14) {
                    // Verdict hero pill
                    HStack(spacing: 10) {
                        Image(systemName: verdictIcon(for: verdict))
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(vColor)

                        Text(verdict.isEmpty ? "UNVERIFIED" : verdict.uppercased())
                            .font(.custom("GreycliffCF-Bold", size: 26))
                            .foregroundStyle(vColor)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                    }
                    .padding(.vertical, 18)
                    .padding(.horizontal, 28)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(vColor.opacity(0.10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(vColor.opacity(0.22), lineWidth: 1)
                            )
                    )

                    // Details card
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.brandTeal)
                            Text("FACT CHECK")
                                .font(.custom("Inter-Bold", size: 10))
                                .tracking(1.2)
                                .foregroundStyle(Color.brandTeal)
                            Spacer()
                        }

                        Text(reel.title)
                            .font(.custom("Inter-SemiBold", size: 16))
                            .foregroundColor(.white)
                            .lineLimit(3)

                        if let claim = firstClaim, !claim.claim.isEmpty {
                            Text(claim.claim)
                                .font(.custom("Inter-Regular", size: 13))
                                .foregroundStyle(.white.opacity(0.60))
                                .lineLimit(3)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(.white.opacity(0.07), lineWidth: 1)
                            )
                    )
                }
                .padding(.horizontal, 16)
            } else {
                Text("Fact check unavailable")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Helpers

    private func verdictColor(for verdict: String?) -> Color {
        let v = (verdict ?? "").lowercased()
        if v.contains("true") || v.contains("correct") { return .brandGreen }
        if v.contains("false") || v.contains("incorrect") { return .brandRed }
        if v.contains("misleading") || v.contains("context") { return .brandYellow }
        return .brandTeal
    }

    private func verdictIcon(for verdict: String?) -> String {
        let v = (verdict ?? "").lowercased()
        if v.contains("true") || v.contains("correct") { return "checkmark.circle.fill" }
        if v.contains("false") || v.contains("incorrect") { return "xmark.circle.fill" }
        if v.contains("misleading") || v.contains("context") { return "exclamationmark.triangle.fill" }
        return "questionmark.circle.fill"
    }
}
