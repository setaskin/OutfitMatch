//
//  ChatService.swift
//  OutfitMatch
//
//  Talks to the backend's /chat endpoint, which uses Claude to have a short
//  conversation figuring out what the user wants, then runs a real SerpApi
//  Google Shopping search once it has enough detail.

import Foundation

enum ChatServiceError: Error {
    case server(String)
    case badResponse
}

enum ChatTurnAction {
    case ask
    case search
}

struct ChatTurn {
    let action: ChatTurnAction
    let message: String
    let matches: [MatchResult]?
}

enum ChatService {
    static func send(history: [ChatMessage]) async throws -> ChatTurn {
        var request = URLRequest(url: BackendConfig.baseURL.appendingPathComponent("chat"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = [
            "messages": history.map { ["role": $0.role.rawValue, "content": $0.content] }
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ChatServiceError.badResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorPayload = try? JSONDecoder().decode(ChatErrorResponse.self, from: data)
            throw ChatServiceError.server(errorPayload?.error ?? "Chat failed (\(httpResponse.statusCode))")
        }

        let decoded = try JSONDecoder().decode(RemoteChatTurn.self, from: data)
        return ChatTurn(
            action: decoded.action == "search" ? .search : .ask,
            message: decoded.message,
            matches: decoded.matches?.map { $0.toMatchResult() }
        )
    }
}

private struct RemoteChatTurn: Decodable {
    let action: String
    let message: String
    let matches: [RemoteMatchDTO]?
}

private struct ChatErrorResponse: Decodable {
    let error: String?
}
