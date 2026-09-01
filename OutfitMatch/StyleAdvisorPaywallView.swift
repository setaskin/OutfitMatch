//
//  StyleAdvisorPaywallView.swift
//  OutfitMatch
//

import StoreKit
import SwiftUI

struct StyleAdvisorPaywallView: View {
    @ObservedObject var subscriptionManager: SubscriptionManager

    var body: some View {
        ZStack {
            Color.scanBackground.ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                Image(systemName: "wand.and.stars")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.scanMint)
                    .accessibilityHidden(true)

                Text("Style Advisor Premium")
                    .font(ScanFont.display(21, weight: .bold))
                    .foregroundStyle(Color.scanInk)

                Text("You've used your free style checks. Subscribe for unlimited AI-powered styling advice based on your photos.")
                    .font(.subheadline)
                    .foregroundStyle(Color.scanInkDim)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if let product = subscriptionManager.product {
                    Text("\(product.displayPrice) / month")
                        .font(ScanFont.display(17, weight: .semibold))
                        .foregroundStyle(Color.scanInk)
                }

                Button {
                    Task { await subscriptionManager.purchase() }
                } label: {
                    Group {
                        if subscriptionManager.isPurchasing {
                            ProgressView()
                                .tint(Color.scanBackground)
                        } else {
                            Text("Subscribe")
                                .font(ScanFont.display(15, weight: .bold))
                        }
                    }
                    .foregroundStyle(Color.scanBackground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color.scanMint)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(subscriptionManager.isPurchasing || subscriptionManager.product == nil)
                .padding(.horizontal)

                if let product = subscriptionManager.product {
                    Text("\(product.displayPrice) per month, billed to your Apple ID. Renews automatically unless canceled at least 24 hours before the end of the current period. Manage or cancel anytime in Settings.")
                        .font(.caption2)
                        .foregroundStyle(Color.scanInkDim)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Button("Restore Purchases") {
                    Task { await subscriptionManager.restorePurchases() }
                }
                .font(.footnote)
                .foregroundStyle(Color.scanInkDim)

                HStack(spacing: 16) {
                    Link("Terms of Use", destination: URL(string: "https://github.com/setaskin/OutfitMatch/blob/main/TERMS.md")!)
                    Link("Privacy Policy", destination: URL(string: "https://github.com/setaskin/OutfitMatch/blob/main/PRIVACY.md")!)
                }
                .font(.caption2)
                .foregroundStyle(Color.scanInkDim)

                if let errorMessage = subscriptionManager.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(Color.scanAmber)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle("Style Advisor")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.scanBackground, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

#Preview {
    NavigationStack {
        StyleAdvisorPaywallView(subscriptionManager: SubscriptionManager())
    }
}
