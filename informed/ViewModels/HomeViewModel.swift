//
//  HomeViewModel.swift
//  informed
//
//  View model for the home feed with fact-checking functionality
//

import Foundation
import SwiftUI
import Combine

@MainActor
class HomeViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var items: [FactCheckItem] = []
    @Published var searchText: String = "" {
        didSet {
            if searchText != oldValue {
                checkIfLink(searchText)
            }
        }
    }
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var processingLink: String? // For showing processing banner
    @Published var processingThumbnailURL: URL? // For link preview in banner
    
    // MARK: - Properties
    
    private var debounceTask: Task<Void, Never>?
    var userId: String = "default-user" // Will be set by HomeView
    var sessionId: String = "" // Will be set by HomeView
    
    // MARK: - Initialization
    
    init() {
        loadData()
    }
    
    // MARK: - Link Detection
    
    private func checkIfLink(_ text: String) {
        // Cancel any pending request
        debounceTask?.cancel()
        
        // Check if the text is a valid URL
        guard let url = URL(string: text),
              url.scheme != nil,
              url.host != nil else {
            return
        }
        
        // Wait 1 second before sending the request (gives user time to finish typing/pasting)
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
            
            // Check if task was cancelled
            guard !Task.isCancelled else { return }
            
            // If it's a valid URL, send the fact check request
            await performFactCheck(for: text, userId: userId, sessionId: sessionId)
        }
    }
    
    // MARK: - Fact Checking
    
    func performFactCheck(for link: String, userId: String, sessionId: String) async {
        // Don't set isLoading - we'll use processingLink instead
        self.processingLink = link
        self.errorMessage = nil
        
        // Extract preview image from link if possible
        if let url = URL(string: link) {
            self.processingThumbnailURL = url
        }
        
        print("🔍 Starting fact check for: \(link)")
        
        do {
            // Use NetworkService for the API call
            let factCheckData = try await NetworkService.shared.performFactCheck(
                link: link,
                userId: userId,
                sessionId: sessionId
            )
            print("✅ Received response from server")
            print("📊 Data: \(factCheckData.title)")
            
            // Convert FactCheckData to FactCheck (the model used in the UI)
            let factCheck = FactCheck(
                claim: factCheckData.claim,
                verdict: factCheckData.verdict,
                claimAccuracyRating: factCheckData.claimAccuracyRating,
                explanation: factCheckData.explanation,
                summary: factCheckData.summary,
                sources: factCheckData.sources
            )
            
            // Create a new FactCheckItem from the response
            let newItem = FactCheckItem(
                sourceName: "Fact Check API",
                sourceIcon: "checkmark.seal.fill",
                timeAgo: "Just now",
                title: factCheckData.title,
                summary: factCheckData.summary,
                thumbnailURL: URL(string: factCheckData.thumbnailUrl ?? factCheckData.videoLink),
                credibilityScore: calculateCredibilityScore(from: factCheckData.claimAccuracyRating),
                sources: factCheckData.sources.joined(separator: ", "),
                verdict: factCheckData.verdict,
                factCheck: factCheck,
                originalLink: link,
                datePosted: factCheckData.date
            )
            
            // Save to history
            PersistenceService.shared.saveFactCheck(newItem)
            
            // Add the new item to the top of the list
            self.items.insert(newItem, at: 0)
            
            // IMPORTANT: Also add to SharedReelManager so it shows in "My Reels" tab
            let storedData = StoredFactCheckData(
                title: factCheckData.title,
                summary: factCheckData.summary,
                thumbnailURL: factCheckData.thumbnailUrl,
                claim: factCheckData.claim,
                verdict: factCheckData.verdict,
                claimAccuracyRating: factCheckData.claimAccuracyRating,
                explanation: factCheckData.explanation,
                sources: factCheckData.sources,
                datePosted: factCheckData.date
            )
            
            let newReel = SharedReel(
                id: UUID().uuidString,
                url: link,
                submittedAt: Date(),
                status: .completed,
                resultId: factCheckData.title,
                errorMessage: nil,
                factCheckData: storedData
            )
            
            SharedReelManager.shared.reels.insert(newReel, at: 0)
            SharedReelManager.shared.saveReels()
            print("✅ Added reel to My Reels tab")
            
            // Clear the search text and processing state
            self.searchText = ""
            self.processingLink = nil
            self.processingThumbnailURL = nil
            
        } catch let networkError as NetworkError {
            // Use NetworkError for better error messages
            self.errorMessage = networkError.errorDescription
            print("❌ Error performing fact check: \(networkError)")
            
            // Clear processing state
            self.processingLink = nil
            self.processingThumbnailURL = nil
        } catch {
            self.errorMessage = "Failed to check fact: \(error.localizedDescription)"
            print("❌ Error performing fact check: \(error)")
            
            // Clear processing state
            self.processingLink = nil
            self.processingThumbnailURL = nil
        }
    }
    
    // MARK: - Data Loading
    
    func loadData() {
        self.isLoading = true

        // Mock Network Delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            self.items = self.getMockData()
            self.isLoading = false
        }
    }
    
    func refresh() {
        items.removeAll()
        loadData()
    }
    
    // MARK: - Helper Methods
    
    func calculateCredibilityScore(from rating: String) -> Double {
        // Extract percentage from rating string like "100%" or "5%"
        let numericString = rating.replacingOccurrences(of: "%", with: "")
        if let percentage = Double(numericString) {
            return percentage / 100.0
        }
        return 0.5 // Default to 50% if parsing fails
    }
    
    // MARK: - Mock Data
    
    private func getMockData() -> [FactCheckItem] {
        return [
            // NYC Election Fact Check
            FactCheckItem(
                sourceName: "News Aggregator",
                sourceIcon: "newspaper.fill",
                timeAgo: "1h ago",
                title: "NYC 2025 Mayoral Election Voter Turnout",
                summary: "More people voted in New York City's election this year than they have in 50 years.",
                thumbnailURL: URL(string: "https://images.unsplash.com/photo-1554687589-f6b201f55d95?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80"),
                credibilityScore: 1.0,
                sources: "News Aggregator",
                verdict: "True",
                factCheck: FactCheck(
                    claim: "More people voted in New York City's election this year than they have in 50 years.",
                    verdict: "True",
                    claimAccuracyRating: "100%",
                    explanation: "The claim states that the 2025 New York City election saw the highest voter turnout in 50 years. According to multiple news sources and the New York City Board of Elections, the 2025 mayoral election had the largest voter turnout in over 50 years, with more than 2 million New Yorkers casting ballots. The last time a mayoral race had over 2 million voters was in 1969. This confirms the claim's accuracy.",
                    summary: "The 2025 New York City mayoral election had the highest voter turnout in over 50 years, with over 2 million voters casting ballots, making the claim true.",
                    sources: [
                        "https://www.cityandstateny.com/politics/2025/11/5-takeaways-2025-nyc-election-turnout/409413/",
                        "https://www.nbcnewyork.com/news/politics/nyc-voter-turnout-breaking-records/6414233/",
                        "https://www.nytimes.com/2025/11/04/nyregion/nyc-mayor-election-turnout.html",
                        "https://www.pbs.org/newshour/politics/democrat-zohran-mamdani-wins-new-york-city-mayors-race"
                    ]
                ),
                originalLink: nil,
                datePosted: nil
            ),
            // AI Chip Fact Check
            FactCheckItem(
                sourceName: "TechCrunch",
                sourceIcon: "network",
                timeAgo: "2h ago",
                title: "Does the new AI Chip actually use human neurons?",
                summary: "Viral claims suggest the new Z-90 chip uses biological components. Our analysis confirms it uses silicon-based neuromorphic architecture.",
                thumbnailURL: URL(string: "https://images.unsplash.com/photo-1555255707-c07966088b7b?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80"),
                credibilityScore: 0.95,
                sources: "TechCrunch",
                verdict: "False",
                factCheck: FactCheck(
                    claim: "The new Z-90 AI chip incorporates actual human neurons into its architecture.",
                    verdict: "False",
                    claimAccuracyRating: "5%",
                    explanation: "Extensive technical documentation and manufacturer specifications confirm that the Z-90 chip uses exclusively silicon-based components with neuromorphic architecture designed to mimic neural behavior. No biological components are used. The claim appears to stem from misunderstandings about neuromorphic engineering, which aims to replicate aspects of biological neural networks using electronic circuits, not actual biological tissue.",
                    summary: "The Z-90 chip uses advanced silicon-based neuromorphic architecture to simulate neural behavior, but does not incorporate actual human neurons or any biological components.",
                    sources: [
                        "https://tech-manufacturer.com/z90-technical-specs.pdf",
                        "https://journalofneurotechnology.org/z90-analysis-2025",
                        "https://www.techcrunch.com/2025/10/15/ai-chip-breakdown/",
                        "https://www.electronicnews.com/z90-architecture-review"
                    ]
                ),
                originalLink: nil,
                datePosted: nil
            ),
            // Salt Water Health Claim
            FactCheckItem(
                sourceName: "Health Watch",
                sourceIcon: "heart.fill",
                timeAgo: "5h ago",
                title: "Can drinking salt water cure insomnia?",
                summary: "A viral social media video claims salt water aids sleep. Medical experts warn of serious health risks.",
                thumbnailURL: URL(string: "https://images.unsplash.com/photo-1515871204537-49a5e85aee65?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80"),
                credibilityScore: 0.15,
                sources: "Health Watch",
                verdict: "False",
                factCheck: FactCheck(
                    claim: "Drinking salt water can effectively treat insomnia and improve sleep quality.",
                    verdict: "False",
                    claimAccuracyRating: "2%",
                    explanation: "Medical research and the American Sleep Association explicitly refute this claim. Consuming salt water can cause dehydration, electrolyte imbalances, and elevated blood pressure - all of which worsen sleep quality. The trend appears to originate from social media influencers without medical backgrounds. Legitimate sleep treatments include cognitive behavioral therapy, consistent sleep schedules, and in some cases, FDA-approved medications prescribed by healthcare professionals.",
                    summary: "Salt water consumption does not treat insomnia and may cause serious health complications including dehydration and elevated blood pressure.",
                    sources: [
                        "https://www.sleepfoundation.org/sleep-hygiene",
                        "https://www.mayoclinic.org/healthy-lifestyle/adult-health/in-depth/sleep/art-20048379",
                        "https://www.aasm.org/public/resources/sleeptips",
                        "https://pubmed.ncbi.nlm.nih.gov/salt-water-health-effects"
                    ]
                ),
                originalLink: nil,
                datePosted: nil
            )
        ]
    }
}
