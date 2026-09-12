//
//  SavedView.swift
//  informed
//
//  Fact checks the user bookmarked from the detail view. Backs the "Saved" stat
//  on the Account tab.
//

import SwiftUI

struct SavedView: View {
    @State private var saved: [FactCheckItem] = PersistenceService.shared.getSavedFactChecks()

    var body: some View {
        ZStack {
            Color.backgroundLight.ignoresSafeArea()

            if saved.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.lg) {
                        ForEach(saved) { item in
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
                .refreshable {
                    HapticManager.lightImpact()
                    reload()
                }
            }
        }
        .navigationTitle("Saved")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            reload()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Image(systemName: "bookmark")
                .font(.system(size: Theme.IconSize.xl))
                .foregroundColor(.gray.opacity(0.5))

            Text("Nothing Saved Yet")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            Text("Tap the bookmark on any fact check to keep it here")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private func reload() {
        saved = PersistenceService.shared.getSavedFactChecks()
    }
}
