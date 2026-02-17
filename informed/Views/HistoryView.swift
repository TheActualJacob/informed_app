//
//  HistoryView.swift
//  informed
//
//  View showing user's fact-check history
//

import SwiftUI

struct HistoryView: View {
    @State private var history: [FactCheckItem] = []
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            Color.backgroundLight.ignoresSafeArea()
            
            if isLoading {
                ProgressView("Loading history...")
            } else if history.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.lg) {
                        ForEach(history) { item in
                            NavigationLink(destination: FactDetailView(item: item)) {
                                FactResultCard(item: item)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .onTapGesture {
                                HapticManager.lightImpact()
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if !history.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            HapticManager.mediumImpact()
                            clearHistory()
                        } label: {
                            Label("Clear History", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundColor(.brandBlue)
                    }
                }
            }
        }
        .onAppear {
            loadHistory()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: Theme.IconSize.xl))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No History Yet")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("Your fact-check history will appear here")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    private func loadHistory() {
        isLoading = true
        history = PersistenceService.shared.getFactCheckHistory()
        isLoading = false
    }
    
    private func clearHistory() {
        withAnimation {
            PersistenceService.shared.clearHistory()
            history = []
        }
        HapticManager.success()
    }
}
