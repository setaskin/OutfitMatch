//
//  Models.swift
//  OutfitMatch
//

import Foundation

enum MatchType {
    case exact
    case alternative
}

struct MatchResult: Identifiable {
    let id = UUID()
    let title: String
    let retailer: String
    let price: Double
    let matchType: MatchType
    let systemImageName: String
}

enum MockSearch {
    /// Stand-in for a real visual search call. Always returns the same
    /// canned results after a short delay so the UI flow can be tested
    /// before any real search backend exists.
    static func find(for image: Data?) async -> [MatchResult] {
        try? await Task.sleep(nanoseconds: 1_200_000_000)

        return [
            MatchResult(title: "Wool-Blend Trench Coat", retailer: "Nordstrom", price: 228.00, matchType: .exact, systemImageName: "person.crop.rectangle"),
            MatchResult(title: "Classic Trench Coat", retailer: "Zara", price: 129.00, matchType: .alternative, systemImageName: "tshirt.fill"),
            MatchResult(title: "Belted Trench Coat", retailer: "H&M", price: 89.99, matchType: .alternative, systemImageName: "tshirt.fill"),
            MatchResult(title: "Cotton Trench Coat", retailer: "Uniqlo", price: 99.00, matchType: .alternative, systemImageName: "tshirt.fill"),
        ]
    }
}
