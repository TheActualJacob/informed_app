//
//  InstructionsView.swift
//  informed
//
//  Home screen explaining how to use the app with Instagram reels
//

import SwiftUI

struct InstructionsView: View {
    @EnvironmentObject var notificationManager: NotificationManager
    @State private var showPermissionRequest = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.brandBlue.opacity(0.1), Color.brandTeal.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 30) {

                    Spacer().frame(height: 20)

                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 60))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.brandTeal, .brandBlue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Text("How to Use Informed")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)

                        Text("Fact-check Instagram reels instantly")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.bottom, 10)

                    // Notification Status Card
                    notificationStatusCard

                    // Instructions
                    VStack(spacing: 16) {
                        InstructionStep(
                            number: "1",
                            icon: "Instagram",
                            title: "Find a Reel",
                            description: "Open Instagram and find a reel you want to fact-check"
                        )

                        InstructionStep(
                            number: "2",
                            icon: "square.and.arrow.up",
                            title: "Share to Informed",
                            description: "Tap the share button and select 'Informed' from the share sheet"
                        )

                        InstructionStep(
                            number: "3",
                            icon: "gearshape.2",
                            title: "We Process It",
                            description: "Our AI analyzes the reel and fact-checks all claims made"
                        )

                        InstructionStep(
                            number: "4",
                            icon: "bell.badge",
                            title: "Get Notified",
                            description: "You'll receive a push notification when fact-checking is complete"
                        )

                        InstructionStep(
                            number: "5",
                            icon: "doc.text.magnifyingglass",
                            title: "View Results",
                            description: "Open the app to see detailed fact-check results and sources"
                        )
                    }
                    .padding(.horizontal)

                    // Tips Section
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Quick Tips", systemImage: "lightbulb.fill")
                            .font(.headline)
                            .foregroundColor(.brandBlue)

                        TipItem(text: "Make sure notifications are enabled to get instant results")
                        TipItem(text: "Processing typically takes 30 seconds to 2 minutes")
                        TipItem(text: "You can share multiple reels - we'll process them all")
                        TipItem(text: "Check the 'Shared Reels' tab to see status of all submissions")
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.08), radius: 8, y: 4)
                    .padding(.horizontal)

                    Spacer().frame(height: 20)
                }
            }
        }
        .navigationTitle("How to Use")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPermissionRequest) {
            NotificationPermissionSheet()
        }
        .task {
            await notificationManager.checkAuthorizationStatus()
        }
    }
    
    private var notificationStatusCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: notificationManager.notificationPermissionGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundColor(notificationManager.notificationPermissionGranted ? .brandGreen : .brandYellow)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notifications")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(notificationManager.notificationPermissionGranted ? "Enabled" : "Disabled")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                if !notificationManager.notificationPermissionGranted {
                    Button(action: {
                        showPermissionRequest = true
                    }) {
                        Text("Enable")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.brandBlue)
                            .cornerRadius(8)
                    }
                }
            }
            
            if !notificationManager.notificationPermissionGranted {
                Text("Enable notifications to receive fact-check results instantly")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 8, y: 4)
        .padding(.horizontal)
    }
}

struct InstructionStep: View {
    let number: String
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Number circle
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.brandTeal, .brandBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                
                Text(number)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(.brandBlue)
                    
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 8, y: 4)
    }
}

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
                    
                    Button(action: {
                        dismiss()
                    }) {
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
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct InstructionsView_Previews: PreviewProvider {
    static var previews: some View {
        InstructionsView()
            .environmentObject(NotificationManager.shared)
    }
}
