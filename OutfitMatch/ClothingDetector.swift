//
//  ClothingDetector.swift
//  OutfitMatch
//
//  On-device check for "what clothing is in this photo" using Vision's
//  built-in image classifier. No network call, no API key — this runs
//  locally, so it's real (not mocked), unlike the product search results.
//
//  VNClassifyImageRequest is a multi-label classifier: it doesn't localize
//  individual items, but a photo with several clothing items (e.g. a shirt,
//  pants, and shoes) typically surfaces a separate tag for each, which is
//  what lets us report multiple detected items from one photo.

import Vision
import UIKit

enum ClothingCategory {
    case footwear
    case outerwear
    case dress
    case top
    case bottom
    case general

    var displayName: String {
        switch self {
        case .footwear: return "Footwear"
        case .outerwear: return "Outerwear"
        case .dress: return "Dress"
        case .top: return "Top"
        case .bottom: return "Bottom"
        case .general: return "Clothing"
        }
    }
}

enum ClothingDetector {
    private static let specificCategoryKeywords: [(ClothingCategory, Set<String>)] = [
        (.footwear, ["footwear", "shoe", "sneaker", "boot", "sandal", "heel"]),
        (.outerwear, ["jacket", "coat", "blazer"]),
        (.dress, ["dress", "gown"]),
        (.top, ["shirt", "t-shirt", "blouse", "top", "sweater", "hoodie", "cardigan", "necktie", "tie"]),
        (.bottom, ["trousers", "pants", "jean", "skirt", "shorts"]),
    ]

    private static let generalKeywords: Set<String> = [
        "clothing", "attire", "apparel", "garment", "fashion", "suit",
        "swimwear", "handbag", "purse", "belt", "glove", "sock",
        "hat", "cap", "beanie", "scarf",
    ]

    /// Returns every distinct clothing category detected in the photo, most
    /// confident first. Empty means no clothing was found.
    static func analyzeAll(_ image: UIImage) async -> [ClothingCategory] {
        #if targetEnvironment(simulator)
        // VNClassifyImageRequest's CoreML backend doesn't run in the iOS
        // Simulator (it fails with "Failed to create espresso context" on
        // every call, regardless of image content). It works normally on a
        // real device, so skip the gate here rather than block testing.
        return [.general]
        #else
        guard let cgImage = image.cgImage else { return [] }
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

                    var specific: [ClothingCategory] = []
                    var foundGeneral = false

                    for observation in observations {
                        guard observation.confidence > 0.08 else { continue }
                        let identifier = observation.identifier.lowercased()

                        for (category, keywords) in specificCategoryKeywords
                        where !specific.contains(category) && keywords.contains(where: { identifier.contains($0) }) {
                            specific.append(category)
                        }

                        if generalKeywords.contains(where: { identifier.contains($0) }) {
                            foundGeneral = true
                        }
                    }

                    if !specific.isEmpty {
                        continuation.resume(returning: specific)
                    } else if foundGeneral {
                        continuation.resume(returning: [.general])
                    } else {
                        continuation.resume(returning: [])
                    }
                } catch {
                    continuation.resume(returning: [])
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
