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
    static func search(image: UIImage, category: ClothingCategory) async throws -> [MatchResult] {
        guard let jpegData = image.jpegData(compressionQuality: 0.8) else {
            throw SearchServiceError.invalidImage
        }

        var request = URLRequest(url: BackendConfig.baseURL.appendingPathComponent("search"))
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
    let matches: [RemoteMatchDTO]?
    let error: String?
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
