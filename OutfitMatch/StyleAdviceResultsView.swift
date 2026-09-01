//
//  StyleAdviceResultsView.swift
//  OutfitMatch
//

import SwiftUI

struct StyleAdviceResultsView: View {
    let advice: StyleAdvice

    var body: some View {
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
            }
            .padding()
        }
        .background(Color.scanBackground.ignoresSafeArea())
        .navigationTitle("Style Advice")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.scanBackground, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

#Preview {
    NavigationStack {
        StyleAdviceResultsView(
            advice: StyleAdvice(advice: "Preview styling advice goes here.", recommendations: [])
        )
    }
}
