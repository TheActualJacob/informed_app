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
        ZStack {
            Color(red: 0.04, green: 0.06, blue: 0.12)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Dynamic Island preview pill
                dynamicIslandPreview
                    .padding(.top, 52)

                Spacer().frame(height: 36)

                // Title + subtitle
                VStack(spacing: 10) {
                    Text("Live in the\nDynamic Island")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text("Notifications power live fact-check progress\nright at the top of your screen.")
                        .font(.subheadline)
                        .foregroundColor(Color.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                .padding(.horizontal, 32)

                Spacer().frame(height: 40)

                // Benefit rows
                VStack(spacing: 14) {
                    NotifBenefitRow(
                        icon: "waveform",
                        color: .brandTeal,
                        title: "Live progress tracking",
                        detail: "Watch your analysis unfold in the Dynamic Island in real time"
                    )
                    NotifBenefitRow(
                        icon: "checkmark.seal.fill",
                        color: .brandGreen,
                        title: "Instant results",
                        detail: "Get notified the moment your fact-check is complete"
                    )
                    NotifBenefitRow(
                        icon: "bell.slash.fill",
                        color: Color.white.opacity(0.4),
                        title: "No noise",
                        detail: "Only important updates about your own submissions"
                    )
                }
                .padding(.horizontal, 28)

                Spacer()

                // CTA buttons
                VStack(spacing: 14) {
                    Button {
                        isRequesting = true
                        Task {
                            let granted = await notificationManager.requestNotificationPermissions()
                            isRequesting = false
                            if granted { dismiss() }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isRequesting {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                                    .scaleEffect(0.85)
                            }
                            Text(isRequesting ? "Requesting…" : "Enable Notifications")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [.brandTeal, .brandBlue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .disabled(isRequesting)

                    Button("Not Now") { dismiss() }
                        .font(.subheadline)
                        .foregroundColor(Color.white.opacity(0.35))
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 44)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(32)
    }

    // MARK: - Dynamic Island Preview

    private var dynamicIslandPreview: some View {
        ZStack {
            // Outer glow
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color.brandTeal.opacity(0.25), Color.brandBlue.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 220, height: 56)
                .blur(radius: 14)

            // Pill body
            Capsule()
                .fill(Color.black)
                .frame(width: 200, height: 40)

            // Content inside pill — fixed width so nothing wraps
            HStack(spacing: 8) {
                // Waveform dots
                HStack(spacing: 3) {
                    ForEach(0..<3) { _ in
                        Capsule()
                            .fill(Color.brandTeal)
                            .frame(width: 3, height: 12)
                    }
                }

                Text("Fact-checking…")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .fixedSize()

                Spacer(minLength: 0)

                Circle()
                    .fill(Color.brandTeal.opacity(0.85))
                    .frame(width: 8, height: 8)
            }
            .padding(.horizontal, 16)
            .frame(width: 200)
        }
    }
}

// MARK: - Benefit Row

private struct NotifBenefitRow: View {
    let icon: String
    let color: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: 46, height: 46)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                Text(detail)
                    .font(.caption)
                    .foregroundColor(Color.white.opacity(0.5))
                    .lineLimit(2)
            }
            Spacer()
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
