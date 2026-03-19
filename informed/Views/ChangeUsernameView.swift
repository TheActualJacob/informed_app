//
//  ChangeUsernameView.swift
//  informed

import SwiftUI

struct ChangeUsernameView: View {
    @EnvironmentObject var userManager: UserManager
    @Environment(\.dismiss) private var dismiss

    @State private var newUsername = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccess = false

    var body: some View {
        Form {
            Section {
                TextField("New username", text: $newUsername)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
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
                        Text("Username updated.")
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
                            Text("Save")
                                .font(.headline)
                        }
                        Spacer()
                    }
                }
                .disabled(newUsername.isEmpty || isLoading)
            }
        }
        .navigationTitle("Change Username")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func submit() {
        guard !newUsername.isEmpty,
              let userId = userManager.currentUserId,
              let sessionId = userManager.currentSessionId else { return }
        isLoading = true
        errorMessage = nil
        showSuccess = false
        Task {
            defer { isLoading = false }
            guard var comps = URLComponents(string: Config.Endpoints.changeUsername) else { return }
            comps.queryItems = [
                URLQueryItem(name: "userId", value: userId),
                URLQueryItem(name: "sessionId", value: sessionId),
            ]
            guard let url = comps.url else { return }
            var req = URLRequest(url: url)
            req.httpMethod = "PATCH"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try? JSONSerialization.data(withJSONObject: ["newUsername": newUsername])
            req.timeoutInterval = 15
            do {
                let (data, response) = try await URLSession.shared.data(for: req)
                guard let http = response as? HTTPURLResponse else { return }
                if (200...299).contains(http.statusCode) {
                    await userManager.updateUsername(newUsername)
                    showSuccess = true
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    dismiss()
                } else if let body = try? JSONDecoder().decode([String: String].self, from: data) {
                    switch http.statusCode {
                    case 409:
                        errorMessage = "Username already taken."
                    case 400:
                        errorMessage = body["error"] ?? "Invalid username."
                    default:
                        errorMessage = "Failed to update username. Please try again."
                    }
                } else {
                    errorMessage = "Failed to update username. Please try again."
                }
            } catch {
                errorMessage = "Network error. Please try again."
            }
        }
    }
}
