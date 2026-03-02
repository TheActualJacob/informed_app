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
    @EnvironmentObject var reelManager: SharedReelManager
    @StateObject private var viewModel = AccountViewModel()
    @State private var showLogoutConfirmation = false
    @State private var showDeleteAccountConfirmation = false
    @State private var isDeletingAccount = false
    @State private var deleteAccountError: String?
    
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
                        NavigationLink(destination: PrivacyPolicyView()) {
                            MenuRow(
                                icon: "shield.fill",
                                title: "Privacy & Security",
                                color: .secondary
                            )
                        }
                        
                        Divider().padding(.leading, 60)
                        
                        // About
                        NavigationLink(destination: AboutView()) {
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

                    // Delete Account Button
                    Button(action: {
                        HapticManager.mediumImpact()
                        showDeleteAccountConfirmation = true
                    }) {
                        HStack {
                            if isDeletingAccount {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .red))
                                    .scaleEffect(0.85)
                            } else {
                                Image(systemName: "person.crop.circle.badge.minus")
                            }
                            Text(isDeletingAccount ? "Deleting…" : "Delete Account")
                        }
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.08))
                        .cornerRadius(Theme.CornerRadius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .disabled(isDeletingAccount)
                    .padding(.horizontal)

                    if let error = deleteAccountError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
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
            .confirmationDialog("Delete Account", isPresented: $showDeleteAccountConfirmation, titleVisibility: .visible) {
                Button("Delete Account", role: .destructive) {
                    Task {
                        isDeletingAccount = true
                        deleteAccountError = nil
                        do {
                            try await userManager.deleteAccount()
                        } catch {
                            isDeletingAccount = false
                            deleteAccountError = "Could not delete account. Please try again or contact privacy@informed-app.com."
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete your account and all associated data. This action cannot be undone.")
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
