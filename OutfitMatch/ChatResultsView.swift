//
//  ChatResultsView.swift
//  OutfitMatch
//
//  Shows results already fetched by the chat flow — no re-search here,
//  ChatService.send already ran the SerpApi call once Claude had enough
//  detail.

import SwiftUI

struct ChatResultsView: View {
    let results: [MatchResult]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if results.isEmpty {
                    EmptyMatchesView(subtitle: "Try describing it a different way.")
                } else {
                    MatchesListView(results: results)
                }
            }
            .padding()
        }
        .background(Color.scanBackground.ignoresSafeArea())
        .navigationTitle("Matches")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.scanBackground, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

#Preview {
    NavigationStack {
        ChatResultsView(results: [])
    }
}
