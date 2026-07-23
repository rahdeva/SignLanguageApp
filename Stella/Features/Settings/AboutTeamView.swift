//
//  AboutTeamView.swift
//  Stella
//
//  Created by Muhammad Hisyam Kamil on 17/07/26.
//

import SwiftUI

/// Displays team members in random order with a random chicken emoji each time.
struct AboutTeamView: View {
    private let teamName = "Dewa Ayam"
    private let members = [
        "Muhammad Hisyam Kamil",
        "Deva Wirandana",
        "Cyintia Limmanto",
        "Fuad Agus Salim",
        "Dimas Prihady Setyawan",
    ]
    private let chickenEmojis = [
        "🐔", "🐓", "🐤", "🐥", "🐣",
        "🍗", "🥚", "🍳", "🪺", "🐦‍⬛",
    ]
    @State private var shuffled: [(name: String, emoji: String)] = []

    var body: some View {
        List {
            ForEach(shuffled.indices, id: \.self) { index in
                HStack {
                    Text(shuffled[index].emoji)
                        .font(.title2)
                    Text(shuffled[index].name)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(teamName)
        .onAppear { reshuffle() }
    }

    private func reshuffle() {
        var memberCopy = members
        memberCopy.shuffle()
        shuffled = memberCopy.map { ($0, chickenEmojis.randomElement()!) }
    }
}

#Preview {
    NavigationStack {
        AboutTeamView()
    }
}
