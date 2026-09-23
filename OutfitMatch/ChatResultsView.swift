//
//  ChatResultsView.swift
//  OutfitMatch
//
//  Results for the chat flow, with the conversation still live underneath.
//  Getting results isn't the end of the task — the first search is rarely
//  right ("no, black", "something cheaper") — so refinement continues here
//  via the shared RefinementSession, the same as the photo and style paths.

import SwiftUI

struct ChatResultsView: View {
    let messages: [ChatMessage]
    let results: [MatchResult]

    @StateObject private var refinement = RefinementSession()
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @State private var refinementText = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let opening = messages.last(where: { $0.role == .assistant }) {
                        ChatBubble(message: opening)
                    }

                    let shown = refinement.refinedResults ?? results
                    if shown.isEmpty {
                        EmptyMatchesView(subtitle: "Try describing it a different way.")
                    } else {
                        MatchesListView(results: shown)
                    }

                    RefinementTranscript(session: refinement, showsRefinedResults: false)
                }
                .padding()
            }

            RefinementBar(
                session: refinement,
                speechRecognizer: speechRecognizer,
                text: $refinementText
            )
        }
        .background(Color.scanBackground.ignoresSafeArea())
        .navigationTitle("Matches")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.scanBackground, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            // Carry the whole conversation so far, not just the last reply —
            // a refinement like "make it cheaper" depends on everything the
            // user already specified.
            refinement.seedHistory(messages)
        }
        .onChange(of: speechRecognizer.transcript) { _, newValue in
            refinementText = newValue
        }
        .onDisappear {
            speechRecognizer.stopRecording()
        }
    }
}

#Preview {
    NavigationStack {
        ChatResultsView(
            messages: [ChatMessage(role: .assistant, content: "Here are some black fur dusters under $150.")],
            results: []
        )
    }
}
