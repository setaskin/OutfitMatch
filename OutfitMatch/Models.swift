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
    /// Stand-in for a real visual search call. Returns canned results keyed
    /// off the detected clothing category, after a short delay, so the UI
    /// flow can be tested before any real search backend exists.
    static func find(for category: ClothingCategory) async -> [MatchResult] {
        try? await Task.sleep(nanoseconds: 1_200_000_000)

        switch category {
        case .footwear:
            return [
                MatchResult(title: "Air Zoom Running Shoe", retailer: "Nike", price: 130.00, matchType: .exact, systemImageName: "shoeprints.fill"),
                MatchResult(title: "Cloud Runner Sneaker", retailer: "DSW", price: 79.99, matchType: .alternative, systemImageName: "shoeprints.fill"),
                MatchResult(title: "Classic Trainer", retailer: "Target", price: 44.99, matchType: .alternative, systemImageName: "shoeprints.fill"),
                MatchResult(title: "Everyday Runner", retailer: "Old Navy", price: 39.99, matchType: .alternative, systemImageName: "shoeprints.fill"),
            ]
        case .outerwear:
            return [
                MatchResult(title: "Wool-Blend Trench Coat", retailer: "Nordstrom", price: 228.00, matchType: .exact, systemImageName: "person.crop.rectangle"),
                MatchResult(title: "Classic Trench Coat", retailer: "Zara", price: 129.00, matchType: .alternative, systemImageName: "tshirt.fill"),
                MatchResult(title: "Belted Trench Coat", retailer: "H&M", price: 89.99, matchType: .alternative, systemImageName: "tshirt.fill"),
                MatchResult(title: "Cotton Trench Coat", retailer: "Uniqlo", price: 99.00, matchType: .alternative, systemImageName: "tshirt.fill"),
            ]
        case .dress:
            return [
                MatchResult(title: "Silk Wrap Sundress", retailer: "Reformation", price: 218.00, matchType: .exact, systemImageName: "person.crop.rectangle"),
                MatchResult(title: "Floral Midi Dress", retailer: "Zara", price: 69.90, matchType: .alternative, systemImageName: "tshirt.fill"),
                MatchResult(title: "Cotton Sundress", retailer: "H&M", price: 34.99, matchType: .alternative, systemImageName: "tshirt.fill"),
                MatchResult(title: "Everyday Slip Dress", retailer: "Old Navy", price: 29.99, matchType: .alternative, systemImageName: "tshirt.fill"),
            ]
        case .top:
            return [
                MatchResult(title: "Premium Cotton Tee", retailer: "Nordstrom", price: 58.00, matchType: .exact, systemImageName: "tshirt.fill"),
                MatchResult(title: "Essential Crew Tee", retailer: "Uniqlo", price: 14.90, matchType: .alternative, systemImageName: "tshirt.fill"),
                MatchResult(title: "Classic Fit Tee", retailer: "H&M", price: 9.99, matchType: .alternative, systemImageName: "tshirt.fill"),
                MatchResult(title: "Everyday Tee", retailer: "Target", price: 8.00, matchType: .alternative, systemImageName: "tshirt.fill"),
            ]
        case .bottom:
            return [
                MatchResult(title: "Slim Straight Jean", retailer: "Nordstrom", price: 148.00, matchType: .exact, systemImageName: "person.crop.rectangle"),
                MatchResult(title: "Classic Straight Jean", retailer: "Zara", price: 59.90, matchType: .alternative, systemImageName: "tshirt.fill"),
                MatchResult(title: "Slim Fit Jean", retailer: "Uniqlo", price: 39.90, matchType: .alternative, systemImageName: "tshirt.fill"),
                MatchResult(title: "Everyday Jean", retailer: "Old Navy", price: 32.99, matchType: .alternative, systemImageName: "tshirt.fill"),
            ]
        case .general:
            return [
                MatchResult(title: "Wool-Blend Trench Coat", retailer: "Nordstrom", price: 228.00, matchType: .exact, systemImageName: "person.crop.rectangle"),
                MatchResult(title: "Classic Trench Coat", retailer: "Zara", price: 129.00, matchType: .alternative, systemImageName: "tshirt.fill"),
                MatchResult(title: "Belted Trench Coat", retailer: "H&M", price: 89.99, matchType: .alternative, systemImageName: "tshirt.fill"),
                MatchResult(title: "Cotton Trench Coat", retailer: "Uniqlo", price: 99.00, matchType: .alternative, systemImageName: "tshirt.fill"),
            ]
        }
    }
}
