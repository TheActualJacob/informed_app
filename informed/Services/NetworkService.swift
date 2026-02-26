//
//  NetworkService.swift
//  informed
//
//  Centralized networking layer with proper error handling
//

import Foundation

// MARK: - Network Errors

enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case noInternetConnection
    case serverError(statusCode: Int)
    case timeout
    case cannotConnectToHost
    case decodingError(String)
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Session expired. Please log in again."
        case .noInternetConnection:
            return "No internet connection"
        case .serverError(let statusCode):
            return "Server error (Code: \(statusCode))"
        case .timeout:
            return "Request timed out. This can happen with long videos - please try again"
        case .cannotConnectToHost:
            return "Cannot connect to server. Make sure the backend is running"
        case .decodingError(let message):
            return "Failed to decode response: \(message)"
        case .unknown(let error):
            return "An error occurred: \(error.localizedDescription)"
        }
    }
}

// MARK: - Network Service

class NetworkService {
    static let shared = NetworkService()
    
    private let session: URLSession
    
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 300 // 5 minutes for long videos
        configuration.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: configuration)
    }
    
    // MARK: - Fact Check API
    
    func performFactCheck(link: String, userId: String, sessionId: String,
                          submissionId: String? = nil) async throws -> FactCheckData {
        guard var urlComponents = URLComponents(string: Config.Endpoints.factCheck) else {
            throw NetworkError.invalidURL
        }
        urlComponents.queryItems = [
            URLQueryItem(name: "userId",    value: userId),
            URLQueryItem(name: "sessionId", value: sessionId)
        ]
        guard let url = urlComponents.url else { throw NetworkError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30  // only the submission round-trip

        var body: [String: String] = ["link": link]
        if let sid = submissionId { body["submission_id"] = sid }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.unknown(URLError(.badServerResponse))
            }

            // Check for API-level error response first (error field present)
            if let errResp = try? JSONDecoder().decode(FactCheckErrorResponse.self, from: data),
               !errResp.error.isEmpty {
                throw NetworkError.decodingError(errResp.error)
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw NetworkError.serverError(statusCode: httpResponse.statusCode)
            }

            // Decode — accepts both 202 async response and legacy synchronous response
            do {
                return try JSONDecoder().decode(FactCheckData.self, from: data)
            } catch {
                throw NetworkError.decodingError(error.localizedDescription)
            }

        } catch let urlError as URLError {
            throw mapURLError(urlError)
        } catch let netErr as NetworkError {
            throw netErr
        } catch {
            throw NetworkError.unknown(error)
        }
    }
    
    // MARK: - User Management
    
    func createUser(username: String, email: String, password: String) async throws -> UserResponse {
        guard let url = URL(string: Config.Endpoints.createUser) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let registration = UserRegistration(username: username, email: email, password: password)
        request.httpBody = try JSONEncoder().encode(registration)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw NetworkError.serverError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)
            }
            
            return try JSONDecoder().decode(UserResponse.self, from: data)
        } catch let urlError as URLError {
            throw mapURLError(urlError)
        }
    }
    
    func loginUser(email: String, password: String) async throws -> LoginResponse {
        guard let url = URL(string: Config.Endpoints.login) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let login = UserLogin(email: email, password: password)
        request.httpBody = try JSONEncoder().encode(login)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.serverError(statusCode: 0)
            }
            
            if httpResponse.statusCode == 401 {
                throw NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "Invalid email or password"])
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw NetworkError.serverError(statusCode: httpResponse.statusCode)
            }
            
            return try JSONDecoder().decode(LoginResponse.self, from: data)
        } catch let urlError as URLError {
            throw mapURLError(urlError)
        }
    }
    
    // MARK: - Device Registration
    
    func registerDevice(token: String) async throws {
        guard let url = URL(string: Config.Endpoints.registerDevice) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "device_token": token,
            "platform": "ios"
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }
    }
    
    // MARK: - Categories & Search
    
    func fetchCategories() async throws -> [CategoryItem] {
        guard let url = URL(string: Config.Endpoints.categories) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        
        let decoded = try JSONDecoder().decode(CategoryResponse.self, from: data)
        return decoded.categories
    }
    
    func searchReels(
        query: String,
        userId: String,
        sessionId: String,
        limit: Int = 20,
        category: String? = nil,
        platform: String? = nil,
        verdict: String? = nil
    ) async throws -> SearchResponse {
        guard var urlComponents = URLComponents(string: Config.Endpoints.search) else {
            throw NetworkError.invalidURL
        }
        
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "userId", value: userId),
            URLQueryItem(name: "sessionId", value: sessionId),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        if let category = category { queryItems.append(URLQueryItem(name: "category", value: category)) }
        if let platform = platform { queryItems.append(URLQueryItem(name: "platform", value: platform)) }
        if let verdict = verdict  { queryItems.append(URLQueryItem(name: "verdict", value: verdict)) }
        urlComponents.queryItems = queryItems
        
        guard let url = urlComponents.url else { throw NetworkError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { throw NetworkError.invalidResponse }
            if httpResponse.statusCode == 401 { throw NetworkError.unauthorized }
            guard (200...299).contains(httpResponse.statusCode) else {
                throw NetworkError.serverError(statusCode: httpResponse.statusCode)
            }
            return try JSONDecoder().decode(SearchResponse.self, from: data)
        } catch let urlError as URLError {
            throw mapURLError(urlError)
        }
    }
    
    func fetchPersonalizedFeed(
        userId: String,
        sessionId: String,
        limit: Int = 20,
        category: String? = nil
    ) async throws -> PersonalizedFeedResponse {
        guard var urlComponents = URLComponents(string: Config.Endpoints.personalizedFeed) else {
            throw NetworkError.invalidURL
        }
        
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "userId", value: userId),
            URLQueryItem(name: "sessionId", value: sessionId),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        if let category = category { queryItems.append(URLQueryItem(name: "category", value: category)) }
        urlComponents.queryItems = queryItems
        
        guard let url = urlComponents.url else { throw NetworkError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { throw NetworkError.invalidResponse }
            if httpResponse.statusCode == 401 { throw NetworkError.unauthorized }
            guard (200...299).contains(httpResponse.statusCode) else {
                throw NetworkError.serverError(statusCode: httpResponse.statusCode)
            }
            return try JSONDecoder().decode(PersonalizedFeedResponse.self, from: data)
        } catch let urlError as URLError {
            throw mapURLError(urlError)
        }
    }
    
    // MARK: - Helper Methods
    
    private func mapURLError(_ error: URLError) -> NetworkError {
        switch error.code {
        case .notConnectedToInternet:
            return .noInternetConnection
        case .cannotConnectToHost:
            return .cannotConnectToHost
        case .timedOut:
            return .timeout
        case .badServerResponse:
            return .serverError(statusCode: 0)
        default:
            return .unknown(error)
        }
    }
}
