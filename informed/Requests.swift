import Foundation

func sendFactCheck(_ info: FactCheckRequest) async throws -> Data {
    // 1. Create the URL
    guard let url = URL(string: "https://api.example.com/endpoint") else {
        throw URLError(.badURL)
    }
    
    // 2. Create the request
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
 
    request.httpBody = try JSONEncoder().encode(info)
    
    // 4. Send the request and wait for response
    let (data, response) = try await URLSession.shared.data(for: request)
    
    // 5. Check the response status
    guard let httpResponse = response as? HTTPURLResponse,
          (200...299).contains(httpResponse.statusCode) else {
        throw URLError(.badServerResponse)
    }
    
    return data
}


struct FactCheckRequest: Codable{
    let link: String
    let userId: String
}
