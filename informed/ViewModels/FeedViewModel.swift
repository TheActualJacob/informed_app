 //
//  FeedViewModel.swift
//  informed
//
//  View model for the public feed displaying reels from all users
//

import Foundation
import SwiftUI
import Combine

@MainActor
class FeedViewModel: ObservableObject {
    @Published var publicReels: [PublicReel] = []
    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var errorMessage: String?
    
    // Pagination
    @Published var currentPage: Int = 1
    @Published var hasMore: Bool = true
    @Published var totalCount: Int = 0
    
    private let pageSize: Int = 10
    private var nextCursor: String?
    
    // MARK: - Initialization
    
    init() {
        // Auto-load feed when view model initializes
        Task {
            await loadFeed()
        }
    }
    
    // MARK: - Public Methods
    
    func loadFeed() async {
        guard !isLoading else { return }
        
        // Debug: Print current user state
        print("🔍 FeedViewModel attempting to load feed...")
        print("   UserManager.shared.currentUserId: \(UserManager.shared.currentUserId ?? "nil")")
        print("   UserManager.shared.currentSessionId: \(UserManager.shared.currentSessionId ?? "nil")")
        print("   UserManager.shared.isAuthenticated: \(UserManager.shared.isAuthenticated)")
        
        // Check if user is logged in first
        guard let userId = UserManager.shared.currentUserId,
              let _ = UserManager.shared.currentSessionId else {
            if UserManager.shared.currentUserId != nil {
                errorMessage = "Session expired. Please log out and log back in."
                print("⚠️ Cannot load feed: User ID exists but session ID is missing")
            } else {
                errorMessage = "Please log in to view the public feed"
                print("⚠️ Cannot load feed: User not logged in")
            }
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        print("✅ Attempting to fetch public feed for user: \(userId)")
        
        do {
            let response = try await fetchPublicFeed(page: 1, limit: pageSize)
            publicReels = response.reels
            currentPage = response.pagination.currentPage
            hasMore = response.pagination.hasMore
            totalCount = response.pagination.totalCount
            nextCursor = response.pagination.nextCursor
            
            print("✅ Loaded \(publicReels.count) public reels")
        } catch let error as NetworkError {
            if case .unauthorized = error {
                errorMessage = "Session expired. Please log out and log back in."
            } else {
                errorMessage = "Backend endpoints not ready. See BACKEND_URGENT_FIX.md"
            }
            print("❌ Error loading feed: \(error)")
        } catch {
            errorMessage = "Backend endpoints not ready. See BACKEND_URGENT_FIX.md"
            print("❌ Error loading feed: \(error)")
        }
        
        isLoading = false
    }
    
    func loadMoreReels() async {
        guard hasMore && !isLoadingMore && !isLoading else { return }
        
        isLoadingMore = true
        
        do {
            let nextPage = currentPage + 1
            let response = try await fetchPublicFeed(page: nextPage, limit: pageSize)
            
            // Append new reels
            publicReels.append(contentsOf: response.reels)
            currentPage = response.pagination.currentPage
            hasMore = response.pagination.hasMore
            nextCursor = response.pagination.nextCursor
            
            print("✅ Loaded \(response.reels.count) more reels (total: \(publicReels.count))")
        } catch {
            errorMessage = "Failed to load more: \(error.localizedDescription)"
            print("❌ Error loading more reels: \(error)")
        }
        
        isLoadingMore = false
    }
    
    func refresh() async {
        currentPage = 1
        hasMore = true
        nextCursor = nil
        await loadFeed()
    }
    
    func trackView(for reel: PublicReel) async {
        do {
            try await trackInteraction(factCheckId: reel.id, interactionType: "view")
            print("📊 Tracked view for reel: \(reel.id)")
        } catch {
            print("⚠️ Failed to track view: \(error)")
        }
    }
    
    func trackShare(for reel: PublicReel) async {
        do {
            try await trackInteraction(factCheckId: reel.id, interactionType: "share")
            print("📊 Tracked share for reel: \(reel.id)")
            
            // Update local engagement count
            // Note: structs can't be mutated in-place; backend returns updated count on next refresh
        } catch {
            print("⚠️ Failed to track share: \(error)")
        }
    }
    
    // MARK: - API Methods
    
    private func fetchPublicFeed(page: Int, limit: Int) async throws -> PublicFeedResponse {
        guard let userId = UserManager.shared.currentUserId,
              let sessionId = UserManager.shared.currentSessionId else {
            throw NetworkError.unauthorized
        }
        
        guard var urlComponents = URLComponents(string: Config.Endpoints.publicFeed) else {
            throw NetworkError.invalidURL
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "userId", value: userId),
            URLQueryItem(name: "sessionId", value: sessionId),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        
        if let cursor = nextCursor, page > 1 {
            urlComponents.queryItems?.append(URLQueryItem(name: "cursor", value: cursor))
        }
        
        guard let url = urlComponents.url else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw NetworkError.unauthorized
            }
            throw NetworkError.serverError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()

        // Debug: log raw JSON to diagnose reels with missing claim data
        if let rawJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let reelsArray = rawJSON["reels"] as? [[String: Any]] {
            print("📡 [FeedViewModel] Raw feed response: \(reelsArray.count) reels")
            for (i, r) in reelsArray.enumerated() {
                let uid         = r["uniqueID"]  as? String ?? "?"
                let title       = (r["title"]    as? String ?? "?")
                let claimsArr   = r["claims"]    as? [[String: Any]] ?? []
                let flatClaim   = r["claim"]     as? String
                let flatVerdict = r["verdict"]   as? String
                let flatRating  = r["claim_accuracy_rating"] as? String
                let flatSummary = r["summary"]   as? String
                print("  [\(i)] \(uid.prefix(8)) | \(title.prefix(40))")
                print("        claims[]=\(claimsArr.count) flat: claim=\(flatClaim != nil) verdict=\(flatVerdict != nil) rating=\(flatRating ?? "nil") summary=\(flatSummary != nil)")
                if !claimsArr.isEmpty {
                    let c0 = claimsArr[0]
                    print("        claims[0] keys: \(c0.keys.sorted())")
                    print("        claims[0] verdict=\(c0["verdict"] ?? "nil") rating=\(c0["claimAccuracyRating"] ?? "nil") summary=\((c0["summary"] as? String)?.prefix(40) ?? "nil")")
                }
                // Full raw dump for last 3 reels
                if i >= reelsArray.count - 3 {
                    print("        FULL[\(i)]: \(r)")
                }
            }
        }

        let feedResponse = try decoder.decode(PublicFeedResponse.self, from: data)

        // Debug: log what actually decoded
        for (i, reel) in feedResponse.reels.enumerated() {
            let c = reel.claims.first
            print("  decoded[\(i)] claims=\(reel.claims.count) verdict='\(c?.verdict ?? "EMPTY")' rating='\(c?.claimAccuracyRating ?? "EMPTY")' summary='\(c?.summary.prefix(30) ?? "EMPTY")' expl=\(c?.explanation.isEmpty == false ? "✅" : "❌empty")")
        }

        return feedResponse
    }
    
    private func trackInteraction(factCheckId: String, interactionType: String) async throws {
        guard let userId = UserManager.shared.currentUserId,
              let sessionId = UserManager.shared.currentSessionId else {
            throw NetworkError.unauthorized
        }
        
        guard var urlComponents = URLComponents(string: Config.Endpoints.trackInteraction) else {
            throw NetworkError.invalidURL
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "userId", value: userId),
            URLQueryItem(name: "sessionId", value: sessionId)
        ]
        
        guard let url = urlComponents.url else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = [
            "factCheckId": factCheckId,
            "interactionType": interactionType
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500)
        }
    }
}
