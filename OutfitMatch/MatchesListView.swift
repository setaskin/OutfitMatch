//
//  MatchesListView.swift
//  OutfitMatch
//
//  Shared results rendering used by both the photo-search flow
//  (ResultsView) and the chat flow (ChatResultsView). Poshmark-style photo
//  grid: large product image, price and title below. The single closest
//  match gets a full-width hero card; alternatives fill a 2-column grid.

import SwiftUI

struct MatchesListView: View {
    let results: [MatchResult]

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            if let exactMatch {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Closest Match")
                        .font(.headline)
                    MatchCard(item: exactMatch, imageAspectRatio: 4.0 / 3.0)
                }
            }

            if !alternatives.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Cheaper Alternatives")
                        .font(.headline)

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(alternatives) { item in
                            MatchCard(item: item, imageAspectRatio: 3.0 / 4.0)
                        }
                    }
                }
            }
        }
    }

    private var exactMatch: MatchResult? {
        results.first { $0.matchType == .exact }
    }

    private var alternatives: [MatchResult] {
        results.filter { $0.matchType == .alternative }
    }
}

struct MatchCard: View {
    let item: MatchResult
    var imageAspectRatio: CGFloat = 3.0 / 4.0

    var body: some View {
        Button {
            if let link = item.link {
                UIApplication.shared.open(link)
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                thumbnail

                Text(item.price, format: .currency(code: "USD"))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)

                Text(item.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(item.retailer)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .disabled(item.link == nil)
    }

    @ViewBuilder
    private var thumbnail: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(Color(.secondarySystemBackground))
            .aspectRatio(imageAspectRatio, contentMode: .fit)
            .overlay {
                if let url = item.thumbnailURL {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            Image(systemName: "tshirt.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Image(systemName: "tshirt.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
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
