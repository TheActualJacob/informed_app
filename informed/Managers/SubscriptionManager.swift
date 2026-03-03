//
//  SubscriptionManager.swift
//  informed
//
//  Manages RevenueCat subscription state and daily/weekly usage limits.
//

import Foundation
import RevenueCat

// MARK: - Usage Status

struct UsageStatus: Codable {
    let tier: String               // "free" | "pro"
    let dailyUsed: Int
    let dailyLimit: Int
    let weeklyUsed: Int
    let weeklyLimit: Int?          // nil for pro (no weekly cap)
    let subscriptionExpiresAt: String?

    enum CodingKeys: String, CodingKey {
        case tier
        case dailyUsed          = "daily_used"
        case dailyLimit         = "daily_limit"
        case weeklyUsed         = "weekly_used"
        case weeklyLimit        = "weekly_limit"
        case subscriptionExpiresAt = "subscription_expires_at"
    }

    var isPro: Bool { tier == "pro" }
    var dailyRemaining: Int { max(0, dailyLimit - dailyUsed) }
    var weeklyRemaining: Int? {
        guard let wl = weeklyLimit else { return nil }
        return max(0, wl - weeklyUsed)
    }
}

// MARK: - SubscriptionManager

@MainActor
final class SubscriptionManager: ObservableObject {

    static let shared = SubscriptionManager()

    // RevenueCat product identifiers – must match App Store Connect
    static let monthlyProductID = "informed_pro_monthly"
    static let annualProductID  = "informed_pro_annual"
    static let entitlementID    = "pro"

    // RevenueCat public API key
    static let revenueCatAPIKey = "test_PwntiSghuGhWdNjbQkjbtHCGbTn"

    // MARK: - Published state

    @Published var isPro: Bool = false
    @Published var usage: UsageStatus = UsageStatus(
        tier: "free", dailyUsed: 0, dailyLimit: 5,
        weeklyUsed: 0, weeklyLimit: 10, subscriptionExpiresAt: nil
    )
    @Published var currentOffering: Offering? = nil
    @Published var isLoadingOffering: Bool = false
    @Published var isPurchasing: Bool = false
    @Published var purchaseError: String? = nil

    // Paywall trigger
    @Published var showPaywall: Bool = false
    @Published var paywallLimitType: String = "daily"  // "daily" | "weekly"

    private init() {}

    // MARK: - Configure

    /// Call once on app launch, after UserManager is authenticated.
    func configure() {
        Purchases.logLevel = .error
        Purchases.configure(withAPIKey: Self.revenueCatAPIKey)
    }

    /// Set RevenueCat's app user ID to the backend's userid so they're in sync.
    func identify(userId: String) {
        Purchases.shared.logIn(userId) { [weak self] _, _, _ in
            Task { await self?.syncCustomerInfo() }
        }
    }

    func logout() {
        Purchases.shared.logOut { _, _ in }
        isPro = false
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

    /// Sync CustomerInfo from RevenueCat and update isPro.
    func syncCustomerInfo() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            isPro = info.entitlements[Self.entitlementID]?.isActive == true
        } catch {
            print("[SubscriptionManager] syncCustomerInfo error: \(error)")
        }
    }

    /// Sync subscription tier with the backend then refresh usage status.
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
            let (data, _) = try await URLSession.shared.data(for: req)
            if let decoded = try? JSONDecoder().decode(UsageStatus.self, from: data) {
                usage = decoded
                isPro = decoded.isPro
            }
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
            usage = decoded
            isPro  = decoded.isPro
        } catch {
            print("[SubscriptionManager] refreshUsage error: \(error)")
        }
    }

    // MARK: - Limit handling

    /// Called when the backend returns a 429 limit_reached response.
    func handleLimitReached(type: String) {
        paywallLimitType = type
        showPaywall = true
    }
}
