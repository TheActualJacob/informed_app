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
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @StateObject private var viewModel = AccountViewModel()
    @State private var showLogoutConfirmation = false
    @State private var showDeleteAccountConfirmation = false
    @State private var isDeletingAccount = false
    @State private var deleteAccountError: String?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xxl) {
                    
                    profileHeader
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

                    // Upgrade banner for free users
                    if !subscriptionManager.isPro {
                        NavigationLink(destination: SubscriptionView().environmentObject(subscriptionManager)) {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 4) {
                                        Text("✦")
                                            .font(.subheadline.weight(.bold))
                                        Text("+informed Pro")
                                            .font(.subheadline.weight(.bold))
                                    }
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color.brandBlue, Color.brandTeal],
                                            startPoint: .leading, endPoint: .trailing
                                        )
                                    )
                                    Text("\(subscriptionManager.usage.dailyRemaining) checks left today · Upgrade for 15/day")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.cardBackground)
                            .clipShape(.rect(cornerRadius: Theme.CornerRadius.md))
                            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color.brandBlue.opacity(0.4), Color.brandTeal.opacity(0.4)],
                                            startPoint: .leading, endPoint: .trailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                        }
                        .padding(.horizontal)
                    }
                    // Email verification banner
                    if !userManager.isEmailVerified && !userManager.isAppleUser {
                        EmailVerificationBannerView()
                            .padding(.horizontal)
                    }
                    menuCard
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
                        .clipShape(.rect(cornerRadius: Theme.CornerRadius.md))
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
                            Text(isDeletingAccount ? "Deleting\u{2026}" : "Delete Account")
                        }
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.08))
                        .clipShape(.rect(cornerRadius: Theme.CornerRadius.md))
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
                    subscriptionManager.logout()
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
                refreshVerificationStatus()
            }
        }
    }

    @ViewBuilder
    private var profileHeader: some View {
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
                HStack(spacing: 6) {
                    Text(username)
                        .font(.title2)
                        .fontWeight(.bold)
                    NavigationLink(destination: EditProfileView()) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if let userId = userManager.currentUserId {
                Text("ID: \(userId.prefix(8))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(.rect(cornerRadius: Theme.CornerRadius.sm))
            }

            if subscriptionManager.isPro {
                HStack(spacing: 5) {
                    Text("✦")
                        .font(.caption.weight(.bold))
                    Text("+informed Pro")
                        .font(.caption.weight(.bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    LinearGradient(
                        colors: [Color.brandBlue, Color.brandTeal],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .clipShape(.rect(cornerRadius: 20))
            }
        }
    }

    @ViewBuilder
    private var menuCard: some View {
        VStack(spacing: 0) {
            NavigationLink(destination: HistoryView()) {
                MenuRow(icon: "clock.arrow.circlepath", title: "History", color: .brandBlue)
            }

            Divider().padding(.leading, 60)

            NavigationLink(destination: SubscriptionView().environmentObject(subscriptionManager)) {
                MenuRow(
                    icon: subscriptionManager.isPro ? "star.circle.fill" : "star.circle",
                    title: subscriptionManager.isPro ? "+informed Pro" : "Upgrade to Pro",
                    color: subscriptionManager.isPro
                        ? Color(red: 1.0, green: 0.78, blue: 0.25)
                        : .brandBlue
                )
            }

            Divider().padding(.leading, 60)

            NavigationLink(destination: InstructionsView()) {
                MenuRow(icon: "info.circle.fill", title: "How to Use", color: .brandTeal)
            }

            Divider().padding(.leading, 60)

            NavigationLink(destination: NotificationSettingsDetailView()) {
                HStack {
                    Image(systemName: "bell.fill")
                        .foregroundStyle(.brandYellow)
                        .frame(width: 30)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Notifications")
                            .font(.body)
                            .foregroundStyle(.primary)
                        Text(notificationManager.notificationPermissionGranted ? "Enabled" : "Disabled")
                            .font(.caption)
                            .foregroundStyle(notificationManager.notificationPermissionGranted ? .brandGreen : .secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }

            Divider().padding(.leading, 60)

            NavigationLink(destination: PrivacyPolicyView()) {
                MenuRow(icon: "shield.fill", title: "Privacy & Security", color: .secondary)
            }

            Divider().padding(.leading, 60)

            NavigationLink(destination: AboutView()) {
                MenuRow(icon: "info.circle", title: "About Informed", color: .secondary)
            }
        }
        .background(Color.cardBackground)
        .clipShape(.rect(cornerRadius: Theme.CornerRadius.md))
        .shadow(color: Color.black.opacity(0.05), radius: Theme.Shadow.sm, y: 2)
    }

    private func refreshVerificationStatus() {
        guard let userId = userManager.currentUserId,
              let sessionId = userManager.currentSessionId else { return }
        Task {
            guard var comps = URLComponents(string: Config.Endpoints.verificationStatus) else { return }
            comps.queryItems = [
                URLQueryItem(name: "userId", value: userId),
                URLQueryItem(name: "sessionId", value: sessionId),
            ]
            guard let url = comps.url else { return }
            guard let (data, response) = try? await URLSession.shared.data(from: url),
                  let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode),
                  let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            let verified = (body["verified"] as? Bool) ?? false
            let hasPassword = (body["hasPassword"] as? Bool) ?? true
            await MainActor.run {
                userManager.isEmailVerified = verified
                UserDefaults.standard.set(verified, forKey: "stored_email_verified")
                // No password means Apple (or future OAuth) user — mark accordingly
                if !hasPassword {
                    userManager.isAppleUser = true
                    UserDefaults.standard.set(true, forKey: "stored_is_apple_user")
                }
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
                .foregroundStyle(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.cardBackground)
        .clipShape(.rect(cornerRadius: Theme.CornerRadius.md))
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
                .foregroundStyle(color)
                .frame(width: 30)
            
            Text(title)
                .foregroundStyle(.primary)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
