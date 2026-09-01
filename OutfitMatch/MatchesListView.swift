//
//  MatchesListView.swift
//  OutfitMatch
//
//  Shared results rendering used by both the photo-search flow
//  (ResultsView) and the chat flow (ChatResultsView).

import SwiftUI

struct MatchesListView: View {
    let results: [MatchResult]

    var body: some View {
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
}

struct MatchRow: View {
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

struct EmptyMatchesView: View {
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No matches found")
                .font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}
