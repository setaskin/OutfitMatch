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
                    resultsList
                case .empty:
                    emptyState
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

    private var resultsList: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(groupedSections, id: \.title) { section in
                Text(section.title)
                    .font(.headline)
                    .padding(.top, 4)

                ForEach(section.items) { item in
                    MatchRow(item: item)
                }
            }
        }
    }

    private var groupedSections: [(title: String, items: [MatchResult])] {
        let exact = results.filter { $0.matchType == .exact }
        let alternatives = results.filter { $0.matchType == .alternative }
        var sections: [(String, [MatchResult])] = []
        if !exact.isEmpty { sections.append(("Closest Match", exact)) }
        if !alternatives.isEmpty { sections.append(("Cheaper Alternatives", alternatives)) }
        return sections
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No matches found")
                .font(.headline)
            Text("Try a clearer photo, or a different angle.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
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

private struct MatchRow: View {
    let item: MatchResult

    var body: some View {
        Button {
            if let link = item.link {
                UIApplication.shared.open(link)
            }
        } label: {
            HStack(spacing: 14) {
                thumbnail

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Text(item.retailer)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(item.price, format: .currency(code: "USD"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .padding(12)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .disabled(item.link == nil)
    }

    @ViewBuilder
    private var thumbnail: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(.secondarySystemBackground))
            .frame(width: 64, height: 64)
            .overlay {
                if let url = item.thumbnailURL {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            Image(systemName: "tshirt.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Image(systemName: "tshirt.fill")
                        .foregroundStyle(.secondary)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    NavigationStack {
        ResultsView(capturedImage: UIImage(systemName: "tshirt.fill")!, categories: [.outerwear])
    }
}
