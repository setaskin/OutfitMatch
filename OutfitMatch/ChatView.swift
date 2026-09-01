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

            HStack(alignment: .bottom, spacing: 8) {
                Button {
                    speechRecognizer.toggleRecording()
                } label: {
                    Image(systemName: speechRecognizer.isRecording ? "mic.fill" : "mic")
                        .font(.system(size: 20))
                        .foregroundStyle(speechRecognizer.isRecording ? Color.scanAmber : Color.scanMint)
                        .frame(width: 34, height: 34)
                }
                .disabled(isSending)

                TextField("", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .foregroundStyle(Color.scanInk)
                    .tint(Color.scanMint)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .placeholder(when: inputText.isEmpty) {
                        Text("Describe what you're looking for…")
                            .foregroundStyle(Color.scanInkDim)
                    }
                    .lineLimit(1...4)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color.scanSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Button {
                    send()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(
                            inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? Color.scanInkDim
                                : Color.scanMint
                        )
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            }
            .padding()
        }
        .background(Color.scanBackground.ignoresSafeArea())
        .navigationTitle("Describe It")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.scanBackground, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationDestination(isPresented: $navigateToResults) {
            ChatResultsView(results: searchResults)
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

private struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }

            Text(message.content)
                .padding(12)
                .background(message.role == .user ? Color.scanMint : Color.scanSurface)
                .foregroundStyle(message.role == .user ? Color.scanBackground : Color.scanInk)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }
}

private extension View {
    @ViewBuilder
    func placeholder(when shouldShow: Bool, @ViewBuilder placeholder: () -> some View) -> some View {
        ZStack(alignment: .leading) {
            if shouldShow { placeholder().allowsHitTesting(false) }
            self
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        ChatView()
    }
}
