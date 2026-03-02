//
//  PrivacyPolicyView.swift
//  informed
//
//  Privacy & Security page shown in Account tab
//

import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {

                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Image(systemName: "shield.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(colors: [.brandTeal, .brandBlue], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                        Text("Privacy & Security")
                            .font(.system(size: 26, weight: .bold))
                    }
                    Text("Last updated February 2026")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)

                PrivacySection(title: "What We Collect", icon: "tray.fill",
                    """
                    We collect only the minimum data necessary to provide the fact-checking service:

                    • Username and email address (provided at registration)
                    • A securely-stored session identifier to authenticate your requests
                    • The social media links you submit for fact-checking
                    • Your device push notification token (to notify you when a fact-check completes)
                    • Basic usage analytics (views, shares — no precise location or contacts)

                    We do not collect your name, phone number, location, or contacts.
                    """)

                PrivacySection(title: "How We Use Your Data", icon: "gearshape.fill",
                    """
                    • Links you submit are processed by our AI to extract and verify claims.
                    • Fact-check results and your username are shown in the public Discover feed.
                    • Your device token is used solely to deliver push notifications about your submissions.
                    • Usage events (views, shares) help us improve the app.

                    We never sell your data to third parties.
                    """)

                PrivacySection(title: "Data Storage & Security", icon: "lock.fill",
                    """
                    • Fact-check results are stored on secure servers.
                    • Your history is saved locally on your device and can be cleared at any time from the History screen.
                    • All communication between the app and our servers is encrypted via HTTPS.
                    """)

                PrivacySection(title: "Third-Party Services", icon: "link",
                    """
                    Informed may use the following third-party services:
                    • AI inference providers (for claim analysis)
                    • CDN providers (for serving thumbnails)

                    These services operate under their own privacy policies and do not receive personally identifiable information from us.
                    """)

                PrivacySection(title: "Your Rights", icon: "person.fill.checkmark",
                    """
                    • You can clear your local fact-check history at any time via the History screen.
                    • You can permanently delete your account and all associated data from the Account screen. This removes your profile, history, and session data from our servers.
                    • You can contact us at privacy@informed-app.com to request deletion of any remaining server-side data.
                    """)

                // Contact
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.brandBlue)
                        Text("Contact Us")
                            .font(.system(size: 17, weight: .bold))
                    }
                    Text("For any privacy-related questions or data requests, reach out at:")
                        .font(.body)
                        .foregroundColor(.secondary)
                    Button {
                        HapticManager.lightImpact()
                        if let url = URL(string: "mailto:privacy@informed-app.com") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text("privacy@informed-app.com")
                            .font(.body)
                            .foregroundColor(.brandBlue)
                            .underline()
                    }
                }
                .padding(.bottom, 32)
            }
            .padding(.horizontal)
        }
        .background(Color.backgroundLight)
        .navigationTitle("Privacy & Security")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Supporting Components

private struct PrivacySection: View {
    let title: String
    let icon: String
    let text: String

    init(title: String, icon: String, _ text: String) {
        self.title = title
        self.icon = icon
        self.text = text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.brandBlue)
                    .font(.system(size: 15, weight: .semibold))
                Text(title)
                    .font(.system(size: 17, weight: .bold))
            }
            Text(text)
                .font(.body)
                .foregroundColor(.secondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
