//
//  SubscriptionManager.swift
//  OutfitMatch
//
//  Style Advisor is a paid feature (after a few free tries) — this wraps
//  StoreKit 2 for the single "Style Advisor Premium" auto-renewable
//  subscription. Test locally via Xcode's StoreKit Configuration file
//  (Configuration.storekit, wired into the shared scheme) — that only
//  works when the app is launched from Xcode itself (Cmd+R), not when
//  installed via the command line.

import Combine
import Foundation
import StoreKit

@MainActor
final class SubscriptionManager: ObservableObject {
    static let styleAdvisorProductID = "com.selengt.OutfitMatch.styleadvisor.monthly"

    @Published private(set) var isSubscribed = false
    @Published private(set) var product: Product?
    @Published var errorMessage: String?
    @Published var isPurchasing = false

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            await self?.observeTransactionUpdates()
        }
        Task {
            await loadProduct()
            await refreshEntitlement()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProduct() async {
        do {
            let products = try await Product.products(for: [Self.styleAdvisorProductID])
            product = products.first
        } catch {
            errorMessage = "Couldn't load subscription info."
        }
    }

    func refreshEntitlement() async {
        var subscribed = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.productID == Self.styleAdvisorProductID {
                subscribed = true
            }
        }
        isSubscribed = subscribed
    }

    func purchase() async {
        guard let product else {
            errorMessage = "Subscription isn't available right now."
            return
        }

        errorMessage = nil
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refreshEntitlement()
                } else {
                    errorMessage = "Purchase couldn't be verified."
                }
            case .userCancelled:
                break
            case .pending:
                errorMessage = "Purchase is waiting for approval."
            @unknown default:
                break
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
        }
    }

    func restorePurchases() async {
        errorMessage = nil
        do {
            try await AppStore.sync()
            await refreshEntitlement()
        } catch {
            errorMessage = "Couldn't restore purchases: \(error.localizedDescription)"
        }
    }

    private func observeTransactionUpdates() async {
        for await result in Transaction.updates {
            if case .verified(let transaction) = result {
                await transaction.finish()
                await refreshEntitlement()
            }
        }
    }
}
