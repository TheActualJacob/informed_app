import Foundation

/// Fetches SVG infographic diagrams from the backend, with actor-based caching.
final class DiagramService {
    static let shared = DiagramService()
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config)
    }

    /// Returns an SVG string for the given story. Checks cache first, then calls the backend.
    func fetchDiagram(storyId: String, articleText: String) async throws -> String {
        // Check cache
        if let cached = await DiagramCacheActor.shared.get(storyId: storyId) {
            return cached
        }

        // Build request
        guard let url = URL(string: Config.Endpoints.generateDiagram) else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = ["story_id": storyId, "text": articleText]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw NetworkError.serverError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let svg = json["svg"] as? String, !svg.isEmpty else {
            throw NetworkError.decodingError("No SVG in diagram response")
        }

        // Cache for future use
        await DiagramCacheActor.shared.set(storyId: storyId, svg: svg)
        return svg
    }
}
