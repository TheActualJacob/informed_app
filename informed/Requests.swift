import Foundation

// MARK: - Fact-check submission (async 202 flow)

/// Submits a link for fact-checking. The backend responds 202 immediately with a
/// submission_id. The caller should start polling /api/submission-status/:id and
/// call syncHistoryFromBackend() once status == "completed".
func sendFactCheck(_ info: FactCheckRequest) async throws -> FactCheckSubmissionResponse {
    guard var urlComponents = URLComponents(string: Config.Endpoints.factCheck) else {
        throw URLError(.badURL)
    }
    urlComponents.queryItems = [
        URLQueryItem(name: "userId",    value: info.userId),
        URLQueryItem(name: "sessionId", value: info.sessionId)
    ]
    guard let url = urlComponents.url else { throw URLError(.badURL) }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.timeoutInterval = 30  // just the submission round-trip

    var body: [String: String] = ["link": info.link]
    if let sid = info.submissionId { body["submission_id"] = sid }
    request.httpBody = try JSONSerialization.data(withJSONObject: body)

    let (data, response) = try await URLSession.shared.data(for: request)

    // Backend returns 202 on success
    if let http = response as? HTTPURLResponse, http.statusCode == 200 || http.statusCode == 202 {
        // Try to decode as async 202 response first
        if let sub = try? JSONDecoder().decode(FactCheckSubmissionResponse.self, from: data) {
            return sub
        }
        // Legacy: backend returned full FactCheckData synchronously — wrap it
        if let legacy = try? JSONDecoder().decode(LegacyFactCheckData.self, from: data) {
            return FactCheckSubmissionResponse(
                submissionId: info.submissionId ?? UUID().uuidString,
                status: "completed",
                progressPercentage: 100,
                message: "Completed",
                legacyData: legacy
            )
        }
    }

    // Error response
    if let errorResponse = try? JSONDecoder().decode(FactCheckErrorResponse.self, from: data) {
        throw FactCheckError.apiError(errorResponse.error, errorResponse.errorType)
    }
    throw URLError(.badServerResponse)
}

struct FactCheckRequest: Codable {
    let link: String
    let userId: String
    let sessionId: String
    var submissionId: String?
}

/// 202 response from POST /fact-check
struct FactCheckSubmissionResponse: Codable {
    let submissionId: String
    let status: String
    let progressPercentage: Int
    let message: String
    /// Only populated for legacy backends that still respond synchronously
    var legacyData: LegacyFactCheckData?

    enum CodingKeys: String, CodingKey {
        case submissionId = "submission_id"
        case status
        case progressPercentage = "progress_percentage"
        case message
    }
}

struct FactCheckErrorResponse: Codable {
    let success: Bool?
    let error: String
    let errorType: String?
    enum CodingKeys: String, CodingKey {
        case success, error
        case errorType = "error_type"
    }
}

struct LimitReachedResponse: Codable {
    let error: String?
    let type: String?
    let limit: Int?
    let used: Int?
    let tier: String?
}

enum FactCheckError: LocalizedError {
    case apiError(String, String?)
    var errorDescription: String? {
        if case .apiError(let msg, _) = self { return msg }
        return "Unknown error"
    }
    var errorType: String? {
        if case .apiError(_, let t) = self { return t }
        return nil
    }
}

// MARK: - Legacy synchronous response (old backend)

/// Some older backend versions still return the full fact-check result synchronously.
/// This model decodes that shape so we can wrap it in FactCheckSubmissionResponse.
struct LegacyFactCheckData: Codable {
    let title: String
    let description: String?
    let date: String?
    let videoLink: String?
    let thumbnailUrl: String?
    let platform: String?
    let errorType: String?
    let aiGenerated: String?
    let aiProbability: Double?
    let claims: [ClaimEntry]?
    // Flat legacy fields
    let claim: String?
    let verdict: String?
    let claimAccuracyRating: String?
    let explanation: String?
    let summary: String?
    let sources: [String]?

    enum CodingKeys: String, CodingKey {
        case title, description, date, videoLink, platform, claims
        case claim, verdict, explanation, summary, sources
        case claimAccuracyRating = "claim_accuracy_rating"
        case thumbnailUrl   = "thumbnail_url"
        case errorType      = "error_type"
        case aiGenerated, aiProbability
    }

    var resolvedClaims: [ClaimEntry] {
        if let arr = claims, !arr.isEmpty { return arr }
        let cl  = claim               ?? ""
        let v   = verdict             ?? "Unverifiable"
        let car = claimAccuracyRating ?? "50%"
        let exp = explanation         ?? ""
        let sum = summary             ?? ""
        let src = sources             ?? []
        return [ClaimEntry(claim: cl, verdict: v, claimAccuracyRating: car,
                           explanation: exp, summary: sum, sources: src)]
    }
}

// MARK: - FactCheckData (kept for NetworkService.performFactCheck compatibility)

/// Used by NetworkService.performFactCheck — now decodes the 202 async response.
/// resolvedClaims synthesises ClaimEntry objects from either new claims array
/// or legacy flat fields so all callers work unchanged.
struct FactCheckData: Codable {
    // Optional because the 202 async response contains no title; only the legacy
    // synchronous response includes it. Making it optional prevents a DecodingError
    // when the 202 body is decoded before isAsyncSubmission can be checked.
    let title: String?
    let description: String?
    let date: String?
    let videoLink: String?
    let thumbnailUrl: String?
    let platform: String?
    let errorType: String?
    let aiGenerated: String?
    let aiProbability: Double?
    // New API
    let claims: [ClaimEntry]?
    // Legacy flat fields (still returned by older backend)
    let claim: String?
    let verdict: String?
    let claimAccuracyRating: String?
    let explanation: String?
    let summary: String?
    let sources: [String]?
    // Async submission fields
    let submissionId: String?
    let status: String?
    let progressPercentage: Int?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case title, description, date, videoLink, platform, claims
        case claim, verdict, explanation, summary, sources
        case claimAccuracyRating  = "claim_accuracy_rating"
        case thumbnailUrl         = "thumbnail_url"
        case errorType            = "error_type"
        case aiGenerated, aiProbability
        case submissionId         = "submission_id"
        case status
        case progressPercentage   = "progress_percentage"
        case message
    }

    var resolvedClaims: [ClaimEntry] {
        if let arr = claims, !arr.isEmpty { return arr }
        let cl  = claim               ?? ""
        let v   = verdict             ?? "Unverifiable"
        let car = claimAccuracyRating ?? "50%"
        let exp = explanation         ?? ""
        let sum = summary             ?? ""
        let src = sources             ?? []
        return [ClaimEntry(claim: cl, verdict: v, claimAccuracyRating: car,
                           explanation: exp, summary: sum, sources: src)]
    }

    /// True when backend returned the async 202 flow (submission is still processing)
    var isAsyncSubmission: Bool {
        submissionId != nil && (status == "processing" || status == "submitting")
    }

    /// True when the 202 response is for a duplicate URL the backend already has completed.
    /// The submission record is already marked "completed" — no Celery task will run.
    var isAlreadyCompleted: Bool {
        submissionId != nil && status == "completed"
    }
}
