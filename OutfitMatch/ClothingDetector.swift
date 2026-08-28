//
//  ClothingDetector.swift
//  OutfitMatch
//
//  On-device check for "does this photo contain clothing" using Vision's
//  built-in image classifier. No network call, no API key — this runs
//  locally, so it's real (not mocked), unlike the product search results.

import Vision
import UIKit

enum ClothingCategory {
    case footwear
    case outerwear
    case dress
    case top
    case bottom
    case general
}

enum ClothingDetector {
    // Ordered so more specific categories are checked before the catch-all
    // "general" bucket. The first category whose keywords match the
    // highest-confidence observation wins.
    private static let categoryKeywords: [(ClothingCategory, Set<String>)] = [
        (.footwear, ["footwear", "shoe", "sneaker", "boot", "sandal", "heel"]),
        (.outerwear, ["jacket", "coat", "blazer"]),
        (.dress, ["dress", "gown"]),
        (.top, ["shirt", "t-shirt", "blouse", "top", "sweater", "hoodie", "cardigan", "necktie", "tie"]),
        (.bottom, ["trousers", "pants", "jean", "skirt", "shorts"]),
        (.general, ["clothing", "attire", "apparel", "garment", "fashion", "suit", "swimwear", "handbag", "purse", "belt", "glove", "sock", "hat", "cap", "beanie", "scarf"]),
    ]

    /// Returns the detected clothing category, or nil if no clothing was found.
    static func analyze(_ image: UIImage) async -> ClothingCategory? {
        #if targetEnvironment(simulator)
        // VNClassifyImageRequest's CoreML backend doesn't run in the iOS
        // Simulator (it fails with "Failed to create espresso context" on
        // every call, regardless of image content). It works normally on a
        // real device, so skip the gate here rather than block testing.
        return .general
        #else
        guard let cgImage = image.cgImage else { return nil }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNClassifyImageRequest()
                let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
                do {
                    try handler.perform([request])
                    let observations = (request.results ?? [])
                        .sorted { $0.confidence > $1.confidence }
                        .prefix(20)

                    for observation in observations {
                        guard observation.confidence > 0.08 else { continue }
                        let identifier = observation.identifier.lowercased()
                        if let match = categoryKeywords.first(where: { _, keywords in
                            keywords.contains { identifier.contains($0) }
                        }) {
                            continuation.resume(returning: match.0)
                            return
                        }
                    }
                    continuation.resume(returning: nil)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
        #endif
    }
}

private extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
