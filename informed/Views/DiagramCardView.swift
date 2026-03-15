import SwiftUI

/// Displays an AI-generated SVG infographic for a story.
/// Uses pre-generated SVG when available, falls back to on-demand fetch.
struct DiagramCardView: View {
    let storyId: String
    let articleText: String
    let preloadedSvg: String?

    @State private var svg: String?
    @State private var loadState: LoadState = .loading

    private enum LoadState {
        case loading, loaded, failed
    }

    init(storyId: String, articleText: String, preloadedSvg: String? = nil) {
        self.storyId = storyId
        self.articleText = articleText
        self.preloadedSvg = preloadedSvg
    }

    var body: some View {
        Group {
            switch loadState {
            case .loading:
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "chart.bar.xaxis.ascending")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                        Text("Generating visual…")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                        Spacer()
                    }
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 240)
                        .overlay(ProgressView().tint(.white.opacity(0.4)))
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                )

            case .loaded:
                if let svg {
                    VStack(spacing: 0) {
                        HStack(spacing: 8) {
                            Image(systemName: "chart.bar.xaxis.ascending")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                            Text("Visual Summary")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 8)

                        SVGWebView(svg: svg)
                            .frame(height: 240)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal, 12)
                            .padding(.bottom, 12)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                }

            case .failed:
                EmptyView()
            }
        }
        .task {
            // Use pre-generated SVG if available — instant load
            if let preloadedSvg, !preloadedSvg.isEmpty {
                svg = preloadedSvg
                loadState = .loaded
                print("📊 Diagram instant-loaded for \(storyId) (\(preloadedSvg.count) chars)")
                return
            }
            guard svg == nil, loadState == .loading else { return }
            guard !articleText.isEmpty else {
                print("📊 Diagram skipped for \(storyId): empty text")
                loadState = .failed
                return
            }
            print("📊 Diagram fetching on-demand for \(storyId)…")
            do {
                svg = try await DiagramService.shared.fetchDiagram(storyId: storyId, articleText: articleText)
                print("📊 Diagram loaded for \(storyId) (\(svg?.count ?? 0) chars)")
                loadState = .loaded
            } catch is CancellationError {
                print("📊 Diagram task cancelled for \(storyId), will retry on reappear")
            } catch {
                print("📊 Diagram failed for \(storyId): \(error)")
                loadState = .failed
            }
        }
    }
}
