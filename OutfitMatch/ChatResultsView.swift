//
//  ChatResultsView.swift
//  OutfitMatch
//
//  Results for the chat flow, with the conversation still live underneath.
//  Getting results isn't the end of the task — the first search is rarely
//  right ("no, black", "something cheaper"), so the chat stays available
//  here and refinements replace the results in place rather than forcing a
//  trip back to start a new conversation.

import SwiftUI

struct ChatResultsView: View {
    /// Full history, sent to Claude so a refinement like "make it black"
    /// still has the context of everything asked so far.
    @State private var messages: [ChatMessage]
    /// Just what this screen shows: the reply that produced these results,
    /// plus any refinement exchange since.
    @State private var transcript: [ChatMessage]
    @State private var results: [MatchResult]
    @State private var inputText = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    @StateObject private var speechRecognizer = SpeechRecognizer()

    init(messages: [ChatMessage], results: [MatchResult]) {
        _messages = State(initialValue: messages)
        _results = State(initialValue: results)
        _transcript = State(initialValue: messages.last(where: { $0.role == .assistant }).map { [$0] } ?? [])
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(transcript) { message in
                            ChatBubble(message: message)
                                .id(message.id)
                        }

                        if isSending {
                            HStack(spacing: 10) {
                                ProgressView().tint(Color.scanMint)
                                Text("Updating results…")
                                    .font(.caption)
                                    .foregroundStyle(Color.scanInkDim)
                                Spacer()
                            }
                        }

                        if results.isEmpty {
                            EmptyMatchesView(subtitle: "Try describing it a different way.")
                        } else {
                            MatchesListView(results: results)
                                .id(resultsID)
                        }
                    }
                    .padding()
                }
                .onChange(of: transcript.count) { _, _ in
                    if let last = transcript.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .top) }
                    }
                }
            }

            if let displayedError {
                Text(displayedError)
                    .font(.caption)
                    .foregroundStyle(Color.scanAmber)
                    .padding(.horizontal)
                    .padding(.bottom, 4)
            }

            ChatInputBar(
                text: $inputText,
                speechRecognizer: speechRecognizer,
                placeholder: "Refine — colour, budget, style…",
                isSending: isSending,
                onSend: refine
            )
        }
        .background(Color.scanBackground.ignoresSafeArea())
        .navigationTitle("Matches")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.scanBackground, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onChange(of: speechRecognizer.transcript) { _, newValue in
            inputText = newValue
        }
        .onDisappear {
            speechRecognizer.stopRecording()
        }
    }

    /// Changes when results are replaced, so the grid re-renders from the top
    /// instead of keeping the previous scroll position over new content.
    private var resultsID: String {
        results.first.map { "\($0.title)-\(results.count)" } ?? "empty"
    }

    private var displayedError: String? {
        errorMessage ?? speechRecognizer.errorMessage
    }

    private func refine() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        speechRecognizer.stopRecording()
        inputText = ""
        errorMessage = nil

        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)
        transcript.append(userMessage)

        Task {
            isSending = true
            do {
                let turn = try await ChatService.send(history: messages)
                isSending = false

                let reply = ChatMessage(role: .assistant, content: turn.message)
                messages.append(reply)
                transcript.append(reply)

                // A refinement can come back as another question rather than a
                // search; keep the existing results on screen until there are
                // new ones to replace them with.
                if turn.action == .search {
                    results = turn.matches ?? []
                }
            } catch {
                isSending = false
                errorMessage = errorText(for: error)
            }
        }
    }

    private func errorText(for error: Error) -> String {
        switch error {
        case ChatServiceError.server(let message):
            return message
        default:
            return "Couldn't reach the chat server. Check your connection and try again."
        }
    }
}

#Preview {
    NavigationStack {
        ChatResultsView(
            messages: [ChatMessage(role: .assistant, content: "Here are some black fur dusters under $120.")],
            results: []
        )
    }
}
