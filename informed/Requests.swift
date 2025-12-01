import Foundation

func sendFactCheck(_ info: FactCheckRequest) async throws -> FactCheckData {
    // 1. Create the base URL for your local Flask server
    guard var urlComponents = URLComponents(string: Config.Endpoints.factCheck) else {
        throw URLError(.badURL)
    }
    
    // 2. Add query parameters for userId and sessionId
    urlComponents.queryItems = [
        URLQueryItem(name: "userId", value: info.userId),
        URLQueryItem(name: "sessionId", value: info.sessionId)
    ]
    
    guard let url = urlComponents.url else {
        throw URLError(.badURL)
    }
    
    // 3. Create the request with extended timeout
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.timeoutInterval = 300  // 5 minutes timeout for long videos
    
    // 4. Encode only the link in the request body
    let body = ["link": info.link]
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    
    // 5. Send the request and wait for response
    let (data, response) = try await URLSession.shared.data(for: request)
    
    // 6. Check the response status
    guard let httpResponse = response as? HTTPURLResponse,
          (200...299).contains(httpResponse.statusCode) else {
        throw URLError(.badServerResponse)
    }
    
    // 7. Decode and return the fact check data
    let factCheckData = try JSONDecoder().decode(FactCheckData.self, from: data)
    return factCheckData
}


struct FactCheckRequest: Codable {
    let link: String
    let userId: String
    let sessionId: String
}

struct FactCheckData: Codable {
    let title: String
    let description: String
    let date: String
    let videoLink: String
    let claim: String
    let verdict: String
    let claimAccuracyRating: String
    let explanation: String
    let summary: String
    let sources: [String]
    
    enum CodingKeys: String, CodingKey {
        case title, description, date, videoLink, claim, verdict, explanation, summary, sources
        case claimAccuracyRating = "claim_accuracy_rating"
    }
}
