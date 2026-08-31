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
    let link: URL?
    let thumbnailURL: URL?
}
