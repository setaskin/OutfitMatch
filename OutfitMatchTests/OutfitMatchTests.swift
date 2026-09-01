//
//  OutfitMatchTests.swift
//  OutfitMatchTests
//
//  Unit tests for the app's pure logic: DTO decoding, the free-use counter,
//  and the Vision-label → clothing-category mapping. Anything that needs
//  Vision, StoreKit, or the network is exercised manually (see README).
//

import Foundation
import Testing
@testable import OutfitMatch

// MARK: - RemoteMatchDTO → MatchResult

struct RemoteMatchDTOTests {
    @Test func exactMatchTypeMapsToExact() {
        let dto = RemoteMatchDTO(title: "Shoe", retailer: "eBay", price: 60, link: nil, thumbnail: nil, matchType: "exact")
        #expect(dto.toMatchResult().matchType == .exact)
    }

    @Test func anyOtherMatchTypeMapsToAlternative() {
        let dto = RemoteMatchDTO(title: "Shoe", retailer: "eBay", price: 40, link: nil, thumbnail: nil, matchType: "alternative")
        #expect(dto.toMatchResult().matchType == .alternative)

        let unknown = RemoteMatchDTO(title: "Shoe", retailer: "eBay", price: 40, link: nil, thumbnail: nil, matchType: "something-unexpected")
        #expect(unknown.toMatchResult().matchType == .alternative)
    }

    @Test func validLinkAndThumbnailParseToURLs() {
        let dto = RemoteMatchDTO(
            title: "Shoe", retailer: "eBay", price: 60,
            link: "https://example.com/product", thumbnail: "https://example.com/thumb.jpg",
            matchType: "exact"
        )
        let result = dto.toMatchResult()
        #expect(result.link == URL(string: "https://example.com/product"))
        #expect(result.thumbnailURL == URL(string: "https://example.com/thumb.jpg"))
    }

    @Test func nilLinkAndThumbnailStayNil() {
        let dto = RemoteMatchDTO(title: "Shoe", retailer: "eBay", price: 60, link: nil, thumbnail: nil, matchType: "exact")
        let result = dto.toMatchResult()
        #expect(result.link == nil)
        #expect(result.thumbnailURL == nil)
    }

    @Test func emptyLinkStringFailsToParseToNil() {
        let dto = RemoteMatchDTO(title: "Shoe", retailer: "eBay", price: 60, link: "", thumbnail: nil, matchType: "exact")
        #expect(dto.toMatchResult().link == nil)
    }

    @Test func decodesFromJSON() throws {
        let json = """
        {"title":"Nike Air","retailer":"Nike","price":89.99,"link":"https://nike.com/x","thumbnail":null,"matchType":"exact"}
        """.data(using: .utf8)!
        let dto = try JSONDecoder().decode(RemoteMatchDTO.self, from: json)
        #expect(dto.title == "Nike Air")
        #expect(dto.price == 89.99)
        #expect(dto.thumbnail == nil)
    }
}

// MARK: - StyleAdvisorAccess

private final class InMemoryFreeUseStore: FreeUseStore {
    private var value: Int?
    func readCount() -> Int? { value }
    func writeCount(_ count: Int) { value = count }
}

@MainActor
struct StyleAdvisorAccessTests {
    @Test func startsWithThreeFreeUses() {
        let access = StyleAdvisorAccess(store: InMemoryFreeUseStore())
        #expect(access.freeUsesRemaining == StyleAdvisorAccess.initialFreeUses)
        #expect(StyleAdvisorAccess.initialFreeUses == 3)
    }

    @Test func consumingUseDecrementsByOne() {
        let access = StyleAdvisorAccess(store: InMemoryFreeUseStore())
        access.consumeFreeUse()
        #expect(access.freeUsesRemaining == 2)
    }

    @Test func neverGoesBelowZero() {
        let access = StyleAdvisorAccess(store: InMemoryFreeUseStore())
        for _ in 0..<10 { access.consumeFreeUse() }
        #expect(access.freeUsesRemaining == 0)
    }

    @Test func persistsAcrossInstancesSharingTheSameStore() {
        let store = InMemoryFreeUseStore()
        let first = StyleAdvisorAccess(store: store)
        first.consumeFreeUse()
        first.consumeFreeUse()

        let second = StyleAdvisorAccess(store: store)
        #expect(second.freeUsesRemaining == 1)
    }
}

// MARK: - ClothingDetector.categorize

struct ClothingDetectorCategorizeTests {
    @Test func noLabelsReturnsEmpty() {
        #expect(ClothingDetector.categorize(labels: []) == [])
    }

    @Test func belowThresholdConfidenceIsIgnored() {
        let result = ClothingDetector.categorize(labels: [(identifier: "sneaker", confidence: 0.05)])
        #expect(result == [])
    }

    @Test func specificKeywordMapsToItsCategory() {
        let result = ClothingDetector.categorize(labels: [(identifier: "Sneaker", confidence: 0.9)])
        #expect(result == [.footwear])
    }

    @Test func multipleDistinctCategoriesAreAllReturnedWithoutDuplicates() {
        let result = ClothingDetector.categorize(labels: [
            (identifier: "sneaker", confidence: 0.9),
            (identifier: "denim jacket", confidence: 0.7),
            (identifier: "boot", confidence: 0.6), // same category as sneaker — should not duplicate
        ])
        #expect(result == [.footwear, .outerwear])
    }

    @Test func generalKeywordAloneMapsToGeneral() {
        let result = ClothingDetector.categorize(labels: [(identifier: "clothing", confidence: 0.5)])
        #expect(result == [.general])
    }

    @Test func specificCategoryTakesPriorityOverGeneral() {
        let result = ClothingDetector.categorize(labels: [
            (identifier: "clothing", confidence: 0.5),
            (identifier: "dress", confidence: 0.8),
        ])
        #expect(result == [.dress])
    }

    @Test func unrelatedLabelsReturnEmpty() {
        let result = ClothingDetector.categorize(labels: [(identifier: "mountain", confidence: 0.9)])
        #expect(result == [])
    }
}
