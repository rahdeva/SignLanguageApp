//
//  HistoryView.swift
//  Stella
//
//  Created by Antigravity on 23/07/26.
//

import SwiftUI
import SwiftData

/// Conversation & practice history tab — renders SwiftData persistent history items using HistoryCard.
struct HistoryView: View {
    @Query(sort: \PracticeHistoryItem.date, order: .reverse) private var historyItems: [PracticeHistoryItem]
    @Environment(\.modelContext) private var modelContext

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM, HH.mm"
        return formatter
    }()

    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()

                if historyItems.isEmpty {
                    ContentUnavailableView {
                        Label(
                            LocalizedStringKey("history.empty_title"),
                            systemImage: "clock.arrow.circlepath"
                        )
                    } description: {
                        Text("history.empty_desc", tableName: "Localizable")
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(historyItems) { item in
                                let score: HistoryCard.Score = item.scoreRawValue == "Keren" ? .keren : (item.scoreRawValue == "Bagus" ? .bagus : .kurang)
                                let accuracy = item.targetTokens.isEmpty ? "0%" : "\(Int(Double(item.completedCount) / Double(item.targetTokens.count) * 100))%"
                                let detected = item.targetTokens.enumerated().map { idx, token in
                                    HistoryCard.DetectedWord(text: token, isAnswered: idx < item.completedCount)
                                }

                                HistoryCard(
                                    score: score,
                                    dateText: Self.dateFormatter.string(from: item.date),
                                    targetText: item.question,
                                    detectedWords: detected,
                                    accuracyText: accuracy,
                                    wordCountText: "\(item.completedCount)/\(item.targetTokens.count)",
                                    durationText: "\(item.durationSeconds) Detik"
                                )
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle(Text("history.title", tableName: "Localizable"))
        }
    }
}

#Preview {
    HistoryView()
        .environment(AppStore())
}
