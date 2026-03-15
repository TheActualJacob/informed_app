import Foundation

/// Thread-safe in-memory cache for SVG diagram strings, keyed by story ID.
/// Optionally persists to disk so cached diagrams survive app restarts.
actor DiagramCacheActor {
    static let shared = DiagramCacheActor()

    private var memory: [String: String] = [:]
    private let cacheDir: URL? = {
        try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("diagrams", isDirectory: true)
    }()

    private init() {
        if let dir = cacheDir {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    func get(storyId: String) -> String? {
        if let svg = memory[storyId] { return svg }
        // Fall back to disk
        if let file = diskURL(for: storyId),
           let data = try? Data(contentsOf: file),
           let svg = String(data: data, encoding: .utf8) {
            memory[storyId] = svg
            return svg
        }
        return nil
    }

    func set(storyId: String, svg: String) {
        memory[storyId] = svg
        // Persist to disk
        if let file = diskURL(for: storyId) {
            try? svg.data(using: .utf8)?.write(to: file, options: .atomic)
        }
    }

    private func diskURL(for storyId: String) -> URL? {
        guard let dir = cacheDir else { return nil }
        let safe = storyId.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? storyId
        return dir.appendingPathComponent("\(safe).svg")
    }
}
