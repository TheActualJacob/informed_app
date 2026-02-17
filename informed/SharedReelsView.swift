//
//  SharedReelsView.swift
//  informed
//
//  Displays a list of shared Instagram reels and their fact-checking status
//

import SwiftUI

struct SharedReelsView: View {
    @EnvironmentObject var reelManager: SharedReelManager
    @EnvironmentObject var userManager: UserManager
    
    // Helper to find fact check item from SharedReelManager's homeViewModel
    private func findFactCheckItem(for resultId: String) -> FactCheckItem? {
        // Try to find in the home view model's items
        return SharedReelManager.shared.homeViewModel?.items.first(where: { $0.title == resultId })
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.backgroundLight.ignoresSafeArea()
                
                if reelManager.reels.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(reelManager.reels) { reel in
                                ReelStatusCard(
                                    reel: reel,
                                    factCheckItem: reel.resultId != nil ? findFactCheckItem(for: reel.resultId!) : nil
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Shared Reels")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !reelManager.reels.isEmpty {
                        Menu {
                            Button(role: .destructive) {
                                withAnimation {
                                    reelManager.clearAllReels()
                                }
                            } label: {
                                Label("Clear All", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                                .foregroundColor(.brandBlue)
                        }
                    }
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No Shared Reels")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("Share Instagram reels to this app\nto start fact-checking them")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct ReelStatusCard: View {
    let reel: SharedReel
    let factCheckItem: FactCheckItem?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with status
            HStack {
                Image(systemName: reel.status.icon)
                    .font(.title3)
                    .foregroundColor(reel.status.color)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(reel.status.rawValue)
                        .font(.headline)
                        .foregroundColor(reel.status.color)
                    
                    Text(reel.timeAgo)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                if reel.status == .processing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .brandBlue))
                }
            }
            
            Divider()
            
            // URL
            VStack(alignment: .leading, spacing: 4) {
                Text("Instagram URL")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray)
                
                Text(reel.displayURL)
                    .font(.footnote)
                    .foregroundColor(.primary)
                    .lineLimit(2)
            }
            
            // Error message if failed
            if let errorMessage = reel.errorMessage, reel.status == .failed {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.brandRed)
                            .font(.caption)
                        
                        Text("Error")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.brandRed)
                    }
                    
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(8)
                .background(Color.brandRed.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Action button for completed items
            if reel.status == .completed, let item = factCheckItem {
                NavigationLink(destination: FactDetailView(item: item)) {
                    HStack {
                        Image(systemName: "doc.text.magnifyingglass")
                        Text("View Results")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: [.brandTeal, .brandBlue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(8)
                }
                .onTapGesture {
                    HapticManager.lightImpact()
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 8, y: 4)
    }
}

struct SharedReelsView_Previews: PreviewProvider {
    static var previews: some View {
        SharedReelsView()
            .environmentObject(UserManager())
            .environmentObject(SharedReelManager.shared)
    }
}
