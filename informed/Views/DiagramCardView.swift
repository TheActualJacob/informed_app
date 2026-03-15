import SwiftUI

/// Displays an AI-generated SVG infographic for a story.
/// Lazily fetches the diagram when the view appears, with loading/success/error states.
struct DiagramCardView: View {
    let storyId: String
    let articleText: String

    @State private var svg: String?
    @State private var isLoading = false
    @State private var hasFailed = false

    var body: some View {
        Group {
            if let svg {
                VStack(spacing: 0) {
                    // Header
                    HStack(spacing: 8) {
                        Image(systemName: "chart.bar.xaxis.ascending")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Visual Summary")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } else if isLoading {
                // Skeleton shimmer
                VStack(spacing: 12) {
                    HStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 120, height: 14)
                        Spacer()
                    }
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 240)
                }
                .padding(16)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shimmering()
            }
            // If hasFailed, render nothing — silent fail
        }
        .task {
            guard svg == nil, !isLoading, !hasFailed else { return }
            guard !articleText.isEmpty else { hasFailed = true; return }
            isLoading = true
            do {
                svg = try await DiagramService.shared.fetchDiagram(storyId: storyId, articleText: articleText)
                print("📊 Diagram loaded for \(storyId) (\(svg?.count ?? 0) chars)")
            } catch {
                print("📊 Diagram failed for \(storyId): \(error)")
                hasFailed = true
            }
            isLoading = false
        }
    }
}
