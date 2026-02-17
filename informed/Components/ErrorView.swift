//
//  ErrorView.swift
//  informed
//
//  Reusable error view with retry functionality
//

import SwiftUI

struct ErrorView: View {
    let error: Error
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: Theme.IconSize.xl))
                .foregroundColor(.brandYellow)
            
            Text("Something Went Wrong")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(error.localizedDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                HapticManager.mediumImpact()
                retryAction()
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: 200)
                .background(Color.brandBlue)
                .cornerRadius(Theme.CornerRadius.md)
            }
        }
        .padding()
    }
}

// MARK: - Error Banner

struct ErrorBanner: View {
    let message: String
    let dismissAction: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.brandYellow)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.primary)
            
            Spacer()
            
            Button(action: {
                HapticManager.lightImpact()
                dismissAction()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.brandYellow.opacity(0.1))
        .cornerRadius(Theme.CornerRadius.md)
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Image(systemName: icon)
                .font(.system(size: Theme.IconSize.xl))
                .foregroundColor(.gray.opacity(0.5))
            
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(message)
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: {
                    HapticManager.lightImpact()
                    action()
                }) {
                    Text(actionTitle)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: 200)
                        .background(Color.brandBlue)
                        .cornerRadius(Theme.CornerRadius.md)
                }
            }
        }
        .padding()
    }
}
