//
//  StyleAdviceService.swift
//  OutfitMatch
//
//  Talks to the backend's /style-advice endpoint: Claude looks at the
//  uploaded photo plus the user's question and returns styling advice with
//  specific, shoppable recommendations, each already backed by a real
//  SerpApi Google Shopping search.

import UIKit

enum StyleAdviceServiceError: Error {
    case invalidImage
    case server(String)
    case badResponse
}

enum StyleAdviceService {
    static func getAdvice(image: UIImage, question: String) async throws -> StyleAdvice {
        guard let jpegData = image.jpegData(compressionQuality: 0.8) else {
            throw StyleAdviceServiceError.invalidImage
        }

        var request = URLRequest(url: BackendConfig.baseURL.appendingPathComponent("style-advice"))
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = multipartBody(boundary: boundary, question: question, imageData: jpegData)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw StyleAdviceServiceError.badResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorPayload = try? JSONDecoder().decode(StyleAdviceErrorResponse.self, from: data)
            throw StyleAdviceServiceError.server(errorPayload?.error ?? "Request failed (\(httpResponse.statusCode))")
        }

        let decoded = try JSONDecoder().decode(RemoteStyleAdvice.self, from: data)
        return StyleAdvice(
            advice: decoded.advice,
            recommendations: decoded.recommendations.map { remote in
                StyleRecommendation(label: remote.label, matches: remote.matches.map { $0.toMatchResult() })
            }
        )
    }

    private static func multipartBody(boundary: String, question: String, imageData: Data) -> Data {
        var body = Data()

        func appendField(name: String, value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        appendField(name: "question", value: question)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"photo.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return body
    }
}

private struct RemoteStyleAdvice: Decodable {
    let advice: String
    let recommendations: [RemoteStyleRecommendation]
}

private struct RemoteStyleRecommendation: Decodable {
    let label: String
    let matches: [RemoteMatchDTO]
}

private struct StyleAdviceErrorResponse: Decodable {
    let error: String?
}
