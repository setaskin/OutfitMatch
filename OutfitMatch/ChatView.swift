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

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
                    .padding(.bottom, 4)
            }

            HStack(alignment: .bottom, spacing: 8) {
                TextField("Describe what you're looking for…", text: $inputText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)

                Button {
                    send()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            }
            .padding()
        }
        .navigationTitle("Describe It")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToResults) {
            ChatResultsView(results: searchResults)
        }
    }

    private func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

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

private struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }

            Text(message.content)
                .padding(12)
                .background(message.role == .user ? Color.accentColor : Color(.secondarySystemBackground))
                .foregroundStyle(message.role == .user ? Color.white : Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }
}

#Preview {
    NavigationStack {
        ChatView()
    }
}
