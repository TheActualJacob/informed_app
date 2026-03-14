//
//  InstructionsView.swift
//  informed
//
//  How It Works screen — swipeable tutorial carousel
//

import SwiftUI

struct InstructionsView: View {
    @EnvironmentObject var notificationManager: NotificationManager
    @State private var showPermissionRequest = false

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.06, blue: 0.12).ignoresSafeArea()

            VStack(spacing: 0) {
                // Notification banner (shown only when notifications are disabled)
                if !notificationManager.notificationPermissionGranted {
                    notificationBanner
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Swipeable tutorial — no dismiss action needed here (it's a tab, not a sheet)
                HowItWorksCarouselView(onComplete: nil)
            }
        }
        .navigationTitle("How It Works")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPermissionRequest) {
            NotificationPermissionSheet()
        }
        .task {
            await notificationManager.checkAuthorizationStatus()
        }
    }

    // MARK: - Notification Banner

    private var notificationBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.badge.fill")
                .font(.title3)
                .foregroundColor(.brandYellow)

            VStack(alignment: .leading, spacing: 2) {
                Text("Enable Notifications")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                Text("Get notified the instant your fact-check is ready")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                showPermissionRequest = true
            } label: {
                Text("Enable")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.brandBlue)
                    .clipShape(Capsule())
            }
        }
        .padding(14)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.07), radius: 8, y: 3)
    }
}

// MARK: - Supporting Views (kept for backward compatibility)

struct TipItem: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(.brandTeal)
            Text(text)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}

struct NotificationPermissionSheet: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var isRequesting = false

    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()

                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.brandTeal, .brandBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(spacing: 12) {
                    Text("Enable Notifications")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Get notified instantly when your fact-checks are ready. We'll only send you important updates about your submissions.")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                VStack(spacing: 16) {
                    Button(action: {
                        isRequesting = true
                        Task {
                            let granted = await notificationManager.requestNotificationPermissions()
                            isRequesting = false
                            if granted {
                                dismiss()
                            }
                        }
                    }) {
                        HStack {
                            if isRequesting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                Text("Requesting...")
                            } else {
                                Text("Enable Notifications")
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.brandTeal, .brandBlue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                    .disabled(isRequesting)

                    Button(action: { dismiss() }) {
                        Text("Maybe Later")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 30)

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Preview

struct InstructionsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            InstructionsView()
                .environmentObject(NotificationManager.shared)
        }
    }
}
