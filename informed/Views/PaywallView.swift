//
//  PaywallView.swift
//  informed
//
//  Full-screen paywall presented when a user hits their daily or weekly limit.
//

import SwiftUI
import RevenueCat

struct PaywallView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss

    let limitType: String  // "daily" | "weekly"

    private var limitMessage: String {
        let usage = subscriptionManager.usage
        if limitType == "weekly" {
            return "You've used all \(usage.weeklyLimit ?? 10) free fact checks this week."
        }
        return "You've used all \(usage.dailyLimit) free fact checks today."
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 28) {

                    // MARK: Header
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.brandBlue, Color.brandTeal],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                            Text("✦")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.white)
                        }

                        Text("+informed")
                            .font(.system(size: 32, weight: .black))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.brandBlue, Color.brandTeal],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )

                        Text(limitMessage)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 8)

                    // MARK: Comparison table
                    VStack(spacing: 0) {
                        paywallRow(icon: "checkmark.seal.fill",
                                   color: .brandGreen,
                                   text: "15 fact checks / day",
                                   proOnly: true)
                        Divider().padding(.leading, 52)

                        paywallRow(icon: "calendar",
                                   color: .brandBlue,
                                   text: "No weekly cap",
                                   proOnly: true)
                        Divider().padding(.leading, 52)

                        paywallRow(icon: "plus.circle.fill",
                                   color: proGold,
                                   text: "+informed badge on your profile",
                                   proOnly: true)
                        Divider().padding(.leading, 52)

                        paywallRow(icon: "star.fill",
                                   color: proGold,
                                   text: "Early access to new features",
                                   proOnly: true)
                        Divider().padding(.leading, 52)

                        paywallRow(icon: "bolt.fill",
                                   color: .brandTeal,
                                   text: "5 fact checks / day (free)",
                                   proOnly: false)
                        Divider().padding(.leading, 52)

                        paywallRow(icon: "clock.fill",
                                   color: .secondary,
                                   text: "10 checks / week (free)",
                                   proOnly: false)
                    }
                    .background(Color.cardBackground)
                    .cornerRadius(Theme.CornerRadius.md)
                    .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                    .padding(.horizontal)

                    // MARK: Purchase buttons
                    if let offering = subscriptionManager.currentOffering {
                        VStack(spacing: 12) {
                            ForEach(offering.availablePackages) { package in
                                PurchaseButton(package: package) {
                                    Task {
                                        try? await subscriptionManager.purchase(package: package)
                                        if subscriptionManager.isPro { dismiss() }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        ProgressView()
                            .padding()
                            .onAppear {
                                Task { await subscriptionManager.fetchOffering() }
                            }
                    }

                    // Restore
                    Button("Restore Purchases") {
                        Task {
                            await subscriptionManager.restorePurchases()
                            if subscriptionManager.isPro { dismiss() }
                        }
                    }
                    .font(.footnote)
                    .foregroundColor(.secondary)

                    Text("Subscriptions auto-renew. Cancel anytime in Settings > Apple ID.")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.bottom, 16)
                }
            }
            .background(Color.backgroundLight)
            .navigationTitle("Upgrade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not Now") { dismiss() }
                        .foregroundColor(.secondary)
                }
            }
            .overlay {
                if subscriptionManager.isPurchasing {
                    ZStack {
                        Color.black.opacity(0.3).ignoresSafeArea()
                        ProgressView("Processing…")
                            .padding(24)
                            .background(Color.cardBackground)
                            .cornerRadius(12)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var proGold: Color { Color(red: 1.0, green: 0.78, blue: 0.25) }

    @ViewBuilder
    private func paywallRow(icon: String, color: Color, text: String, proOnly: Bool) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 22)
                .padding(.leading, 16)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)

            Spacer()

            if proOnly {
                Text("PRO")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        LinearGradient(
                            colors: [Color.brandBlue, Color.brandTeal],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .cornerRadius(4)
                    .padding(.trailing, 16)
            } else {
                Text("FREE")
                    .font(.caption2.weight(.medium))
                    .foregroundColor(.secondary)
                    .padding(.trailing, 16)
            }
        }
        .padding(.vertical, 14)
    }
}

// MARK: - PurchaseButton

private struct PurchaseButton: View {
    let package: Package
    let action: () -> Void

    private var isAnnual: Bool {
        package.storeProduct.productIdentifier.contains("annual")
    }

    private var priceLabel: String {
        package.storeProduct.localizedPriceString
    }

    private var periodLabel: String {
        isAnnual ? "/ year  (~$4.17/mo)" : "/ month"
    }

    private var savingsBadge: String? {
        isAnnual ? "Save 17%" : nil
    }

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(isAnnual ? "Annual" : "Monthly")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("\(priceLabel) \(periodLabel)")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.85))
                }

                Spacer()

                if let badge = savingsBadge {
                    Text(badge)
                        .font(.caption.weight(.bold))
                        .foregroundColor(Color(red: 1.0, green: 0.78, blue: 0.25))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(6)
                }
            }
            .padding()
            .background(
                isAnnual
                    ? LinearGradient(colors: [Color.brandBlue, Color.brandTeal],
                                     startPoint: .leading, endPoint: .trailing)
                    : LinearGradient(colors: [Color.brandBlue.opacity(0.7), Color.brandBlue.opacity(0.7)],
                                     startPoint: .leading, endPoint: .trailing)
            )
            .cornerRadius(Theme.CornerRadius.md)
        }
    }
}
