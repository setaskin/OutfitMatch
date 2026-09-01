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
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                ForEach(advice.recommendations) { recommendation in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(recommendation.label)
                            .font(.title3.weight(.bold))

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
        .navigationTitle("Style Advice")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        StyleAdviceResultsView(
            advice: StyleAdvice(advice: "Preview styling advice goes here.", recommendations: [])
        )
    }
}
