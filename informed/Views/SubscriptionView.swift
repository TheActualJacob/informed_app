//
//  SubscriptionView.swift
//  informed
//
//  Manage current subscription plan, view usage stats, and upgrade/downgrade.
//

import SwiftUI

struct SubscriptionView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    @State private var showPaywall = false

    private var proGold: Color { Color(red: 1.0, green: 0.78, blue: 0.25) }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // MARK: Plan status card
                planStatusCard

                // MARK: Usage this period
                usageCard

                // MARK: Actions
                actionButtons
            }
            .padding()
        }
        .background(Color.backgroundLight)
        .navigationTitle(subscriptionManager.isPro ? "+informed Pro" : "Subscription")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) {
            PaywallView(limitType: "daily")
                .environmentObject(subscriptionManager)
        }
        .task {
            await subscriptionManager.refreshUsage()
            await subscriptionManager.fetchOffering()
        }
    }

    // MARK: - Plan status card

    private var planStatusCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(subscriptionManager.isPro ? "+informed Pro" : "Free Plan")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(
                            subscriptionManager.isPro
                                ? LinearGradient(colors: [Color.brandBlue, Color.brandTeal],
                                                 startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [.primary, .primary],
                                                 startPoint: .leading, endPoint: .trailing)
                        )

                    if subscriptionManager.isPro,
                       let expiresStr = subscriptionManager.usage.subscriptionExpiresAt,
                       let date = ISO8601DateFormatter().date(from: expiresStr) {
                        Text("Renews \(date.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if !subscriptionManager.isPro {
                        Text("5 checks/day · 10 checks/week")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if subscriptionManager.isPro {
                    Text("✦")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(proGold)
                        .frame(width: 52, height: 52)
                        .background(proGold.opacity(0.15))
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                        .frame(width: 52, height: 52)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Circle())
                }
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(Theme.CornerRadius.md)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    // MARK: - Usage card

    private var usageCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Usage")
                .font(.headline)

            usageRow(
                label: "Today",
                used: subscriptionManager.usage.dailyUsed,
                limit: subscriptionManager.usage.dailyLimit,
                color: dailyBarColor
            )

            if let wl = subscriptionManager.usage.weeklyLimit {
                usageRow(
                    label: "This week",
                    used: subscriptionManager.usage.weeklyUsed,
                    limit: wl,
                    color: .brandBlue
                )
            } else {
                HStack {
                    Text("This week")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Unlimited")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(proGold)
                }
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(Theme.CornerRadius.md)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    @ViewBuilder
    private func usageRow(label: String, used: Int, limit: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(used) / \(limit)")
                    .font(.subheadline.weight(.semibold))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.15))
                        .frame(height: 6)
                    Capsule().fill(color)
                        .frame(width: geo.size.width * min(CGFloat(used) / CGFloat(max(limit, 1)), 1.0),
                               height: 6)
                        .animation(.easeInOut, value: used)
                }
            }
            .frame(height: 6)
        }
    }

    private var dailyBarColor: Color {
        let remaining = subscriptionManager.usage.dailyRemaining
        if remaining <= 1 { return .brandRed }
        if remaining <= 2 { return .brandYellow }
        return .brandGreen
    }

    // MARK: - Action buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if !subscriptionManager.isPro {
                Button(action: { showPaywall = true }) {
                    HStack {
                        Text("✦")
                        Text("Upgrade to +informed Pro")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [Color.brandBlue, Color.brandTeal],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .cornerRadius(Theme.CornerRadius.md)
                }
            }

            if subscriptionManager.isPro {
                Button(action: openAppleSubscriptions) {
                    HStack {
                        Image(systemName: "gear")
                        Text("Manage in App Store")
                    }
                    .font(.subheadline)
                    .foregroundColor(.brandBlue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.brandBlue.opacity(0.08))
                    .cornerRadius(Theme.CornerRadius.md)
                }
            }

            Button {
                Task { await subscriptionManager.restorePurchases() }
            } label: {
                Text("Restore Purchases")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.secondary.opacity(0.08))
                    .cornerRadius(Theme.CornerRadius.md)
            }
        }
    }

    private func openAppleSubscriptions() {
        if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }
}
