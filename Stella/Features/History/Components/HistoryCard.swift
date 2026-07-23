//
//  HistoryCard.swift
//  Stella
//
//  Created by Dimas Prihady Setyawan on 22/07/26.
//

import SwiftUI

struct HistoryCard: View {
    let score: Score
    let dateText: String
    let targetText: String
    let detectedWords: [DetectedWord]
    let accuracyText: String
    let wordCountText: String
    let durationText: String

    init(
        score: Score,
        dateText: String,
        targetText: String,
        detectedWords: [DetectedWord],
        accuracyText: String,
        wordCountText: String,
        durationText: String
    ) {
        self.score = score
        self.dateText = dateText
        self.targetText = targetText
        self.detectedWords = detectedWords
        self.accuracyText = accuracyText
        self.wordCountText = wordCountText
        self.durationText = durationText
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                ScoreBadge(score: score)

                Spacer()

                Text(dateText)
                    .font(.footnote)
                    .foregroundStyle(.gray)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Target")
                    .font(.footnote)
                    .foregroundStyle(.gray)
                    .fontWeight(.medium)

                Text("\"\(targetText)\"")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text("Kata terdeteksi")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    ForEach(detectedWords) { word in
                        DetectedWordBadge(word: word)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
                .overlay(Color.primary.opacity(0.1))

            HStack {
                MetricText(title: "Akurasi:", value: accuracyText)

                Spacer()

                MetricText(title: "Kata:", value: wordCountText)

                Spacer()

                MetricText(title: "Waktu:", value: durationText)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color("CardColor"))
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
        )
    }
}

extension HistoryCard {
    enum Score: String {
        case keren = "Keren"
        case bagus = "Bagus"
        case kurang = "Kurang"

        var color: Color {
            switch self {
            case .keren:
                .green
            case .bagus:
                .yellow
            case .kurang:
                .red
            }
        }

        var textColor: Color {
            switch self {
            case .keren:
                .green
            case .bagus:
                Color(red: 0.55, green: 0.36, blue: 0)
            case .kurang:
                .red
            }
        }
    }

    struct DetectedWord: Identifiable {
        let id = UUID()
        let text: String
        let isAnswered: Bool
    }
}

private struct ScoreBadge: View {
    let score: HistoryCard.Score

    var body: some View {
        PillBadge(
            text: score.rawValue,
            iconName: nil,
            tint: score.color,
            textColor: score.textColor
        )
    }
}

private struct DetectedWordBadge: View {
    let word: HistoryCard.DetectedWord

    private var tint: Color {
        word.isAnswered ? .green : .gray
    }

    var body: some View {
        PillBadge(
            text: word.text,
            iconName: word.isAnswered ? "checkmark" : "xmark",
            tint: tint,
            textColor: .primary
        )
    }
}

private struct PillBadge: View {
    let text: String
    let iconName: String?
    let tint: Color
    let textColor: Color

    var body: some View {
        HStack(spacing: 8) {
            if let iconName {
                Image(systemName: iconName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
            }

            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(textColor)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            Capsule()
                .fill(tint.opacity(0.12))
        )
        .overlay(
            Capsule()
                .stroke(tint.opacity(0.25), lineWidth: 1)
        )
    }
}

private struct MetricText: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.subheadline)

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 12) {
            HistoryCard(
                score: .keren,
                dateText: "21 Nov, 10.26",
                targetText: "Saya naik motor",
                detectedWords: [
                    .init(text: "Saya", isAnswered: true),
                    .init(text: "Naik", isAnswered: true),
                    .init(text: "Motor", isAnswered: true)
                ],
                accuracyText: "100%",
                wordCountText: "3/3",
                durationText: "12 Detik"
            )

            HistoryCard(
                score: .bagus,
                dateText: "21 Nov, 10.30",
                targetText: "Saya naik motor",
                detectedWords: [
                    .init(text: "Saya", isAnswered: true),
                    .init(text: "Naik", isAnswered: true),
                    .init(text: "Motor", isAnswered: false)
                ],
                accuracyText: "67%",
                wordCountText: "2/3",
                durationText: "30 Detik"
            )

            HistoryCard(
                score: .kurang,
                dateText: "21 Nov, 10.34",
                targetText: "Saya naik motor",
                detectedWords: [
                    .init(text: "Saya", isAnswered: true),
                    .init(text: "Naik", isAnswered: false),
                    .init(text: "Motor", isAnswered: false)
                ],
                accuracyText: "33%",
                wordCountText: "1/3",
                durationText: "30 Detik"
            )
        }
        .padding()
    }
}
