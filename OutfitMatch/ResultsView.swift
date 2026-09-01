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

    private enum LoadState {
        case searching
        case loaded
        case empty
        case failed(String)
    }

    var body: some View {
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
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                switch loadState {
                case .searching:
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Searching for matches…")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.top, 40)
                case .loaded:
                    MatchesListView(results: results)
                case .empty:
                    EmptyMatchesView(subtitle: "Try a clearer photo, or a different angle.")
                case .failed(let message):
                    errorState(message)
                }
            }
            .padding()
        }
        .navigationTitle("Matches")
        .navigationBarTitleDisplayMode(.inline)
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
                .foregroundStyle(.secondary)
            Text("Search failed")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Task { await runSearch() }
            }
            .buttonStyle(.bordered)
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
