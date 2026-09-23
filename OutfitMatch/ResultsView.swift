//
//  ResultsView.swift
//  OutfitMatch
//

import SwiftUI

struct ResultsView: View {
    let capturedImage: UIImage
    let categories: [ClothingCategory]

    @State private var results: [MatchResult] = []
    @State private var loadState: LoadState = .searching
    @StateObject private var refinement = RefinementSession()
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @State private var refinementText = ""

    private enum LoadState {
        case searching
        case loaded
        case empty
        case failed(String)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                Image(uiImage: capturedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .frame(maxWidth: .infinity)

                if !categories.isEmpty {
                    Text("Detected: \(categories.map(\.displayName).joined(separator: ", "))")
                        .font(ScanFont.mono(11))
                        .foregroundStyle(Color.scanInkDim)
                }

                    switch loadState {
                    case .searching:
                        HStack {
                            Spacer()
                            VStack(spacing: 12) {
                                ProgressView()
                                    .tint(Color.scanMint)
                                Text("Searching for matches…")
                                    .foregroundStyle(Color.scanInkDim)
                            }
                            Spacer()
                        }
                        .padding(.top, 40)
                    case .loaded:
                        // Refined results replace the photo matches, since a
                        // refinement is a new search rather than an addition.
                        MatchesListView(results: refinement.refinedResults ?? results)
                    case .empty:
                        EmptyMatchesView(subtitle: "Try a clearer photo, or a different angle.")
                    case .failed(let message):
                        errorState(message)
                    }

                    RefinementTranscript(session: refinement, showsRefinedResults: false)
                }
                .padding()
            }

            if case .loaded = loadState {
                RefinementBar(
                    session: refinement,
                    speechRecognizer: speechRecognizer,
                    text: $refinementText
                )
            }
        }
        .background(Color.scanBackground.ignoresSafeArea())
        .navigationTitle("Matches")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.scanBackground, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onChange(of: speechRecognizer.transcript) { _, newValue in
            refinementText = newValue
        }
        .onDisappear {
            speechRecognizer.stopRecording()
        }
        .task {
            await runSearch()
        }
    }

    private func runSearch() async {
        loadState = .searching
        do {
            let matches = try await SearchService.search(image: capturedImage, category: categories.first ?? .general)
            results = matches
            loadState = matches.isEmpty ? .empty : .loaded

            // A refinement arrives as text ("in black", "cheaper"), so the
            // conversation needs to know what the photo turned up first.
            if let closest = matches.first {
                let item = categories.first?.displayName.lowercased() ?? "item"
                refinement.seed(
                    "I searched the \(item) in your photo and the closest match was \"\(closest.title)\" "
                    + "from \(closest.retailer). Tell me what to change and I'll search again."
                )
            }
        } catch {
            loadState = .failed(errorMessage(for: error))
        }
    }

    private func errorMessage(for error: Error) -> String {
        switch error {
        case SearchServiceError.server(let message):
            return message
        case SearchServiceError.invalidImage:
            return "That photo couldn't be processed."
        default:
            return "Couldn't reach the search server. Make sure the backend is running."
        }
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(Color.scanAmber)
            Text("Search failed")
                .font(ScanFont.display(15, weight: .semibold))
                .foregroundStyle(Color.scanInk)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.scanInkDim)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Task { await runSearch() }
            }
            .buttonStyle(.bordered)
            .tint(Color.scanMint)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}

#Preview {
    NavigationStack {
        ResultsView(capturedImage: UIImage(systemName: "tshirt.fill")!, categories: [.outerwear])
    }
}
