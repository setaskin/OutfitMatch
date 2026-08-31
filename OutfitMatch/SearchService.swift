//
//  SearchService.swift
//  OutfitMatch
//
//  Talks to the local backend proxy (see /backend), which holds the real
//  SerpApi key and does the actual Google Lens search. The app never calls
//  SerpApi directly.

import UIKit

enum SearchServiceError: Error {
    case invalidImage
    case server(String)
    case badResponse
}

enum SearchService {
    // Simulator only: this is the Mac's own loopback address, reachable
    // because the Simulator shares the host's network stack. Testing on a
    // real device needs the Mac's LAN IP instead (e.g. http://192.168.x.x:5050)
    // since "localhost" on a physical iPhone means the iPhone itself.
    private static let baseURL = URL(string: "http://127.0.0.1:5050")!

    static func search(image: UIImage, category: ClothingCategory) async throws -> [MatchResult] {
        guard let jpegData = image.jpegData(compressionQuality: 0.8) else {
            throw SearchServiceError.invalidImage
        }

        var request = URLRequest(url: baseURL.appendingPathComponent("search"))
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = multipartBody(boundary: boundary, category: category.rawValue, imageData: jpegData)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SearchServiceError.badResponse
        }

        let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)

        guard httpResponse.statusCode == 200 else {
            throw SearchServiceError.server(decoded.error ?? "Search failed (\(httpResponse.statusCode))")
        }

        return (decoded.matches ?? []).map { $0.toMatchResult() }
    }

    private static func multipartBody(boundary: String, category: String, imageData: Data) -> Data {
        var body = Data()

        func appendField(name: String, value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        appendField(name: "category", value: category)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"photo.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return body
    }
}

private struct SearchResponse: Decodable {
    let matches: [RemoteMatch]?
    let error: String?
}

private struct RemoteMatch: Decodable {
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

private extension ClothingCategory {
    var rawValue: String {
        switch self {
        case .footwear: return "footwear"
        case .outerwear: return "outerwear"
        case .dress: return "dress"
        case .top: return "top"
        case .bottom: return "bottom"
        case .general: return "general"
        }
    }
}
