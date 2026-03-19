//
//  ChangePasswordView.swift
//  informed

import SwiftUI

struct ChangePasswordView: View {
    @EnvironmentObject var userManager: UserManager
    @Environment(\.dismiss) private var dismiss

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccess = false

    var body: some View {
        Form {
            Section {
                SecureField("Current Password", text: $currentPassword)
                    .textContentType(.password)
            }
            Section {
                SecureField("New Password", text: $newPassword)
                    .textContentType(.newPassword)
                SecureField("Confirm New Password", text: $confirmPassword)
                    .textContentType(.newPassword)
                if !newPassword.isEmpty && newPassword.count < 8 {
                    Text("Must be at least 8 characters.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !confirmPassword.isEmpty && confirmPassword != newPassword {
                    Text("Passwords do not match.")
                        .font(.caption)
                        .foregroundStyle(Color.brandRed)
                }
            }

            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(Color.brandRed)
                        .font(.subheadline)
                }
            }

            if showSuccess {
                Section {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.brandGreen)
                        Text("Password updated successfully.")
                            .foregroundStyle(Color.brandGreen)
                    }
                }
            }

            Section {
                Button(action: submit) {
                    HStack {
                        Spacer()
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Update Password")
                                .font(.headline)
                        }
                        Spacer()
                    }
                }
                .disabled(isLoading || !canSubmit)
            }
        }
        .navigationTitle("Change Password")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var canSubmit: Bool {
        !currentPassword.isEmpty
            && newPassword.count >= 8
            && newPassword == confirmPassword
    }

    private func submit() {
        guard canSubmit,
              let userId = userManager.currentUserId,
              let sessionId = userManager.currentSessionId else { return }
        isLoading = true
        errorMessage = nil
        showSuccess = false
        Task {
            defer { isLoading = false }
            guard var comps = URLComponents(string: Config.Endpoints.changePassword) else { return }
            comps.queryItems = [
                URLQueryItem(name: "userId", value: userId),
                URLQueryItem(name: "sessionId", value: sessionId),
            ]
            guard let url = comps.url else { return }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try? JSONSerialization.data(withJSONObject: [
                "currentPassword": currentPassword,
                "newPassword": newPassword,
            ])
            req.timeoutInterval = 15
            do {
                let (data, response) = try await URLSession.shared.data(for: req)
                guard let http = response as? HTTPURLResponse else { return }
                if (200...299).contains(http.statusCode) {
                    showSuccess = true
                    currentPassword = ""
                    newPassword = ""
                    confirmPassword = ""
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    dismiss()
                } else if let body = try? JSONDecoder().decode([String: String].self, from: data) {
                    switch body["error"] {
                    case "wrong_password":
                        errorMessage = "Current password is incorrect."
                    case "email_not_verified":
                        errorMessage = "You must verify your email before changing your password."
                    case "no_password_set":
                        errorMessage = "Password change is not available for Apple Sign-In accounts."
                    case "password_too_short":
                        errorMessage = "New password must be at least 8 characters."
                    default:
                        errorMessage = "Failed to update password. Please try again."
                    }
                } else {
                    errorMessage = "Failed to update password. Please try again."
                }
            } catch {
                errorMessage = "Network error. Please try again."
            }
        }
    }
}
