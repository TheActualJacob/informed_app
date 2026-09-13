//
//  UsageCounterView.swift
//  informed
//
//  Pill badge showing the fact-check allowance: "15/day" on Pro, "n / 7 trial"
//  during the free trial, and a "Start free trial" prompt otherwise. Tapping
//  opens the paywall unless the account is on a paid plan.
//

import SwiftUI

struct UsageCounterView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var showPaywall = false

    private var usage: UsageStatus { subscriptionManager.usage }
    private var isPaidPro: Bool { subscriptionManager.isPro && !subscriptionManager.isTrial }

    var body: some View {
        Button(action: handleTap) {
            HStack(spacing: 5) {
                if isPaidPro {
                    Image(systemName: "plus.circle.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(proGold)
                    Text("\(UsageStatus.proDailyLimit)/day")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(proGold)
                } else if subscriptionManager.isTrial {
                    Image(systemName: "checkmark.seal")
                        .font(.caption2)
                        .foregroundColor(counterColor)
                    Text("\(usage.governingUsed) / \(usage.governingLimit ?? UsageStatus.trialAllowance)")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(counterColor)
                        .contentTransition(.numericText())
                    Text("trial")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                        .foregroundColor(.brandBlue)
                    Text("Start free trial")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.brandBlue)
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
            PaywallView(limitType: usage.governingLimitType)
                .environmentObject(subscriptionManager)
        }
        .task {
            await subscriptionManager.refreshUsage()
        }
    }

    // MARK: - Helpers

    private var proGold: Color { Color(red: 1.0, green: 0.78, blue: 0.25) }

    private var remaining: Int { usage.governingRemaining }

    private var counterColor: Color {
        if remaining == 0 { return .brandRed }
        if remaining == 1 { return .brandYellow }
        return .secondary
    }

    private var pillBackground: Color {
        isPaidPro ? proGold.opacity(0.12) : Color.secondary.opacity(0.08)
    }

    private var borderColor: Color {
        isPaidPro ? proGold.opacity(0.4) : Color.secondary.opacity(0.2)
    }

    private func handleTap() {
        if !isPaidPro {
            showPaywall = true
            Task { await subscriptionManager.fetchOffering() }
        }
    }
}
