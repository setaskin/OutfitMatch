//
//  MatchesListView.swift
//  OutfitMatch
//
//  Shared results rendering used by the photo-search, chat, and style
//  advisor flows. Poshmark-style photo grid: large product image, price
//  and title below. The single closest match gets a full-width hero card;
//  alternatives fill a 2-column grid. Styled with the Scan Line theme.

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
                    sectionHeader("Closest Match")
                    MatchCard(item: exactMatch, imageAspectRatio: 4.0 / 3.0)
                }
            }

            if !alternatives.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader("Cheaper Alternatives")

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(alternatives) { item in
                            MatchCard(item: item, imageAspectRatio: 3.0 / 4.0)
                        }
                    }
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(ScanFont.display(15, weight: .semibold))
            .foregroundStyle(Color.scanInk)
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
                    .font(ScanFont.display(14, weight: .bold))
                    .foregroundStyle(Color.scanMint)

                Text(item.title)
                    .font(.caption)
                    .foregroundStyle(Color.scanInk.opacity(0.85))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(item.retailer)
                    .font(ScanFont.mono(10))
                    .foregroundStyle(Color.scanInkDim)
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
            .fill(Color.scanSurface)
            .aspectRatio(imageAspectRatio, contentMode: .fit)
            .overlay {
                if let url = item.thumbnailURL {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            Image(systemName: "tshirt.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(Color.scanInkDim)
                        }
                    }
                } else {
                    Image(systemName: "tshirt.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.scanInkDim)
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
                .foregroundStyle(Color.scanInkDim)
            Text("No matches found")
                .font(ScanFont.display(15, weight: .semibold))
                .foregroundStyle(Color.scanInk)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(Color.scanInkDim)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}
