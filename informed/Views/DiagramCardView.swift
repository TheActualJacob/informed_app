import SwiftUI

/// Displays an AI-generated SVG infographic for a story.
/// Lazily fetches the diagram when the view appears, with loading/success/error states.
struct DiagramCardView: View {
    let storyId: String
    let articleText: String

    @State private var svg: String?
    @State private var loadState: LoadState = .loading

    private enum LoadState {
        case loading, loaded, failed
    }

    var body: some View {
        Group {
            switch loadState {
            case .loading:
                // Skeleton shimmer — always visible until fetch completes
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
            guard svg == nil, loadState == .loading else { return }
            guard !articleText.isEmpty else {
                print("📊 Diagram skipped for \(storyId): empty text")
                loadState = .failed
                return
            }
            print("📊 Diagram fetching for \(storyId)…")
            do {
                svg = try await DiagramService.shared.fetchDiagram(storyId: storyId, articleText: articleText)
                print("📊 Diagram loaded for \(storyId) (\(svg?.count ?? 0) chars)")
                loadState = .loaded
            } catch {
                print("📊 Diagram failed for \(storyId): \(error)")
                loadState = .failed
            }
        }
    }
}
