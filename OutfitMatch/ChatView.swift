//
//  ChatView.swift
//  OutfitMatch
//
//  Lets the user describe what they're looking for in plain text instead of
//  a photo. Claude (via the backend's /chat endpoint) asks a couple of
//  clarifying questions, then triggers a real SerpApi Google Shopping
//  search once it has enough detail.

import SwiftUI

struct ChatView: View {
    @State private var messages: [ChatMessage] = [
        ChatMessage(
            role: .assistant,
            content: "Hi! Tell me what you're looking for — an item, color, style, or budget, whatever you've got."
        )
    ]
    @State private var inputText = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var searchResults: [MatchResult] = []
    @State private var navigateToResults = false
    @StateObject private var speechRecognizer = SpeechRecognizer()

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { message in
                            ChatBubble(message: message)
                                .id(message.id)
                        }
                        if isSending {
                            HStack {
                                ProgressView()
                                    .tint(Color.scanMint)
                                Spacer()
                            }
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
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
                placeholder: "Describe what you're looking for…",
                isSending: isSending,
                onSend: send
            )
        }
        .background(Color.scanBackground.ignoresSafeArea())
        .navigationTitle("Describe It")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.scanBackground, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationDestination(isPresented: $navigateToResults) {
            ChatResultsView(messages: messages, results: searchResults)
        }
        .onChange(of: speechRecognizer.transcript) { _, newValue in
            inputText = newValue
        }
        .onDisappear {
            speechRecognizer.stopRecording()
        }
    }

    private var displayedError: String? {
        errorMessage ?? speechRecognizer.errorMessage
    }

    private func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        speechRecognizer.stopRecording()
        inputText = ""
        errorMessage = nil
        messages.append(ChatMessage(role: .user, content: text))

        Task {
            isSending = true
            do {
                let turn = try await ChatService.send(history: messages)
                isSending = false
                messages.append(ChatMessage(role: .assistant, content: turn.message))

                if turn.action == .search {
                    searchResults = turn.matches ?? []
                    navigateToResults = true
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
            return "Couldn't reach the chat server. Make sure the backend is running."
        }
    }
}

#Preview {
    NavigationStack {
        ChatView()
    }
}
