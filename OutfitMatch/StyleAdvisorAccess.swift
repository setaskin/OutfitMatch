//
//  StyleAdvisorAccess.swift
//  OutfitMatch
//
//  Tracks the free-trial usage count for Style Advisor (a few free tries,
//  then it requires the subscription in SubscriptionManager). Persisted
//  locally via UserDefaults — good enough for a single-device trial; a
//  real launch would want this server-side so it can't be reset by
//  reinstalling the app.

import Combine
import Foundation

@MainActor
final class StyleAdvisorAccess: ObservableObject {
    static let initialFreeUses = 3
    private static let freeUsesKey = "styleAdvisorFreeUsesRemaining"

    @Published private(set) var freeUsesRemaining: Int

    init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Self.freeUsesKey) == nil {
            defaults.set(Self.initialFreeUses, forKey: Self.freeUsesKey)
        }
        freeUsesRemaining = defaults.integer(forKey: Self.freeUsesKey)
    }

    func consumeFreeUse() {
        guard freeUsesRemaining > 0 else { return }
        freeUsesRemaining -= 1
        UserDefaults.standard.set(freeUsesRemaining, forKey: Self.freeUsesKey)
    }
}
