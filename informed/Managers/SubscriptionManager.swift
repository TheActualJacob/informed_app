//
//  SubscriptionManager.swift
//  informed
//
//  Manages RevenueCat subscription state and the fact-check allowance.
//
//  Tiers (mirrors informedBackend/subscription_tiers.py):
//    free  – no allowance; the 7-day free trial is the only way to fact-check
//    trial – 7 fact checks for the whole trial, then auto-renews as Pro
//    pro   – 15 fact checks per day, no weekly cap
//

import Foundation
import Combine
import RevenueCat

// MARK: - Usage Status

struct UsageStatus: Codable {
    let tier: String               // "free" | "trial" | "pro"
    let dailyUsed: Int
    let dailyLimit: Int?           // 15 for pro, nil otherwise
    let weeklyUsed: Int            // legacy: mirrors the governing window for non-pro tiers
    let weeklyLimit: Int?
    let trialUsed: Int?
    let trialLimit: Int?
    let trialEndsAt: String?
    let limitType: String?         // "none" | "trial" | "daily"
    let used: Int?
    let limit: Int?
    let remaining: Int?
    let limitReached: Bool?
    let subscriptionExpiresAt: String?
    let subscriptionStartedAt: String?

    enum CodingKeys: String, CodingKey {
        case tier
        case dailyUsed             = "daily_used"
        case dailyLimit            = "daily_limit"
        case weeklyUsed            = "weekly_used"
        case weeklyLimit           = "weekly_limit"
        case trialUsed             = "trial_used"
        case trialLimit            = "trial_limit"
        case trialEndsAt           = "trial_ends_at"
        case limitType             = "limit_type"
        case used, limit, remaining
        case limitReached          = "limit_reached"
        case subscriptionExpiresAt = "subscription_expires_at"
        case subscriptionStartedAt = "subscription_started_at"
    }

    /// Allowances, mirrored from the backend for copy shown before the first response.
    static let trialAllowance = 7
    static let trialDays      = 7
    static let proDailyLimit  = 15

    /// A signed-out / not-yet-fetched account: free, no allowance.
    static let placeholder = UsageStatus(
        tier: "free", dailyUsed: 0, dailyLimit: nil, weeklyUsed: 0, weeklyLimit: 0,
        trialUsed: nil, trialLimit: nil, trialEndsAt: nil, limitType: "none",
        used: 0, limit: 0, remaining: 0, limitReached: true,
        subscriptionExpiresAt: nil, subscriptionStartedAt: nil
    )

    var isPro: Bool   { tier == "pro" }
    var isTrial: Bool { tier == "trial" }
    /// Pro or trial — an active App Store entitlement.
    var hasEntitlement: Bool { isPro || isTrial }

    var dailyRemaining: Int? {
        guard let dl = dailyLimit else { return nil }
        return max(0, dl - dailyUsed)
    }
    var weeklyRemaining: Int? {
        guard let wl = weeklyLimit else { return nil }
        return max(0, wl - weeklyUsed)
    }

    // MARK: Governing window
    //
    // Pro is capped per day, a trial by its 7-check allowance, and a free
    // account has no allowance at all. Every counter and paywall string reads
    // from these helpers so it describes the window that actually applies.

    /// "daily" (pro), "trial", or "none" (free). Older backends only send the
    /// daily/weekly pair, so fall back to the tier.
    var governingLimitType: String {
        if let limitType { return limitType }
        return isPro ? "daily" : (isTrial ? "trial" : "none")
    }
    /// nil = unlimited
    var governingLimit: Int? {
        if let limit { return limit }
        switch governingLimitType {
        case "daily": return dailyLimit
        case "trial": return trialLimit ?? weeklyLimit ?? Self.trialAllowance
        default:      return weeklyLimit ?? 0
        }
    }
    var governingUsed: Int {
        if let used { return used }
        return governingLimitType == "daily" ? dailyUsed : weeklyUsed
    }
    var governingRemaining: Int {
        if let remaining { return remaining }
        guard let limit = governingLimit else { return Int.max }
        return max(0, limit - governingUsed)
    }
    var isLimitReached: Bool { limitReached ?? (governingRemaining == 0) }
    /// "today" / "in your trial" / "" — the window a counter describes.
    var governingPeriodLabel: String {
        switch governingLimitType {
        case "daily": return "today"
        case "trial": return "in your trial"
        default:      return ""
        }
    }

    var trialEndDate: Date? { Self.parseDate(trialEndsAt ?? subscriptionExpiresAt) }
    var expiryDate: Date? { Self.parseDate(subscriptionExpiresAt) }

    /// The backend sends naive-UTC `isoformat()` strings ("2026-09-20T10:00:00[.ffffff]");
    /// RevenueCat sends a trailing Z. Accept both.
    static func parseDate(_ s: String?) -> Date? {
        guard let s, !s.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: s) { return d }
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: s) { return d }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        for fmt in ["yyyy-MM-dd'T'HH:mm:ss.SSSSSS", "yyyy-MM-dd'T'HH:mm:ss"] {
            f.dateFormat = fmt
            if let d = f.date(from: s) { return d }
        }
        return nil
    }
}

// MARK: - SubscriptionManager

@MainActor
final class SubscriptionManager: ObservableObject {

    static let shared = SubscriptionManager()

    // RevenueCat product identifiers – must match App Store Connect
    static let monthlyProductID = "informed_pro_monthly"
    static let annualProductID  = "informed_pro_annual"
    static let entitlementID    = "Informed Pro"

    // RevenueCat public API key
    static let revenueCatAPIKey = "appl_MzFXoJPTkITfCZLOmoXrJAPMeNp"

    // MARK: - Published state

    /// True while the "Informed Pro" entitlement is active — during the free
    /// trial as well as on a paid plan. Check `isTrial` to tell them apart.
    @Published var isPro: Bool = false {
        didSet { storeTierInAppGroup() }
    }
    /// True during the 7-day free trial.
    @Published var isTrial: Bool = false {
        didSet { storeTierInAppGroup() }
    }
    @Published var usage: UsageStatus = .placeholder

    /// "free" | "trial" | "pro" — what the App Group and the share extension see.
    var currentTier: String { isPro ? (isTrial ? "trial" : "pro") : "free" }

    /// Live monthly price from the store (e.g. "$8.99"), once the offering has loaded.
    var monthlyPriceString: String? { monthlyPackage?.storeProduct.localizedPriceString }
    var monthlyPackage: Package? {
        currentOffering?.availablePackages.first(where: {
            $0.packageType == .monthly || $0.storeProduct.productIdentifier == Self.monthlyProductID
        })
    }
    @Published var currentOffering: Offering? = nil
    /// Free-trial / intro eligibility per product id, from RevenueCat (Apple
    /// grants an introductory offer once per Apple ID per subscription group).
    @Published var introEligibility: [String: IntroEligibilityStatus] = [:]
    @Published var isLoadingOffering: Bool = false
    @Published var isPurchasing: Bool = false
    @Published var purchaseError: String? = nil

    // Paywall trigger
    @Published var showPaywall: Bool = false
    @Published var paywallLimitType: String = "none"  // "none" | "trial" | "daily"

    /// Set once per launch after the backend has been told about an entitlement
    /// it didn't know of (see refreshUsage), so a genuinely free account can't
    /// loop on the sync.
    private var reconciledWithStore = false

    private init() {}

    // MARK: - Configure

    /// No-op: RevenueCat is now configured unconditionally in informedApp.init().
    /// Kept for backwards compatibility in case anything still calls it.
    func configure() {}

    /// Log the user into RevenueCat and sync their subscription state.
    /// Async so callers can await and be sure isPro is accurate afterwards.
    func identify(userId: String) async {
        do {
            _ = try await Purchases.shared.logIn(userId)
        } catch {
            print("[SubscriptionManager] logIn error: \(error)")
        }
        await syncCustomerInfo()
        // Prefetch the offering + trial eligibility so the paywall opens populated.
        await fetchOffering()
    }

    func logout() {
        Purchases.shared.logOut { _, _ in }
        isPro = false
        isTrial = false
        usage = .placeholder
    }

    // MARK: - Offerings

    func fetchOffering() async {
        isLoadingOffering = true
        defer { isLoadingOffering = false }
        do {
            let offerings = try await Purchases.shared.offerings()
            currentOffering = offerings.current
        } catch {
            print("[SubscriptionManager] fetchOffering error: \(error)")
        }
        let ids = currentOffering?.availablePackages.map { $0.storeProduct.productIdentifier } ?? []
        if !ids.isEmpty {
            let result = await Purchases.shared.checkTrialOrIntroDiscountEligibility(productIdentifiers: ids)
            introEligibility = result.mapValues { $0.status }
        }
        for package in currentOffering?.availablePackages ?? [] {
            let product = package.storeProduct
            let intro = product.introductoryDiscount.map {
                "\($0.paymentMode == .freeTrial ? "free trial" : "intro price") \(Self.trialLengthLabel($0))"
            } ?? "none"
            let status = introEligibility[product.productIdentifier].map { "\($0)" } ?? "unknown"
            print("[SubscriptionManager] \(product.productIdentifier): \(product.localizedPriceString), intro offer: \(intro), eligibility: \(status)")
        }
    }

    // MARK: - Free trial

    /// The free-trial introductory offer on a package, if the store has one and
    /// this Apple ID hasn't used it. `.unknown` is treated as available: StoreKit
    /// makes the final call in the purchase sheet.
    func trialOffer(for package: Package) -> StoreProductDiscount? {
        guard let discount = package.storeProduct.introductoryDiscount,
              discount.paymentMode == .freeTrial else { return nil }
        switch introEligibility[package.storeProduct.productIdentifier] ?? .unknown {
        case .ineligible, .noIntroOfferExists: return nil
        default: return discount
        }
    }

    /// True when any plan in the offering still carries a free trial for this Apple ID.
    var trialAvailable: Bool {
        currentOffering?.availablePackages.contains { trialOffer(for: $0) != nil } ?? false
    }

    /// "7 days", "1 month", … for an introductory offer's period.
    static func trialLengthLabel(_ discount: StoreProductDiscount) -> String {
        let period = discount.subscriptionPeriod
        let n = period.value
        switch period.unit {
        case .day:   return "\(n) day\(n == 1 ? "" : "s")"
        case .week:  return "\(n * 7) days"
        case .month: return "\(n) month\(n == 1 ? "" : "s")"
        case .year:  return "\(n) year\(n == 1 ? "" : "s")"
        @unknown default: return "\(n)"
        }
    }

    // MARK: - Purchase

    func purchase(package: Package) async throws {
        isPurchasing = true
        purchaseError = nil
        defer { isPurchasing = false }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if !result.userCancelled {
                await syncCustomerInfo()
                await syncWithBackend()
            }
        } catch {
            purchaseError = error.localizedDescription
            throw error
        }
    }

    func restorePurchases() async {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            _ = try await Purchases.shared.restorePurchases()
            await syncCustomerInfo()
            await syncWithBackend()
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    // MARK: - Sync

    /// Sync CustomerInfo from RevenueCat and update isPro / isTrial.
    func syncCustomerInfo() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            let entitlement = info.entitlements[Self.entitlementID]
            isPro   = entitlement?.isActive == true
            isTrial = isPro && entitlement?.periodType == .trial
        } catch {
            print("[SubscriptionManager] syncCustomerInfo error: \(error)")
        }
    }

    /// Tell the backend to re-read the subscription from RevenueCat (it sets the
    /// tier to free / trial / pro), then refresh usage.
    func syncWithBackend() async {
        guard let userId    = UserManager.shared.currentUserId,
              let sessionId = UserManager.shared.currentSessionId else { return }

        guard var urlComponents = URLComponents(string: Config.Endpoints.subscriptionSync) else { return }
        urlComponents.queryItems = [
            URLQueryItem(name: "userId",    value: userId),
            URLQueryItem(name: "sessionId", value: sessionId),
        ]
        guard let url = urlComponents.url else { return }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Pass the RC customer id so the backend can fetch from RC API
        let body: [String: String] = ["revenuecat_customer_id": userId]
        req.httpBody = try? JSONEncoder().encode(body)

        do {
            _ = try await URLSession.shared.data(for: req)
        } catch {
            print("[SubscriptionManager] syncWithBackend error: \(error)")
        }

        await refreshUsage()
    }

    /// Fetch latest usage stats from the backend.
    func refreshUsage() async {
        guard let userId    = UserManager.shared.currentUserId,
              let sessionId = UserManager.shared.currentSessionId else { return }

        guard var urlComponents = URLComponents(string: Config.Endpoints.usageStatus) else { return }
        urlComponents.queryItems = [
            URLQueryItem(name: "userId",    value: userId),
            URLQueryItem(name: "sessionId", value: sessionId),
        ]
        guard let url = urlComponents.url else { return }

        do {
            let (data, _) = try await URLSession.shared.data(for: URLRequest(url: url))
            let decoded = try JSONDecoder().decode(UsageStatus.self, from: data)
            // The backend learns about trial conversions and renewals from the
            // RevenueCat webhook. If it still says free while the store says the
            // entitlement is active (a trial that just rolled into Pro, a late
            // webhook), push one sync so the allowance matches the subscription.
            if !decoded.hasEntitlement, !reconciledWithStore,
               let info = try? await Purchases.shared.customerInfo(),
               info.entitlements[Self.entitlementID]?.isActive == true {
                reconciledWithStore = true
                print("[SubscriptionManager] backend says free but the entitlement is active — syncing")
                await syncWithBackend()   // refreshes usage again on its way out
                return
            }
            usage   = decoded
            isPro   = decoded.hasEntitlement
            isTrial = decoded.isTrial
        } catch {
            print("[SubscriptionManager] refreshUsage error: \(error)")
        }
    }

    // MARK: - Limit handling

    /// Called when the backend returns a 429 limit_reached response.
    func handleLimitReached(type: String) {
        // Older builds and backends say "weekly"; the tier says what that means now.
        paywallLimitType = (type == "weekly") ? usage.governingLimitType : type
        showPaywall = true
    }

    // MARK: - App Group

    /// Keep the App Group in sync so the Share Extension and the Dynamic Island
    /// widget can read the tier without a network call.
    private func storeTierInAppGroup() {
        let defaults = UserDefaults(suiteName: "group.rob")
        defaults?.set(isPro, forKey: "is_pro_user")
        defaults?.set(currentTier, forKey: "subscription_tier")
    }
}
