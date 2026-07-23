//
//  HomeView.swift
//  Stella
//
//  Created by Antigravity on 23/07/26.
//

import SwiftUI

struct HomeView: View {
    @Environment(AppStore.self) private var appStore
    @State private var selectedDestination: HomeDestination? = nil

    enum HomeDestination: Hashable {
        case dictionary
        case practiceWithoutVideo
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header Banner
                    headerView

                    // Main 2 Menu Cards
                    VStack(spacing: 16) {
                        // Card 1: Kamus Isyarat (Dictionary with Video)
                        NavigationLink(value: HomeDestination.dictionary) {
                            menuCard(
                                titleKey: "home.card1_title",
                                subtitleKey: "home.card1_subtitle",
                                iconName: "play.rectangle.fill",
                                gradientColors: [Color.blue, Color.indigo]
                            )
                        }

                        // Card 2: Latihan Tanpa Video (Practice without Video)
                        NavigationLink(value: HomeDestination.practiceWithoutVideo) {
                            menuCard(
                                titleKey: "home.card2_title",
                                subtitleKey: "home.card2_subtitle",
                                iconName: "hand.raised.fill",
                                gradientColors: [Color.purple, Color.blue]
                            )
                        }
                    }

                    Spacer(minLength: 20)
                }
                .padding(16)
            }
            .navigationTitle("tab.home")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: HomeDestination.self) { destination in
                switch destination {
                case .dictionary:
                    SingleWordPracticeView(
                        showVideoTutorial: true,
                        isRandomMode: false
                    )
                    .navigationTitle("home.card1_title")
                case .practiceWithoutVideo:
                    SingleWordPracticeView(
                        showVideoTutorial: false,
                        isRandomMode: true
                    )
                    .navigationTitle("home.card2_title")
                }
            }
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("home.welcome_title", tableName: "Localizable")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Text("home.welcome_subtitle", tableName: "Localizable")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func menuCard(
        titleKey: String,
        subtitleKey: String,
        iconName: String,
        gradientColors: [Color]
    ) -> some View {
        HStack(spacing: 16) {
            // Icon Badge with Gradient
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .shadow(color: gradientColors.first?.opacity(0.4) ?? .clear, radius: 8, x: 0, y: 4)

                Image(systemName: iconName)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
            }

            // Card Text Content
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(titleKey), tableName: "Localizable")
                    .font(.title3.weight(.bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)

                Text(LocalizedStringKey(subtitleKey), tableName: "Localizable")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            // Chevron Arrow Indicator
            Image(systemName: "chevron.right")
                .font(.headline.weight(.semibold))
                .foregroundColor(.secondary.opacity(0.6))
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
        )
    }
}

#Preview {
    HomeView()
        .environment(AppStore())
}
