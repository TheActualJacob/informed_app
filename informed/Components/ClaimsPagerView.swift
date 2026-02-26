 //
//  ClaimsPagerView.swift
//  informed
//
//  Swipeable pager for up to 3 fact-checked claims inside the detail view.
//

import SwiftUI

// MARK: - ClaimsPagerView

/// Displays 1-3 ClaimEntry objects as horizontally swipeable pages.
/// When there is only one claim the pager chrome (dots, counter) is hidden.
struct ClaimsPagerView: View {
    let claims: [ClaimEntry]
    @State private var selectedIndex: Int = 0
    /// Tracks per-page heights so the container can match the tallest visible page.
    @State private var pageHeights: [Int: CGFloat] = [:]
    /// Pulses the "swipe" chevrons to draw attention until the user swipes once.
    @State private var hasSwipedOnce: Bool = false
    @State private var arrowPulse: Bool = false

    private var currentHeight: CGFloat {
        pageHeights[selectedIndex] ?? 600
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {

            // ── Header bar (only when multi-claim) ──────────────────────────
            if claims.count > 1 {
                ZStack {
                    // Background pill
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                        .fill(Color.secondary.opacity(0.08))

                    HStack(spacing: 0) {
                        // Left chevron — greyed when on first page
                        Button {
                            guard selectedIndex > 0 else { return }
                            HapticManager.lightImpact()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                selectedIndex -= 1
                            }
                        } label: {
                            Image(systemName: "chevron.left.circle.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(selectedIndex > 0 ? .brandBlue : .secondary.opacity(0.3))
                                .scaleEffect(arrowPulse && !hasSwipedOnce && selectedIndex == 0 ? 1.15 : 1.0)
                                .padding(.leading, 10)
                                .padding(.vertical, 10)      // expand hit area vertically
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(selectedIndex == 0)

                        Spacer()

                        // Center label
                        VStack(spacing: 2) {
                            HStack(spacing: 5) {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("Claim \(selectedIndex + 1) of \(claims.count)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                            }
                            Text("Swipe to see all claims")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        // Right chevron — greyed when on last page
                        Button {
                            guard selectedIndex < claims.count - 1 else { return }
                            HapticManager.lightImpact()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                selectedIndex += 1
                            }
                        } label: {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(selectedIndex < claims.count - 1 ? .brandBlue : .secondary.opacity(0.3))
                                .scaleEffect(arrowPulse && !hasSwipedOnce && selectedIndex == 0 ? 1.15 : 1.0)
                                .padding(.trailing, 10)
                                .padding(.vertical, 10)      // expand hit area vertically
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(selectedIndex == claims.count - 1)
                    }
                    .padding(.vertical, 10)
                }
                .frame(height: 52)
                .onAppear {
                    // Pulse the arrows twice so users notice the swipe affordance
                    withAnimation(.easeInOut(duration: 0.5).repeatCount(3, autoreverses: true).delay(0.4)) {
                        arrowPulse = true
                    }
                }
            }

            // ── Pager ────────────────────────────────────────────────────────
            TabView(selection: $selectedIndex) {
                ForEach(Array(claims.enumerated()), id: \.offset) { index, claim in
                    ClaimPageView(claim: claim, index: index, total: claims.count)
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: PageHeightKey.self,
                                    value: [index: geo.size.height]
                                )
                            }
                        )
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: currentHeight)
            .onPreferenceChange(PageHeightKey.self) { heights in
                for (k, v) in heights { pageHeights[k] = v }
            }
            .animation(.easeInOut(duration: 0.25), value: selectedIndex)
            .onChange(of: selectedIndex) {
                if !hasSwipedOnce { hasSwipedOnce = true; arrowPulse = false }
            }

            // ── Dot indicators ───────────────────────────────────────────────
            if claims.count > 1 {
                HStack(spacing: 8) {
                    ForEach(0..<claims.count, id: \.self) { i in
                        Capsule()
                            .fill(i == selectedIndex
                                  ? claims[i].credibilityLevel.color
                                  : Color.secondary.opacity(0.25))
                            .frame(width: i == selectedIndex ? 20 : 7,
                                   height: 7)
                            .animation(.spring(response: 0.3), value: selectedIndex)
                    }
                }
            }
        }
    }
}

// MARK: - Page Height Preference Key

private struct PageHeightKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { max($0, $1) })
    }
}

// MARK: - ClaimPageView

/// One page — claim, verdict/accuracy, summary, explanation, sources.
struct ClaimPageView: View {
    let claim: ClaimEntry
    let index: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {

            // Claim
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Label(total > 1 ? "Claim \(index + 1)" : "The Claim",
                      systemImage: "quote.bubble.fill")
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(claim.claim)
                    .font(.body)
                    .foregroundColor(.primary.opacity(0.85))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.blue.opacity(0.08))
            .cornerRadius(Theme.CornerRadius.md)

            // Verdict + Accuracy
            HStack(spacing: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Verdict")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    Text(claim.verdict)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(claim.credibilityLevel.color)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Accuracy Rating")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    Text(claim.claimAccuracyRating)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(claim.credibilityLevel.color)
                }
            }
            .padding(Theme.Spacing.lg)
            .background(claim.credibilityLevel.color.opacity(0.08))
            .cornerRadius(Theme.CornerRadius.md)

            // Summary
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Label("Summary", systemImage: "text.alignleft")
                    .font(.headline)
                Text(claim.summary)
                    .font(.body)
                    .foregroundColor(.primary.opacity(0.8))
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.green.opacity(0.08))
            .cornerRadius(Theme.CornerRadius.md)

            // Explanation
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Label("Explanation", systemImage: "info.circle.fill")
                    .font(.headline)
                if !claim.explanation.isEmpty {
                    Text(claim.explanation)
                        .font(.body)
                        .foregroundColor(.primary.opacity(0.8))
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("No detailed explanation available for this claim.")
                        .font(.body)
                        .foregroundColor(.gray.opacity(0.8))
                        .italic()
                }
            }
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cardBackground)
            .cornerRadius(Theme.CornerRadius.md)

            // Sources
            if !claim.sources.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Label("Sources", systemImage: "link")
                        .font(.headline)
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(claim.sources.indices, id: \.self) { i in
                            Button(action: {
                                HapticManager.lightImpact()
                                if let url = URL(string: claim.sources[i]) {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                HStack(spacing: Theme.Spacing.sm) {
                                    Image(systemName: "link.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(.brandBlue)
                                    Text(extractDomainName(from: claim.sources[i]))
                                        .font(.caption)
                                        .foregroundColor(.brandBlue)
                                        .lineLimit(1)
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .font(.caption2)
                                        .foregroundColor(.brandBlue.opacity(0.6))
                                }
                                .padding(.vertical, Theme.Spacing.sm)
                                .padding(.horizontal, Theme.Spacing.md)
                                .background(Color.brandBlue.opacity(0.05))
                                .cornerRadius(Theme.CornerRadius.sm)
                            }
                        }
                    }
                }
                .padding(Theme.Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.cardBackground)
                .cornerRadius(Theme.CornerRadius.md)
            }
        }
        // Small horizontal inset so content doesn't bleed into pager edge
        .padding(.horizontal, 2)
    }
}

// MARK: - Preview

#if DEBUG
struct ClaimsPagerView_Previews: PreviewProvider {
    static let sampleClaims = [
        ClaimEntry(
            claim: "Drinking coffee every day reduces the risk of type-2 diabetes by 30%.",
            verdict: "Mostly True",
            claimAccuracyRating: "78%",
            explanation: "Multiple large-scale studies have found a correlation between moderate coffee consumption and reduced diabetes risk, though causality is not fully established. The figure of 30% comes from a 2014 meta-analysis but varies widely across studies.",
            summary: "Evidence supports a modest protective effect of daily coffee on type-2 diabetes risk.",
            sources: ["https://pubmed.ncbi.nlm.nih.gov/12345678", "https://www.nejm.org/doi/abc"]
        ),
        ClaimEntry(
            claim: "The video was filmed in 2019, not 2024 as claimed.",
            verdict: "True",
            claimAccuracyRating: "95%",
            explanation: "Metadata from the original upload and background landmarks confirm the footage predates 2024 by at least five years.",
            summary: "The footage is demonstrably from 2019 based on multiple independent verification methods.",
            sources: ["https://www.snopes.com/fact-check/example"]
        )
    ]

    static var previews: some View {
        ScrollView {
            ClaimsPagerView(claims: sampleClaims)
                .padding()
        }
    }
}
#endif
