//
//  RefinementSession.swift
//  OutfitMatch
//
//  Refining results is the same job whichever way the search started — a
//  photo, a description, or a styling question — so the loop lives once here
//  and each results screen just renders it.
//
//  Refinements go through the chat endpoint regardless of the original path,
//  because "in black" or "something cheaper" is textual intent, and Claude
//  needs the earlier context to act on it. That context is seeded as an
//  opening assistant message describing what the original search turned up.

import Combine
import Foundation

@MainActor
final class RefinementSession: ObservableObject {
    /// The refinement exchange shown on screen.
    @Published private(set) var transcript: [ChatMessage] = []
    /// Results from the latest refinement. `nil` until the user refines, so
    /// screens can fall back to whatever the original search produced.
    @Published private(set) var refinedResults: [MatchResult]?
    @Published private(set) var isSending = false
    @Published var errorMessage: String?

    /// Full history sent to Claude, including the seed — without it a
    /// refinement like "in black" has nothing to attach to.
    private var history: [ChatMessage] = []

    var hasActivity: Bool { !transcript.isEmpty || isSending }

    /// Describe what the original search found. Only the first call counts,
    /// so this is safe to call from `onAppear` or a repeated `task`.
    func seed(_ context: String) {
        guard history.isEmpty else { return }
        history = [ChatMessage(role: .assistant, content: context)]
    }

    /// Continue a conversation that already exists, as the chat path does —
    /// everything the user already specified stays in scope.
    func seedHistory(_ messages: [ChatMessage]) {
        guard history.isEmpty else { return }
        history = messages
    }

    func refine(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }

        errorMessage = nil
        let userMessage = ChatMessage(role: .user, content: trimmed)
        history.append(userMessage)
        transcript.append(userMessage)

        Task {
            isSending = true
            defer { isSending = false }

            do {
                let turn = try await ChatService.send(history: history)
                let reply = ChatMessage(role: .assistant, content: turn.message)
                history.append(reply)
                transcript.append(reply)

                // A refinement can come back as a clarifying question rather
                // than a search; leave the current results up until there are
                // new ones to replace them with.
                if turn.action == .search {
                    refinedResults = turn.matches ?? []
                }
            } catch {
                errorMessage = Self.message(for: error)
            }
        }
    }

    private static func message(for error: Error) -> String {
        switch error {
        case ChatServiceError.server(let message):
            return message
        default:
            return "Couldn't reach the server. Check your connection and try again."
        }
    }
}
