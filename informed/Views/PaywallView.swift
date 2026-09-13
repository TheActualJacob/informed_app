//
//  PaywallView.swift
//  informed
//
//  Sheet that starts the 7-day free trial (or upgrades to Pro). Presented when a
//  free account tries to fact-check, when the trial or daily allowance is used
//  up, and from the usage pill / Account tab.
//

import SwiftUI
import RevenueCat

struct PaywallView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss

    /// Why the sheet opened: "none" (no allowance — start the trial), "trial"
    /// (trial checks used up), "daily" (Pro's daily cap) or the legacy "weekly".
    /// The copy is driven by the live usage status; this only matters before it loads.
    let limitType: String

    private var usage: UsageStatus { subscriptionManager.usage }

    private var limitMessage: String {
        let trialEnd = usage.trialEndDate.map { " on \($0.formatted(date: .abbreviated, time: .omitted))" } ?? ""
        switch usage.tier {
        case "pro":
            let limit = usage.dailyLimit ?? UsageStatus.proDailyLimit
            return usage.isLimitReached
                ? "You've used all \(limit) fact checks for today. Your allowance resets tomorrow."
                : "\(usage.governingRemaining) of \(limit) fact checks left today."
        case "trial":
            let limit = usage.trialLimit ?? UsageStatus.trialAllowance
            let then = "Pro starts with \(UsageStatus.proDailyLimit) a day when your trial ends\(trialEnd)."
            return usage.isLimitReached
                ? "You've used all \(limit) fact checks in your free trial. \(then)"
                : "\(usage.governingRemaining) of \(limit) trial fact checks left. \(then)"
        default:
            return "Fact-checking starts with a free \(UsageStatus.trialDays)-day trial: "
                 + "\(UsageStatus.trialAllowance) fact checks free, then \(UsageStatus.proDailyLimit) a day with Pro."
        }
    }

    private var navigationTitle: String {
        if usage.hasEntitlement { return "Your Plan" }
        return subscriptionManager.trialAvailable ? "Free Trial" : "Upgrade"
    }

    /// Monthly package price, used to compute the annual plan's savings.
    private var monthlyPrice: Decimal? { subscriptionManager.monthlyPackage?.storeProduct.price }

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
                                   text: "\(UsageStatus.proDailyLimit) fact checks / day",
                                   tag: "PRO")
                        Divider().padding(.leading, 52)

                        paywallRow(icon: "calendar",
                                   color: .brandBlue,
                                   text: "No weekly cap",
                                   tag: "PRO")
                        Divider().padding(.leading, 52)

                        paywallRow(icon: "plus.circle.fill",
                                   color: proGold,
                                   text: "+informed badge on your profile",
                                   tag: "PRO")
                        Divider().padding(.leading, 52)

                        paywallRow(icon: "star.fill",
                                   color: proGold,
                                   text: "Early access to new features",
                                   tag: "PRO")
                        Divider().padding(.leading, 52)

                        paywallRow(icon: "gift.fill",
                                   color: .brandTeal,
                                   text: "\(UsageStatus.trialAllowance) fact checks in your \(UsageStatus.trialDays)-day free trial",
                                   tag: "TRIAL")
                    }
                    .background(Color.cardBackground)
                    .cornerRadius(Theme.CornerRadius.md)
                    .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                    .padding(.horizontal)

                    // MARK: Purchase buttons / plan management
                    if usage.hasEntitlement {
                        manageCard
                    } else {
                        purchaseSection
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

                    Text(legalFooter)
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.bottom, 16)
                }
            }
            .background(Color.backgroundLight)
            .navigationTitle(navigationTitle)
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

    // MARK: - Sections

    @ViewBuilder
    private var purchaseSection: some View {
        if let offering = subscriptionManager.currentOffering {
            VStack(spacing: 12) {
                if subscriptionManager.trialAvailable {
                    Text("Try +informed free for \(UsageStatus.trialDays) days")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                ForEach(offering.availablePackages) { package in
                    PurchaseButton(package: package,
                                   monthlyPrice: monthlyPrice,
                                   trial: subscriptionManager.trialOffer(for: package)) {
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
    }

    /// Shown to trial and Pro subscribers: nothing to buy, just where to manage it.
    private var manageCard: some View {
        VStack(spacing: 12) {
            Text(usage.isTrial ? "You're on the free trial" : "You're on +informed Pro")
                .font(.headline)
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
        .padding(.horizontal)
    }

    private var legalFooter: String {
        if usage.hasEntitlement {
            return "Subscriptions auto-renew until cancelled. Manage or cancel anytime in Settings > Apple ID."
        }
        if subscriptionManager.trialAvailable {
            return "Free for \(UsageStatus.trialDays) days, then the plan price shown. The subscription auto-renews until cancelled — "
                 + "cancel in Settings > Apple ID at least a day before the trial ends to avoid being charged."
        }
        return "Subscriptions auto-renew. Cancel anytime in Settings > Apple ID."
    }

    // MARK: - Helpers

    private var proGold: Color { Color(red: 1.0, green: 0.78, blue: 0.25) }

    private func openAppleSubscriptions() {
        if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }

    @ViewBuilder
    private func paywallRow(icon: String, color: Color, text: String, tag: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 22)
                .padding(.leading, 16)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)

            Spacer()

            if tag == "PRO" {
                Text(tag)
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
                Text(tag)
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
    /// Price of the monthly package in the same offering; drives the savings badge.
    var monthlyPrice: Decimal? = nil
    /// The free-trial introductory offer, when this Apple ID is still eligible.
    var trial: StoreProductDiscount? = nil
    let action: () -> Void

    private var isAnnual: Bool {
        package.packageType == .annual
            || package.storeProduct.productIdentifier.contains("annual")
            || package.storeProduct.subscriptionPeriod?.unit == .year
    }

    private var priceLabel: String {
        package.storeProduct.localizedPriceString
    }

    /// Annual price ÷ 12, formatted in the product's own currency — derived from
    /// the live store price so App Store Connect price changes never leave a
    /// stale number in the app.
    private var perMonthEquivalent: String? {
        guard isAnnual else { return nil }
        let perMonth = package.storeProduct.price / 12
        if let formatter = package.storeProduct.priceFormatter,
           let s = formatter.string(from: perMonth as NSDecimalNumber) {
            return s
        }
        return String(format: "%.2f", NSDecimalNumber(decimal: perMonth).doubleValue)
    }

    private var periodLabel: String {
        if isAnnual, let m = perMonthEquivalent { return "/ year  (~\(m)/mo)" }
        return isAnnual ? "/ year" : "/ month"
    }

    /// "Annual · 7 days free" when the trial applies, else just the plan name.
    private var title: String {
        let plan = isAnnual ? "Annual" : "Monthly"
        guard let trial else { return plan }
        return "\(plan) · \(SubscriptionManager.trialLengthLabel(trial)) free"
    }

    /// Apple requires the post-trial price to be stated next to the trial.
    private var subtitle: String {
        trial == nil ? "\(priceLabel) \(periodLabel)" : "then \(priceLabel) \(periodLabel)"
    }

    private var savingsBadge: String? {
        guard isAnnual, let monthly = monthlyPrice, monthly > 0 else { return nil }
        let fullYear = monthly * 12
        let saved = (fullYear - package.storeProduct.price) / fullYear
        let pct = Int((NSDecimalNumber(decimal: saved).doubleValue * 100).rounded())
        return pct > 0 ? "Save \(pct)%" : nil
    }

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(subtitle)
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
