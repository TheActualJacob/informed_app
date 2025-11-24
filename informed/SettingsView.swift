//
//  SettingsView.swift
//  informed
//
//  Settings page for notifications and account management
//

import SwiftUI

struct NotificationSettingsView: View {
    @EnvironmentObject var notificationManager: NotificationManager
    @EnvironmentObject var userManager: UserManager
    @State private var showLogoutConfirmation = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.backgroundLight.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        
                        // Account Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Account")
                                .font(.headline)
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                            
                            VStack(spacing: 0) {
                                if let username = userManager.currentUsername {
                                    SettingsRow(
                                        icon: "person.circle.fill",
                                        title: "Username",
                                        value: username,
                                        color: .brandBlue
                                    )
                                }
                                
                                if let userId = userManager.currentUserId {
                                    Divider().padding(.leading, 60)
                                    
                                    SettingsRow(
                                        icon: "number.circle.fill",
                                        title: "User ID",
                                        value: String(userId.prefix(8)) + "...",
                                        color: .brandTeal
                                    )
                                }
                            }
                            .background(Color.white)
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                        
                        // Notifications Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Notifications")
                                .font(.headline)
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                            
                            VStack(spacing: 0) {
                                HStack {
                                    Image(systemName: "bell.fill")
                                        .font(.title3)
                                        .foregroundColor(.brandBlue)
                                        .frame(width: 30)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Push Notifications")
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        
                                        Text(notificationStatusText)
                                            .font(.caption)
                                            .foregroundColor(notificationStatusColor)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: notificationManager.notificationPermissionGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(notificationManager.notificationPermissionGranted ? .brandGreen : .gray)
                                }
                                .padding()
                                
                                if notificationManager.authorizationStatus == .denied {
                                    Divider()
                                    
                                    Button(action: {
                                        notificationManager.openNotificationSettings()
                                    }) {
                                        HStack {
                                            Image(systemName: "gear")
                                                .foregroundColor(.brandBlue)
                                            
                                            Text("Open Settings")
                                                .foregroundColor(.brandBlue)
                                            
                                            Spacer()
                                            
                                            Image(systemName: "arrow.up.right")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                        .padding()
                                    }
                                }
                                
                                if let deviceToken = notificationManager.deviceToken {
                                    Divider()
                                    
                                    HStack {
                                        Image(systemName: "iphone")
                                            .font(.title3)
                                            .foregroundColor(.brandTeal)
                                            .frame(width: 30)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Device Registered")
                                                .font(.body)
                                                .foregroundColor(.primary)
                                            
                                            Text(String(deviceToken.prefix(16)) + "...")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.brandGreen)
                                    }
                                    .padding()
                                }
                            }
                            .background(Color.white)
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                        
                        // About Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("About")
                                .font(.headline)
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                            
                            VStack(spacing: 0) {
                                SettingsRow(
                                    icon: "info.circle.fill",
                                    title: "Version",
                                    value: "1.0.0",
                                    color: .gray
                                )
                                
                                Divider().padding(.leading, 60)
                                
                                Button(action: {
                                    // Open privacy policy
                                }) {
                                    HStack {
                                        Image(systemName: "hand.raised.fill")
                                            .font(.title3)
                                            .foregroundColor(.gray)
                                            .frame(width: 30)
                                        
                                        Text("Privacy Policy")
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    .padding()
                                }
                                
                                Divider().padding(.leading, 60)
                                
                                Button(action: {
                                    // Open terms of service
                                }) {
                                    HStack {
                                        Image(systemName: "doc.text.fill")
                                            .font(.title3)
                                            .foregroundColor(.gray)
                                            .frame(width: 30)
                                        
                                        Text("Terms of Service")
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    .padding()
                                }
                            }
                            .background(Color.white)
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                        
                        // Logout Button
                        Button(action: {
                            showLogoutConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Log Out")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.brandRed)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)
                        
                        Spacer().frame(height: 20)
                    }
                    .padding(.top)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .confirmationDialog("Log Out", isPresented: $showLogoutConfirmation, titleVisibility: .visible) {
                Button("Log Out", role: .destructive) {
                    userManager.logout()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to log out?")
            }
        }
        .task {
            await notificationManager.checkAuthorizationStatus()
        }
    }
    
    private var notificationStatusText: String {
        switch notificationManager.authorizationStatus {
        case .authorized:
            return "Enabled"
        case .denied:
            return "Disabled - Tap to enable in Settings"
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
    
    private var notificationStatusColor: Color {
        switch notificationManager.authorizationStatus {
        case .authorized, .provisional:
            return .brandGreen
        case .denied:
            return .brandRed
        case .notDetermined:
            return .brandYellow
        default:
            return .gray
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 30)
            
            Text(title)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .foregroundColor(.gray)
                .lineLimit(1)
        }
        .padding()
    }
}

struct NotificationSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationSettingsView()
            .environmentObject(UserManager())
            .environmentObject(NotificationManager.shared)
    }
}
