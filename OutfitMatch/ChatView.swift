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
    /// Set when arriving from the home screen's voice card, so the listening
    /// screen opens immediately instead of making the user find the button.
    var startInVoiceMode = false

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
    @StateObject private var voice = VoiceConversation()
    @State private var showVoiceMode = false
    /// Set when a spoken turn triggered a search, so leaving voice mode lands
    /// on the results instead of dropping the user back into an empty chat.
    @State private var voiceProducedResults = false

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
                placeholder: "What are you after?",
                isSending: isSending,
                onSend: send,
                onVoiceMode: startVoiceMode
            )
        }
        .background(Color.scanBackground.ignoresSafeArea())
        .navigationTitle("Describe It")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.scanBackground, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .fullScreenCover(isPresented: $showVoiceMode) {
            VoiceModeView(conversation: voice) {
                endVoiceMode()
            }
        }
        .navigationDestination(isPresented: $navigateToResults) {
            ChatResultsView(messages: messages, results: searchResults)
        }
        .onChange(of: speechRecognizer.transcript) { _, newValue in
            inputText = newValue
        }
        .onAppear {
            if startInVoiceMode && !showVoiceMode && !voice.isActive {
                startVoiceMode()
            }
        }
        .onDisappear {
            speechRecognizer.stopRecording()
        }
    }

    private var displayedError: String? {
        errorMessage ?? speechRecognizer.errorMessage
    }

    private func startVoiceMode() {
        // The tap-to-dictate mic and voice mode both want the microphone;
        // only one can hold it.
        speechRecognizer.stopRecording()
        voiceProducedResults = false
        showVoiceMode = true
        voice.start(send: sendSpoken)
    }

    private func endVoiceMode() {
        voice.stop()
        showVoiceMode = false
        if voiceProducedResults {
            voiceProducedResults = false
            navigateToResults = true
        }
    }

    /// One spoken turn: append it, send it, and hand back the reply for
    /// speaking. Results are kept for when the user leaves voice mode rather
    /// than yanking the screen away mid-conversation.
    private func sendSpoken(_ text: String) async -> String? {
        messages.append(ChatMessage(role: .user, content: text))

        do {
            let turn = try await ChatService.send(history: messages)
            messages.append(ChatMessage(role: .assistant, content: turn.message))

            if turn.action == .search {
                searchResults = turn.matches ?? []
                voiceProducedResults = true
            }
            return turn.message
        } catch {
            let message = errorText(for: error)
            voice.errorMessage = message
            return message
        }
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
