import Foundation

/// Fetches SVG infographic diagrams from the backend, with actor-based caching.
/// Uses detached tasks so in-flight requests survive SwiftUI view lifecycle changes.
final class DiagramService {
    static let shared = DiagramService()
    private let session: URLSession
    private let lock = NSLock()
    private var inFlight: [String: Task<String, Error>] = [:]

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        session = URLSession(configuration: config)
    }

    /// Returns an SVG string for the given story. Checks cache first, then calls the backend.
    /// Coalesces duplicate requests — if a fetch is already in-flight for this storyId,
    /// callers await the existing task instead of starting a new one.
    func fetchDiagram(storyId: String, articleText: String) async throws -> String {
        // Check cache
        if let cached = await DiagramCacheActor.shared.get(storyId: storyId) {
            return cached
        }

        // Coalesce: reuse in-flight task or create a new detached one
        let task: Task<String, Error> = lock.withLock {
            if let existing = inFlight[storyId] {
                return existing
            }
            let urlSession = self.session
            let newTask = Task<String, Error>.detached {
                guard let url = URL(string: Config.Endpoints.generateDiagram) else {
                    throw NetworkError.invalidURL
                }
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                let body: [String: String] = ["story_id": storyId, "text": articleText]
                request.httpBody = try JSONSerialization.data(withJSONObject: body)

                let (data, response) = try await urlSession.data(for: request)

                guard let http = response as? HTTPURLResponse,
                      (200...299).contains(http.statusCode) else {
                    throw NetworkError.serverError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)
                }
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let svg = json["svg"] as? String, !svg.isEmpty else {
                    throw NetworkError.decodingError("No SVG in diagram response")
                }
                await DiagramCacheActor.shared.set(storyId: storyId, svg: svg)
                return svg
            }
            inFlight[storyId] = newTask
            return newTask
        }

        do {
            let result = try await task.value
            lock.withLock { inFlight[storyId] = nil }
            return result
        } catch {
            lock.withLock { inFlight[storyId] = nil }
            throw error
        }
    }
}
