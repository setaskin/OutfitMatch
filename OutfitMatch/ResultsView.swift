//
//  ResultsView.swift
//  OutfitMatch
//

import SwiftUI

struct ResultsView: View {
    let capturedImage: UIImage
    let categories: [ClothingCategory]

    @State private var resultsByCategory: [(category: ClothingCategory, results: [MatchResult])] = []
    @State private var isSearching = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Image(uiImage: capturedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .frame(maxWidth: .infinity)

                if isSearching {
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
                } else {
                    resultsList
                }
            }
            .padding()
        }
        .navigationTitle("Matches")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            resultsByCategory = await withTaskGroup(of: (Int, ClothingCategory, [MatchResult]).self) { group in
                for (index, category) in categories.enumerated() {
                    group.addTask {
                        let results = await MockSearch.find(for: category)
                        return (index, category, results)
                    }
                }

                var ordered = Array(repeating: (ClothingCategory.general, [MatchResult]()), count: categories.count)
                for await (index, category, results) in group {
                    ordered[index] = (category, results)
                }
                return ordered
            }
            isSearching = false
        }
    }

    private var resultsList: some View {
        VStack(alignment: .leading, spacing: 28) {
            if categories.count > 1 {
                Text("Found \(categories.count) items in this photo")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(resultsByCategory, id: \.category) { entry in
                VStack(alignment: .leading, spacing: 16) {
                    Text(entry.category.displayName)
                        .font(.title3.weight(.bold))

                    ForEach(groupedSections(for: entry.results), id: \.title) { section in
                        Text(section.title)
                            .font(.headline)
                            .padding(.top, 4)

                        ForEach(section.items) { item in
                            MatchRow(item: item)
                        }
                    }
                }
            }
        }
    }

    private func groupedSections(for results: [MatchResult]) -> [(title: String, items: [MatchResult])] {
        let exact = results.filter { $0.matchType == .exact }
        let alternatives = results.filter { $0.matchType == .alternative }
        var sections: [(String, [MatchResult])] = []
        if !exact.isEmpty { sections.append(("Exact Match", exact)) }
        if !alternatives.isEmpty { sections.append(("Cheaper Alternatives", alternatives)) }
        return sections
    }
}

private struct MatchRow: View {
    let item: MatchResult

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
                .frame(width: 64, height: 64)
                .overlay(
                    Image(systemName: item.systemImageName)
                        .font(.title2)
                        .foregroundStyle(.secondary)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline.weight(.medium))
                Text(item.retailer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(item.price, format: .currency(code: "USD"))
                .font(.subheadline.weight(.semibold))
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

#Preview {
    NavigationStack {
        ResultsView(capturedImage: UIImage(systemName: "tshirt.fill")!, categories: [.outerwear, .footwear])
    }
}
