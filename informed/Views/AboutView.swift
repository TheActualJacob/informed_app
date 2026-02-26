//
//  AboutView.swift
//  informed
//
//  About page shown in Account tab
//

import SwiftUI

struct AboutView: View {
    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {

                // App Icon + Name
                VStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.brandTeal, .brandBlue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 90, height: 90)
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 44, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .shadow(color: .brandBlue.opacity(0.35), radius: 14, x: 0, y: 6)

                    Text("Informed")
                        .font(.system(size: 30, weight: .black))
                        .foregroundStyle(
                            LinearGradient(colors: [.brandTeal, .brandBlue], startPoint: .leading, endPoint: .trailing)
                        )

                    Text("Version \(appVersion) (\(buildNumber))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 24)

                // Mission
                AboutSection(icon: "sparkles", title: "Our Mission") {
                    Text("Informed uses AI to fact-check social media content in seconds — helping you cut through misinformation and stay informed with confidence.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                // How it works
                AboutSection(icon: "gearshape.2.fill", title: "How It Works") {
                    VStack(alignment: .leading, spacing: 12) {
                        AboutStep(number: "1", text: "Share an Instagram or TikTok reel to Informed, or paste a link in the search bar.")
                        AboutStep(number: "2", text: "Our AI extracts the claims and cross-references them against trusted sources.")
                        AboutStep(number: "3", text: "You get a clear verdict, accuracy rating, and cited evidence — instantly.")
                    }
                }

                // Links
                AboutSection(icon: "link", title: "Links") {
                    VStack(spacing: 0) {
                        AboutLinkRow(icon: "safari.fill", label: "Website", url: "https://informed-app.com")
                        Divider().padding(.leading, 40)
                        AboutLinkRow(icon: "envelope.fill", label: "Contact Us", url: "mailto:hello@informed-app.com")
                        Divider().padding(.leading, 40)
                        AboutLinkRow(icon: "doc.text.fill", label: "Terms of Service", url: "https://informed-app.com/terms")
                        Divider().padding(.leading, 40)
                        AboutLinkRow(icon: "hand.raised.fill", label: "Privacy Policy", url: "https://informed-app.com/privacy")
                    }
                    .background(Color.cardBackground)
                    .cornerRadius(Theme.CornerRadius.md)
                }

                // Credits
                VStack(spacing: 4) {
                    Text("Made with ❤️")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Text("© \(Calendar.current.component(.year, from: Date())) Informed. All rights reserved.")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .padding(.bottom, 32)
            }
            .padding(.horizontal)
        }
        .background(Color.backgroundLight)
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Supporting Components

private struct AboutSection<Content: View>: View {
    let icon: String
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.brandBlue)
                    .font(.system(size: 15, weight: .semibold))
                Text(title)
                    .font(.system(size: 17, weight: .bold))
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AboutStep: View {
    let number: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 22, height: 22)
                .background(Color.brandBlue)
                .clipShape(Circle())
            Text(text)
                .font(.body)
                .foregroundColor(.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct AboutLinkRow: View {
    let icon: String
    let label: String
    let url: String

    var body: some View {
        Button {
            HapticManager.lightImpact()
            if let u = URL(string: url) { UIApplication.shared.open(u) }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .foregroundColor(.brandBlue)
                    .frame(width: 22)
                Text(label)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}
