//
//  StyleAdvisorAccess.swift
//  OutfitMatch
//
//  Tracks the free-trial usage count for Style Advisor (a few free tries,
//  then it requires the subscription in SubscriptionManager). Persisted in
//  the Keychain rather than UserDefaults — Keychain items survive an
//  uninstall/reinstall (tied to the device, not the app's data container),
//  so the free trial can't be reset just by deleting and reinstalling the
//  app. Still resettable via a full device restore, but that's a much
//  higher bar — good enough for a small-scale launch; a real launch would
//  want this server-side (tied to an account) so it can't be bypassed at
//  all.

import Combine
import Foundation
import Security

protocol FreeUseStore {
    func readCount() -> Int?
    func writeCount(_ count: Int)
}

struct KeychainFreeUseStore: FreeUseStore {
    private let service = "com.selengt.OutfitMatch.styleAdvisorFreeUses"
    private let account = "freeUsesRemaining"

    func readCount() -> Int? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8),
              let value = Int(string) else { return nil }
        return value
    }

    func writeCount(_ count: Int) {
        let data = Data(String(count).utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        if readCount() != nil {
            SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        } else {
            var newItem = query
            newItem[kSecValueData as String] = data
            newItem[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(newItem as CFDictionary, nil)
        }
    }
}

@MainActor
final class StyleAdvisorAccess: ObservableObject {
    static let initialFreeUses = 3

    @Published private(set) var freeUsesRemaining: Int
    private let store: FreeUseStore

    init(store: FreeUseStore = KeychainFreeUseStore()) {
        self.store = store
        if let existing = store.readCount() {
            freeUsesRemaining = existing
        } else {
            freeUsesRemaining = Self.initialFreeUses
            store.writeCount(Self.initialFreeUses)
        }
    }

    func consumeFreeUse() {
        guard freeUsesRemaining > 0 else { return }
        freeUsesRemaining -= 1
        store.writeCount(freeUsesRemaining)
    }
}
