//
//  Models.swift
//  OutfitMatch
//

import Foundation

enum MatchType: Equatable {
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

/// Shared wire format for a match, as returned by both /search and /chat.
struct RemoteMatchDTO: Decodable {
    let title: String
    let retailer: String
    let price: Double
    let link: String?
    let thumbnail: String?
    let matchType: String

    func toMatchResult() -> MatchResult {
        MatchResult(
            title: title,
            retailer: retailer,
            price: price,
            matchType: matchType == "exact" ? .exact : .alternative,
            link: link.flatMap(URL.init),
            thumbnailURL: thumbnail.flatMap(URL.init)
        )
    }
}

enum ChatRole: String {
    case user
    case assistant
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: ChatRole
    let content: String
}

struct StyleRecommendation: Identifiable {
    let id = UUID()
    let label: String
    let matches: [MatchResult]
}

struct StyleAdvice {
    let advice: String
    let recommendations: [StyleRecommendation]
}
