import Foundation

func sendFactCheck(_ info: FactCheckRequest) async throws -> FactCheckData {
    // 1. Create the URL for your local Flask server
    guard let url = URL(string: "http://192.168.1.238:5001/fact-check") else {
        throw URLError(.badURL)
    }
    
    // 2. Create the request with extended timeout
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.timeoutInterval = 300  // 5 minutes timeout for long videos
    
    // 3. Encode the request body
    request.httpBody = try JSONEncoder().encode(info)
    
    // 4. Send the request and wait for response
    let (data, response) = try await URLSession.shared.data(for: request)
    
    // 5. Check the response status
    guard let httpResponse = response as? HTTPURLResponse,
          (200...299).contains(httpResponse.statusCode) else {
        throw URLError(.badServerResponse)
    }
    
    // 6. Decode and return the fact check data
    let factCheckData = try JSONDecoder().decode(FactCheckData.self, from: data)
    return factCheckData
}


struct FactCheckRequest: Codable {
    let link: String
    let userId: String
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



