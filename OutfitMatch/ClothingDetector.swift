//
//  ClothingDetector.swift
//  OutfitMatch
//
//  On-device check for "does this photo contain clothing" using Vision's
//  built-in image classifier. No network call, no API key — this runs
//  locally, so it's real (not mocked), unlike the product search results.

import Vision
import UIKit

enum ClothingDetector {
    private static let clothingKeywords: Set<String> = [
        "clothing", "attire", "apparel", "garment", "fashion",
        "shirt", "t-shirt", "blouse", "top", "dress", "gown",
        "jacket", "coat", "blazer", "trousers", "pants", "jean",
        "skirt", "suit", "sweater", "hoodie", "cardigan", "shorts",
        "footwear", "shoe", "sneaker", "boot", "sandal", "heel",
        "hat", "cap", "beanie", "scarf", "necktie", "tie",
        "handbag", "purse", "belt", "glove", "sock", "swimwear"
    ]

    static func containsClothing(in image: UIImage) async -> Bool {
        #if targetEnvironment(simulator)
        // VNClassifyImageRequest's CoreML backend doesn't run in the iOS
        // Simulator (it fails with "Failed to create espresso context" on
        // every call, regardless of image content). It works normally on a
        // real device, so skip the gate here rather than block testing.
        return true
        #else
        guard let cgImage = image.cgImage else { return false }
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

                    let found = observations.contains { observation in
                        let identifier = observation.identifier.lowercased()
                        return observation.confidence > 0.08
                            && clothingKeywords.contains { identifier.contains($0) }
                    }
                    continuation.resume(returning: found)
                } catch {
                    continuation.resume(returning: false)
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
