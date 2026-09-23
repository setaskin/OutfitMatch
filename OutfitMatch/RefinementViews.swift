//
//  RefinementViews.swift
//  OutfitMatch
//
//  The two pieces every results screen adds to become refinable: the
//  conversation so far, and the bar to continue it.

import SwiftUI

/// The refinement exchange, shown under whatever the screen already displays.
/// Renders nothing until the user actually refines.
struct RefinementTranscript: View {
    @ObservedObject var session: RefinementSession
    /// Style advice keeps its original recommendations on screen and appends
    /// refined results below; the flat-list screens swap theirs out instead.
    var showsRefinedResults = true

    var body: some View {
        if session.hasActivity {
            VStack(alignment: .leading, spacing: 16) {
                Rectangle()
                    .fill(Color.scanHairline)
                    .frame(height: 1)

                ForEach(session.transcript) { message in
                    ChatBubble(message: message)
                }

                if session.isSending {
                    HStack(spacing: 10) {
                        ProgressView().tint(Color.scanMint)
                        Text("Updating results…")
                            .font(.caption)
                            .foregroundStyle(Color.scanInkDim)
                        Spacer()
                    }
                }

                if showsRefinedResults, let refined = session.refinedResults {
                    if refined.isEmpty {
                        EmptyMatchesView(subtitle: "Nothing matched that. Try describing it differently.")
                    } else {
                        MatchesListView(results: refined)
                    }
                }
            }
        }
    }
}

/// Input bar for refining, plus any error from the last attempt.
struct RefinementBar: View {
    @ObservedObject var session: RefinementSession
    @ObservedObject var speechRecognizer: SpeechRecognizer
    @Binding var text: String
    var placeholder = "Refine — colour, budget, style…"

    var body: some View {
        VStack(spacing: 0) {
            if let error = session.errorMessage ?? speechRecognizer.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.scanAmber)
                    .padding(.horizontal)
                    .padding(.bottom, 4)
            }

            ChatInputBar(
                text: $text,
                speechRecognizer: speechRecognizer,
                placeholder: placeholder,
                isSending: session.isSending,
                onSend: {
                    speechRecognizer.stopRecording()
                    session.refine(text)
                    text = ""
                }
            )
        }
    }
}
