//
//  FeedViewModel.swift
//  informed
//
//  View model for the published news story feed
//

import Foundation
import SwiftUI
import Combine

@MainActor
class FeedViewModel: ObservableObject {
   // Published editorial stories
   @Published var stories: [Story] = []
   
   @Published var isLoading: Bool = false
   @Published var errorMessage: String?
   
   // MARK: - Initialization
   
   init() { }
   
   // MARK: - Public Methods
   
   func loadFeed() async {
       guard !isLoading else { return }
       
       guard let userId = UserManager.shared.currentUserId,
             let _ = UserManager.shared.currentSessionId else {
           if UserManager.shared.currentUserId != nil {
               errorMessage = "Session expired. Please log out and log back in."
           } else {
               errorMessage = "Please log in to view the news"
           }
           return
       }
       _ = userId

       if errorMessage?.contains("log in") == true || errorMessage?.contains("Session expired") == true {
           errorMessage = nil
       }
       
       if stories.isEmpty { isLoading = true }
       errorMessage = nil
       
       do {
           let fetchedStories = try await NetworkService.shared.fetchStories(limit: 20)
           withAnimation(.easeInOut(duration: 0.25)) {
               stories = fetchedStories
           }
           print("✅ Loaded \(stories.count) stories")
       } catch let error as NetworkError {
           if case .unauthorized = error {
               errorMessage = "Session expired. Please log out and log back in."
           } else {
               errorMessage = "Could not refresh news. Pull down to try again."
           }
           print("❌ Error loading news: \(error)")
       } catch {
           errorMessage = "Could not refresh news. Pull down to try again."
           print("❌ Error loading news: \(error)")
       }
       
       isLoading = false
   }

   func loadFeedIfNeeded() async {
       guard AppDataCache.shared.isDiscoverStale || stories.isEmpty else { return }
       await loadFeed()
   }
   
   func refresh() async {
       AppDataCache.shared.lastDiscoverRefresh = nil
       await loadFeed()
   }
}
