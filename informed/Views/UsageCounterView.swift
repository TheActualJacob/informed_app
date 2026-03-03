//
//  UsageCounterView.swift
//  informed
//
//  Pill badge showing daily usage. Tapping opens the paywall for free users.
//

import SwiftUI

struct UsageCounterView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var showPaywall = false

    var body: some View {
        Button(action: handleTap) {
            HStack(spacing: 5) {
                if subscriptionManager.isPro {
                    Image(systemName: "plus.circle.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(proGold)
                    Text("15/day")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(proGold)
                } else {
                    Image(systemName: "checkmark.seal")
                        .font(.caption2)
                        .foregroundColor(counterColor)
                    Text("\(subscriptionManager.usage.dailyUsed) / \(subscriptionManager.usage.dailyLimit)")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(counterColor)
                    Text("today")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(pillBackground)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showPaywall) {
            PaywallView(limitType: "daily")
                .environmentObject(subscriptionManager)
        }
        .task {
            await subscriptionManager.refreshUsage()
        }
    }

    // MARK: - Helpers

    private var proGold: Color { Color(red: 1.0, green: 0.78, blue: 0.25) }

    private var remaining: Int { subscriptionManager.usage.dailyRemaining }

    private var counterColor: Color {
        if remaining <= 1 { return .brandRed }
        if remaining <= 2 { return .brandYellow }
        return .secondary
    }

    private var pillBackground: Color {
        subscriptionManager.isPro
            ? proGold.opacity(0.12)
            : Color.secondary.opacity(0.08)
    }

    private var borderColor: Color {
        subscriptionManager.isPro
            ? proGold.opacity(0.4)
            : Color.secondary.opacity(0.2)
    }

    private func handleTap() {
        if !subscriptionManager.isPro {
            showPaywall = true
            Task { await subscriptionManager.fetchOffering() }
        }
    }
}
