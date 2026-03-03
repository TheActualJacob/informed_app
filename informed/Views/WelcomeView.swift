//
//  WelcomeView.swift
//  informed
//
//  Post-signup onboarding: mission statement + free/pro tier explainer.
//

import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    var onContinue: () -> Void

    @State private var appearedPhase: Int = 0   // drives staggered entrance
    @State private var showPaywall = false

    // MARK: - Body

    var body: some View {
        ZStack {
            // Full-bleed gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.08, blue: 0.18),
                    Color(red: 0.06, green: 0.14, blue: 0.30),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Soft glow behind logo
            Circle()
                .fill(Color.brandBlue.opacity(0.15))
                .frame(width: 380, height: 380)
                .blur(radius: 80)
                .offset(y: -120)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // ── Logo & headline ──────────────────────────────────────
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.brandBlue, Color.brandTeal],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 86, height: 86)
                                .shadow(color: Color.brandBlue.opacity(0.5), radius: 24, y: 8)

                            Text("✦")
                                .font(.system(size: 38, weight: .heavy))
                                .foregroundColor(.white)
                        }
                        .scaleEffect(appearedPhase >= 1 ? 1 : 0.4)
                        .opacity(appearedPhase >= 1 ? 1 : 0)

                        VStack(spacing: 6) {
                            Text("Welcome to")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                                .tracking(1.5)

                            Text("informed")
                                .font(.system(size: 42, weight: .black))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.white, Color(white: 0.85)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .opacity(appearedPhase >= 1 ? 1 : 0)
                        .offset(y: appearedPhase >= 1 ? 0 : 14)
                    }
                    .padding(.top, 64)
                    .padding(.bottom, 36)

                    // ── Mission card ─────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 10) {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.brandTeal, Color.brandBlue],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    )
                                )
                            Text("Our Commitment")
                                .font(.subheadline.weight(.bold))
                                .foregroundColor(.white)
                        }

                        Text("Informed is built on a simple belief: everyone deserves access to accurate information. We use advanced AI to fact-check social media content and we're committed to keeping that free.")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.78))
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.white.opacity(0.07))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 20)
                    .opacity(appearedPhase >= 2 ? 1 : 0)
                    .offset(y: appearedPhase >= 2 ? 0 : 18)

                    // ── Cost reality card ────────────────────────────────────
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 10) {
                            Image(systemName: "cpu.fill")
                                .foregroundColor(proGold)
                            Text("The Reality of AI")
                                .font(.subheadline.weight(.bold))
                                .foregroundColor(.white)
                        }

                        Text("Every fact-check runs multiple AI models — transcribing audio, analyzing claims, and cross-referencing thousands of sources. That costs real money. To keep the lights on, we offer a Pro tier for power users.")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.78))
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.white.opacity(0.07))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .opacity(appearedPhase >= 3 ? 1 : 0)
                    .offset(y: appearedPhase >= 3 ? 0 : 18)

                    // ── Tier comparison ──────────────────────────────────────
                    HStack(spacing: 12) {
                        tierCard(
                            title: "Free",
                            icon: "sparkle",
                            iconColor: .white.opacity(0.8),
                            features: [
                                ("checkmark.circle.fill", .brandGreen,  "5 checks / day"),
                                ("checkmark.circle.fill", .brandGreen,  "10 checks / week"),
                                ("checkmark.circle.fill", .brandGreen,  "Full AI analysis"),
                                ("checkmark.circle.fill", .brandGreen,  "All platforms"),
                            ],
                            background: Color.white.opacity(0.06),
                            border: Color.white.opacity(0.1),
                            badge: nil
                        )

                        tierCard(
                            title: "+Pro",
                            icon: "✦",
                            iconColor: proGold,
                            features: [
                                ("checkmark.circle.fill", proGold,      "15 checks / day"),
                                ("checkmark.circle.fill", proGold,      "No weekly cap"),
                                ("checkmark.circle.fill", proGold,      "+informed badge"),
                                ("checkmark.circle.fill", proGold,      "Early access"),
                            ],
                            background: LinearGradient(
                                        colors: [Color.brandBlue.opacity(0.25), Color.brandTeal.opacity(0.18)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing),
                            border: Color.brandBlue.opacity(0.5),
                            badge: "$4.99 / mo"
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .opacity(appearedPhase >= 4 ? 1 : 0)
                    .offset(y: appearedPhase >= 4 ? 0 : 18)

                    // ── CTA buttons ──────────────────────────────────────────
                    VStack(spacing: 12) {
                        // Upgrade button (secondary)
                        Button {
                            Task { await subscriptionManager.fetchOffering() }
                            showPaywall = true
                        } label: {
                            HStack(spacing: 8) {
                                Text("✦")
                                    .font(.system(size: 14, weight: .heavy))
                                    .foregroundColor(proGold)
                                Text("Upgrade to +informed Pro")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.white.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(
                                                LinearGradient(
                                                    colors: [Color.brandBlue.opacity(0.8), Color.brandTeal.opacity(0.8)],
                                                    startPoint: .leading, endPoint: .trailing
                                                ),
                                                lineWidth: 1.5
                                            )
                                    )
                            )
                        }

                        // Continue free button (primary action)
                        Button(action: onContinue) {
                            Text("Start with Free")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(Color(red: 0.04, green: 0.08, blue: 0.18))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 17)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(.white)
                                        .shadow(color: .white.opacity(0.2), radius: 12, y: 4)
                                )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .opacity(appearedPhase >= 5 ? 1 : 0)
                    .offset(y: appearedPhase >= 5 ? 0 : 18)

                    Text("You can always upgrade later from your Account tab.")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.35))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 12)
                        .padding(.bottom, 48)
                        .opacity(appearedPhase >= 5 ? 1 : 0)
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(limitType: "daily")
                .environmentObject(subscriptionManager)
                .onDisappear {
                    if subscriptionManager.isPro { onContinue() }
                }
        }
        .onAppear { runEntrance() }
    }

    // MARK: - Helpers

    private var proGold: Color { Color(red: 1.0, green: 0.80, blue: 0.30) }

    private func runEntrance() {
        let delays: [Double] = [0, 0.15, 0.30, 0.45, 0.60]
        for (i, delay) in delays.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                    appearedPhase = i + 1
                }
            }
        }
    }

    // MARK: - Tier card builder

    @ViewBuilder
    private func tierCard<B: ShapeStyle, BD: ShapeStyle>(
        title: String,
        icon: String,
        iconColor: Color,
        features: [(String, Color, String)],
        background: B,
        border: BD,
        badge: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 6) {
                if icon == "✦" {
                    Text(icon)
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundColor(iconColor)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                Text(title)
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(.white)
                Spacer()
                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(proGold)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(proGold.opacity(0.15))
                        .cornerRadius(6)
                }
            }

            VStack(alignment: .leading, spacing: 9) {
                ForEach(Array(features.enumerated()), id: \.0) { _, feature in
                    HStack(spacing: 7) {
                        Image(systemName: feature.0)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(feature.1)
                        Text(feature.2)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.82))
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(background)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(border, lineWidth: 1)
                )
        )
    }
}
