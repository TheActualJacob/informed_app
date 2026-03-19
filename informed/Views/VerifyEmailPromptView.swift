//
//  VerifyEmailPromptView.swift
//  informed

import SwiftUI

// MARK: - Email Verification Banner (shown on AccountView)

struct EmailVerificationBannerView: View {
    @EnvironmentObject var userManager: UserManager
    @State private var showSheet = false

    var body: some View {
        Button(action: { showSheet = true }) {
            HStack(spacing: 12) {
                Image(systemName: "envelope.badge.fill")
                    .font(.title3)
                    .foregroundStyle(Color.brandBlue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Verify your email")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("Required to post comments.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color.cardBackground)
            .cornerRadius(Theme.CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                    .stroke(Color.brandBlue.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        }
        .sheet(isPresented: $showSheet) {
            VerifyEmailPromptView()
        }
    }
}

// MARK: - Verify Email Prompt Sheet

struct VerifyEmailPromptView: View {
    @ObservedObject private var userManager = UserManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var phase: Phase = .send
    @State private var code: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var cooldownSeconds: Int = 0
    @State private var cooldownTimer: Timer?

    private enum Phase { case send, enter }

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: phase == .send ? "envelope.badge" : "lock.open.laptopcomputer")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.brandBlue)

                VStack(spacing: 8) {
                    Text(phase == .send ? "Verify Your Email" : "Enter the Code")
                        .font(.title2.weight(.bold))
                    Text(phase == .send
                         ? "We'll send a 6-digit code to **\(userManager.userEmail)**."
                         : "We sent a 6-digit code to **\(userManager.userEmail)**. It expires in 15 minutes."
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                }

                if phase == .enter {
                    TextField("6-digit code", text: $code)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 32, weight: .semibold, design: .monospaced))
                        .frame(maxWidth: 200)
                        .padding(.vertical, 12)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(Theme.CornerRadius.md)
                        .onChange(of: code) { _, newVal in
                            code = String(newVal.filter(\.isNumber).prefix(6))
                        }
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(Color.brandRed)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                VStack(spacing: 12) {
                    Button(action: primaryAction) {
                        Group {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text(phase == .send ? "Send Code" : "Verify")
                                    .font(.headline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canSubmit ? Color.brandBlue : Color.secondary.opacity(0.3))
                        .foregroundStyle(.white)
                        .cornerRadius(Theme.CornerRadius.md)
                    }
                    .disabled(isLoading || !canSubmit)

                    if phase == .enter {
                        Button(action: resendCode) {
                            if cooldownSeconds > 0 {
                                Text("Resend in \(cooldownSeconds)s")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Resend Code")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.brandBlue)
                            }
                        }
                        .disabled(cooldownSeconds > 0 || isLoading)
                    } else {
                        Button("Dismiss") { dismiss() }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var canSubmit: Bool {
        phase == .send || code.count == 6
    }

    private func primaryAction() {
        if phase == .send { sendCode() } else { verifyCode() }
    }

    private func sendCode() {
        guard let userId = userManager.currentUserId,
              let sessionId = userManager.currentSessionId else { return }
        isLoading = true
        errorMessage = nil
        Task {
            defer { isLoading = false }
            guard var comps = URLComponents(string: Config.Endpoints.sendVerificationEmail) else { return }
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
                if http.statusCode == 429,
                   let body = try? JSONDecoder().decode([String: Int].self, from: data),
                   let retryAfter = body["retryAfterSeconds"] {
                    startCooldown(seconds: retryAfter)
                    phase = .enter
                    return
                }
                if (200...299).contains(http.statusCode) {
                    phase = .enter
                    startCooldown(seconds: 60)
                } else {
                    errorMessage = "Failed to send code. Please try again."
                }
            } catch {
                errorMessage = "Network error. Please try again."
            }
        }
    }

    private func verifyCode() {
        guard let userId = userManager.currentUserId,
              let sessionId = userManager.currentSessionId else { return }
        isLoading = true
        errorMessage = nil
        Task {
            defer { isLoading = false }
            guard var comps = URLComponents(string: Config.Endpoints.verifyCode) else { return }
            comps.queryItems = [
                URLQueryItem(name: "userId", value: userId),
                URLQueryItem(name: "sessionId", value: sessionId),
            ]
            guard let url = comps.url else { return }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try? JSONSerialization.data(withJSONObject: ["code": code])
            req.timeoutInterval = 15
            do {
                let (data, response) = try await URLSession.shared.data(for: req)
                guard let http = response as? HTTPURLResponse else { return }
                if (200...299).contains(http.statusCode) {
                    await MainActor.run {
                        userManager.isEmailVerified = true
                        UserDefaults.standard.set(true, forKey: "stored_email_verified")
                        dismiss()
                    }
                } else if let body = try? JSONDecoder().decode([String: String].self, from: data) {
                    switch body["error"] {
                    case "wrong_code":
                        errorMessage = "Incorrect code — please try again."
                    case "code_expired":
                        errorMessage = "Code expired — tap Resend."
                        startCooldown(seconds: 0)
                    default:
                        errorMessage = "Verification failed. Please try again."
                    }
                } else {
                    errorMessage = "Verification failed. Please try again."
                }
            } catch {
                errorMessage = "Network error. Please try again."
            }
        }
    }

    private func resendCode() {
        code = ""
        errorMessage = nil
        sendCode()
    }

    private func startCooldown(seconds: Int) {
        cooldownTimer?.invalidate()
        cooldownSeconds = seconds
        guard seconds > 0 else { return }
        cooldownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if cooldownSeconds > 0 {
                cooldownSeconds -= 1
            } else {
                timer.invalidate()
            }
        }
    }
}
