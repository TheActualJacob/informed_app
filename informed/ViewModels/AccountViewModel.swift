//
//  AccountViewModel.swift
//  informed
//
//  View model for account statistics and management
//

import Foundation
import SwiftUI
import Combine

@MainActor
class AccountViewModel: ObservableObject {
    @Published var checkedCount: Int = 0
    @Published var savedCount: Int = 0
    @Published var sharedCount: Int = 0
    @Published var isLoading: Bool = false
    
    func loadStats() {
        isLoading = true
        
        // TODO: Load real stats from backend or local storage
        // For now, calculate from local data
        Task {
            // Simulate network delay
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            // Load saved fact checks count from UserDefaults
            let persistence = PersistenceService.shared
            checkedCount = persistence.getFactCheckHistory().count
            savedCount = persistence.getSavedFactChecks().count
            sharedCount = persistence.getSharedCount()
            
            isLoading = false
        }
    }
}
