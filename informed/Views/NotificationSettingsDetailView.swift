//
//  NotificationSettingsDetailView.swift
//  informed
//
//  Detailed notification settings and permissions view
//

import SwiftUI

struct NotificationSettingsDetailView: View {
    @EnvironmentObject var notificationManager: NotificationManager
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                
                // Status Card
                VStack(spacing: Theme.Spacing.lg) {
                    HStack {
                        Image(systemName: notificationManager.notificationPermissionGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.title)
                            .foregroundColor(notificationManager.notificationPermissionGranted ? .brandGreen : .brandYellow)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notifications")
                                .font(.headline)
                            
                            Text(notificationStatusText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    if notificationManager.authorizationStatus == .denied {
                        Button(action: {
                            HapticManager.lightImpact()
                            notificationManager.openNotificationSettings()
                        }) {
                            HStack {
                                Image(systemName: "gear")
                                Text("Open Settings")
                            }
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.brandBlue)
                            .cornerRadius(Theme.CornerRadius.md)
                        }
                    }
                    
                    if let deviceToken = notificationManager.deviceToken {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text("Device Registered")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            
                            Text(String(deviceToken.prefix(16)) + "...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(Theme.Spacing.sm)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(Theme.CornerRadius.sm)
                        }
                    }
                }
                .padding()
                .background(Color.cardBackground)
                .cornerRadius(Theme.CornerRadius.md)
                .shadow(color: Color.black.opacity(0.05), radius: Theme.Shadow.sm, y: 2)
                
                // Info Section
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    Text("About Notifications")
                        .font(.headline)
                    
                    Text("You'll receive notifications when:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    InfoRow(
                        icon: "checkmark.circle.fill",
                        text: "Fact-check analysis is complete",
                        color: .brandGreen
                    )
                    InfoRow(
                        icon: "bell.fill",
                        text: "Shared reels are processed",
                        color: .brandBlue
                    )
                    InfoRow(
                        icon: "exclamationmark.triangle.fill",
                        text: "Important updates about your submissions",
                        color: .brandYellow
                    )
                }
                .padding()
                .background(Color.cardBackground)
                .cornerRadius(Theme.CornerRadius.md)
                
            }
            .padding()
        }
        .background(Color.backgroundLight)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var notificationStatusText: String {
        switch notificationManager.authorizationStatus {
        case .authorized:
            return "Enabled - You'll receive notifications"
        case .denied:
            return "Disabled - Enable in Settings"
        case .notDetermined:
            return "Not configured"
        case .provisional:
            return "Provisional"
        case .ephemeral:
            return "Ephemeral"
        @unknown default:
            return "Unknown"
        }
    }
}

struct InfoRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }
}
