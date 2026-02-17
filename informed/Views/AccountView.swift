//
//  AccountView.swift
//  informed
//
//  Account profile and settings view
//

import SwiftUI

struct AccountView: View {
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var notificationManager: NotificationManager
    @StateObject private var viewModel = AccountViewModel()
    @State private var showLogoutConfirmation = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Theme.Spacing.xxl) {
                    
                    // Profile Header
                    VStack(spacing: Theme.Spacing.md) {
                        ZStack {
                            Circle()
                                .fill(
                                    Color.brandGradient(
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)
                            
                            Text(userManager.currentUsername?.prefix(1).uppercased() ?? "U")
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        if let username = userManager.currentUsername {
                            Text(username)
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        
                        if let userId = userManager.currentUserId {
                            Text("ID: \(userId.prefix(8))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, Theme.Spacing.md)
                                .padding(.vertical, 6)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(Theme.CornerRadius.sm)
                        }
                    }
                    .padding(.top, Theme.Spacing.xl)
                    
                    // Stats Section
                    HStack(spacing: Theme.Spacing.xl) {
                        StatCard(
                            title: "Checked",
                            value: "\(viewModel.checkedCount)",
                            icon: "checkmark.seal.fill",
                            color: .brandGreen
                        )
                        .redacted(reason: viewModel.isLoading ? .placeholder : [])
                        
                        StatCard(
                            title: "Saved",
                            value: "\(viewModel.savedCount)",
                            icon: "bookmark.fill",
                            color: .brandBlue
                        )
                        .redacted(reason: viewModel.isLoading ? .placeholder : [])
                        
                        StatCard(
                            title: "Shared",
                            value: "\(viewModel.sharedCount)",
                            icon: "square.and.arrow.up",
                            color: .brandTeal
                        )
                        .redacted(reason: viewModel.isLoading ? .placeholder : [])
                    }
                    .padding(.horizontal)
                    
                    // Main Menu Section
                    VStack(spacing: 0) {
                        // History
                        NavigationLink(destination: HistoryView()) {
                            MenuRow(
                                icon: "clock.arrow.circlepath",
                                title: "History",
                                color: .brandBlue
                            )
                        }
                        
                        Divider().padding(.leading, 60)
                        
                        // How to Use
                        NavigationLink(destination: InstructionsView()) {
                            MenuRow(
                                icon: "info.circle.fill",
                                title: "How to Use",
                                color: .brandTeal
                            )
                        }
                        
                        Divider().padding(.leading, 60)
                        
                        // Notifications
                        NavigationLink(destination: NotificationSettingsDetailView()) {
                            HStack {
                                Image(systemName: "bell.fill")
                                    .foregroundColor(.brandYellow)
                                    .frame(width: 30)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Notifications")
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    
                                    Text(notificationManager.notificationPermissionGranted ? "Enabled" : "Disabled")
                                        .font(.caption)
                                        .foregroundColor(notificationManager.notificationPermissionGranted ? .brandGreen : .secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                        }
                        
                        Divider().padding(.leading, 60)
                        
                        // Privacy
                        Button(action: {
                            HapticManager.lightImpact()
                            // TODO: Privacy settings
                        }) {
                            MenuRow(
                                icon: "shield.fill",
                                title: "Privacy & Security",
                                color: .secondary
                            )
                        }
                        
                        Divider().padding(.leading, 60)
                        
                        // About
                        Button(action: {
                            HapticManager.lightImpact()
                            // TODO: About page
                        }) {
                            MenuRow(
                                icon: "info.circle",
                                title: "About Informed",
                                color: .secondary
                            )
                        }
                    }
                    .background(Color.cardBackground)
                    .cornerRadius(Theme.CornerRadius.md)
                    .shadow(color: Color.black.opacity(0.05), radius: Theme.Shadow.sm, y: 2)
                    .padding(.horizontal)
                    
                    // Logout Button
                    Button(action: {
                        HapticManager.mediumImpact()
                        showLogoutConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.brandRed)
                        .cornerRadius(Theme.CornerRadius.md)
                    }
                    .padding(.horizontal)
                    .padding(.top, Theme.Spacing.xl)
                    
                    Spacer()
                }
            }
            .background(Color.backgroundLight)
            .navigationTitle("Account")
            .confirmationDialog("Sign Out", isPresented: $showLogoutConfirmation, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) {
                    HapticManager.success()
                    userManager.logout()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .onAppear {
                viewModel.loadStats()
            }
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(Theme.CornerRadius.md)
        .shadow(color: Color.black.opacity(0.05), radius: Theme.Shadow.sm, y: 2)
    }
}

struct MenuRow: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 30)
            
            Text(title)
                .foregroundColor(.primary)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}
