//
//  ChangePasswordView.swift
//  informed

import SwiftUI

struct ChangePasswordView: View {
    @EnvironmentObject var userManager: UserManager
    @Environment(\.dismiss) private var dismiss

    private enum Phase { case send, enter }

    @State private var phase: Phase = .send
    @State private var code = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var cooldownSeconds: Int = 0
    @State private var cooldownTimer: Timer?

    var body: some View {
        Form {
            if phase == .send {
                Section(footer: Text("We'll send a 6-digit code to \(userManager.userEmail).")) {
                    Button(action: sendCode) {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView().progressViewStyle(CircularProgressViewStyle())
                            } else if cooldownSeconds > 0 {
                                Text("Resend in \(cooldownSeconds)s")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Send Verification Code")
                                    .font(.headline)
                            }
                            Spacer()
                        }
                    }
                    .disabled(isLoading || cooldownSeconds > 0)
                }
            } else {
                Section(header: Text("Verification Code")) {
                    TextField("6-digit code", text: $code)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .font(.system(.body, design: .monospaced))
                        .onChange(of: code) { _, v in
                            code = String(v.filter(\.isNumber).prefix(6))
                        }
                }
                Section(header: Text("New Password")) {
                    SecureField("New Password", text: $newPassword)
                        .textContentType(.newPassword)
                    SecureField("Confirm New Password", text: $confirmPassword)
                        .textContentType(.newPassword)
                    if !newPassword.isEmpty && newPassword.count < 8 {
                        Text("Must be at least 8 characters.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if !confirmPassword.isEmpty && confirmPassword != newPassword {
                        Text("Passwords do not match.")
                            .font(.caption).foregroundStyle(Color.brandRed)
                    }
                }
                Section {
                    Button(action: submit) {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView().progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Text("Update Password").font(.headline)
                            }
                            Spacer()
                        }
                    }
                    .disabled(isLoading || !canSubmit)
                    Button("Resend Code") { phase = .send }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let error = errorMessage {
                Section {
                    Text(error).foregroundStyle(Color.brandRed).font(.subheadline)
                }
            }
        }
        .navigationTitle("Change Password")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var canSubmit: Bool {
        code.count == 6 && newPassword.count >= 8 && newPassword == confirmPassword
    }

    private func sendCode() {
        guard let userId = userManager.currentUserId,
              let sessionId = userManager.currentSessionId else { return }
        isLoading = true
        errorMessage = nil
        Task {
            defer { Task { @MainActor in isLoading = false } }
            guard var comps = URLComponents(string: Config.Endpoints.sendPasswordChangeCode) else { return }
            comps.queryItems = [
                URLQueryItem(name: "userId", value: userId),
                URLQueryItem(name: "sessionId", value: sessionId),
            ]
            guard let url = comps.url else { return }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.timeoutInterval = 15
            do {
                let (data, response) = try await URLSession.shared.data(for: req)
                guard let http = response as? HTTPURLResponse else { return }
                await MainActor.run {
                    if http.statusCode == 429,
                       let body = try? JSONDecoder().decode([String: Int].self, from: data),
                       let retry = body["retryAfterSeconds"] {
                        startCooldown(seconds: retry)
                        phase = .enter
                    } else if (200...299).contains(http.statusCode) {
                        phase = .enter
                        startCooldown(seconds: 60)
                    } else {
                        errorMessage = "Failed to send code. Please try again."
                    }
                }
            } catch {
                await MainActor.run { errorMessage = "Network error. Please try again." }
            }
        }
    }

    private func submit() {
        guard canSubmit,
              let userId = userManager.currentUserId,
              let sessionId = userManager.currentSessionId else { return }
        isLoading = true
        errorMessage = nil
        Task {
            defer { Task { @MainActor in isLoading = false } }
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
                "verificationCode": code,
                "newPassword": newPassword,
            ])
            req.timeoutInterval = 15
            do {
                let (data, response) = try await URLSession.shared.data(for: req)
                guard let http = response as? HTTPURLResponse else { return }
                await MainActor.run {
                    if (200...299).contains(http.statusCode) {
                        dismiss()
                    } else if let body = try? JSONDecoder().decode([String: String].self, from: data) {
                        switch body["error"] {
                        case "wrong_code":
                            errorMessage = "Incorrect code — please try again."
                        case "code_expired":
                            errorMessage = "Code expired — tap Resend Code."
                        case "no_code_pending":
                            errorMessage = "No code sent yet — tap Send Verification Code."
                            phase = .send
                        case "password_too_short":
                            errorMessage = "New password must be at least 8 characters."
                        default:
                            errorMessage = "Failed to update password. Please try again."
                        }
                    } else {
                        errorMessage = "Failed to update password. Please try again."
                    }
                }
            } catch {
                await MainActor.run { errorMessage = "Network error. Please try again." }
            }
        }
    }

    private func startCooldown(seconds: Int) {
        cooldownTimer?.invalidate()
        cooldownSeconds = seconds
        guard seconds > 0 else { return }
        cooldownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                cooldownSeconds -= 1
                if cooldownSeconds <= 0 { cooldownTimer?.invalidate() }
            }
        }
    }
}
