//
//  StyleAdvisorPaywallView.swift
//  OutfitMatch
//

import StoreKit
import SwiftUI

struct StyleAdvisorPaywallView: View {
    @ObservedObject var subscriptionManager: SubscriptionManager

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "wand.and.stars")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)

            Text("Style Advisor Premium")
                .font(.title2.weight(.bold))

            Text("You've used your free style checks. Subscribe for unlimited AI-powered styling advice based on your photos.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if let product = subscriptionManager.product {
                Text("\(product.displayPrice) / month")
                    .font(.title3.weight(.semibold))
            }

            Button {
                Task { await subscriptionManager.purchase() }
            } label: {
                if subscriptionManager.isPurchasing {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Subscribe")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(subscriptionManager.isPurchasing || subscriptionManager.product == nil)
            .padding(.horizontal)

            Button("Restore Purchases") {
                Task { await subscriptionManager.restorePurchases() }
            }
            .font(.footnote)

            if let errorMessage = subscriptionManager.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Style Advisor")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        StyleAdvisorPaywallView(subscriptionManager: SubscriptionManager())
    }
}
