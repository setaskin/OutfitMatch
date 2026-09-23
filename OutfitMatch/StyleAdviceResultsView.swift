//
//  StyleAdviceResultsView.swift
//  OutfitMatch
//
//  Claude's styling advice plus a shoppable list per recommendation, with
//  the same refinement chat the other two search paths have.

import SwiftUI

struct StyleAdviceResultsView: View {
    let advice: StyleAdvice

    @StateObject private var refinement = RefinementSession()
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @State private var refinementText = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text(advice.advice)
                        .font(.body)
                        .foregroundStyle(Color.scanInk)
                        .padding()
                        .background(Color.scanSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                    ForEach(advice.recommendations) { recommendation in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(recommendation.label)
                                .font(ScanFont.display(17, weight: .bold))
                                .foregroundStyle(Color.scanInk)

                            if recommendation.matches.isEmpty {
                                EmptyMatchesView(subtitle: "No shopping results found for this one.")
                            } else {
                                MatchesListView(results: recommendation.matches)
                            }
                        }
                    }

                    // Unlike the flat-list screens, refined results append
                    // below rather than replacing — the advice and its
                    // recommendations are still worth keeping on screen.
                    RefinementTranscript(session: refinement)
                }
                .padding()
            }

            RefinementBar(
                session: refinement,
                speechRecognizer: speechRecognizer,
                text: $refinementText,
                placeholder: "Ask a follow-up, or refine a pick…"
            )
        }
        .background(Color.scanBackground.ignoresSafeArea())
        .navigationTitle("Style Advice")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.scanBackground, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            // Claude wrote this advice, so it's genuine prior context for a
            // follow-up like "show me those in black".
            let picks = advice.recommendations.map(\.label).joined(separator: ", ")
            refinement.seed(
                picks.isEmpty
                    ? advice.advice
                    : "\(advice.advice)\n\nI suggested: \(picks)."
            )
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
        StyleAdviceResultsView(
            advice: StyleAdvice(advice: "Preview styling advice goes here.", recommendations: [])
        )
    }
}
