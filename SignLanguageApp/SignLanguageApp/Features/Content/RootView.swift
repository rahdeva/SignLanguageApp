//
//  RootView.swift
//  SignLanguageApp
//
//  Created by Muhammad Hisyam Kamil on 17/07/26.
//

import SwiftUI

/// Navigation tabs for the two main pipelines plus history log.
enum AppTab: String, CaseIterable {
    case speechToText = "Speech"
    case signToSpeech = "Sign"
    case history

    var title: String {
        switch self {
        case .speechToText: "Speech to Text"
        case .signToSpeech: "Sign to Speech"
        case .history: "History"
        }
    }

    var icon: String {
        switch self {
        case .speechToText: "mic"
        case .signToSpeech: "camera"
        case .history: "clock"
        }
    }
}

/// Root view — hosts `AppStore` in the environment and presents a three-tab layout.
struct RootView: View {
    @State private var appStore = AppStore()
    @State private var selectedTab: AppTab = .speechToText

    var body: some View {
        TabView(selection: $selectedTab) {
            SpeechToTextView()
                .tabItem {
                    Label(
                        AppTab.speechToText.title,
                        systemImage: AppTab.speechToText.icon
                    )
                }
                .tag(AppTab.speechToText)

            SignToSpeechView()
                .tabItem {
                    Label(
                        AppTab.signToSpeech.title,
                        systemImage: AppTab.signToSpeech.icon
                    )
                }
                .tag(AppTab.signToSpeech)

            HistoryView()
                .tabItem {
                    Label(
                        AppTab.history.title,
                        systemImage: AppTab.history.icon
                    )
                }
                .tag(AppTab.history)
        }
        .environment(appStore)
        .task { await appStore.checkPermissions() }
    }
}

// MARK: - History Tab

private struct HistoryView: View {
    @Environment(AppStore.self) private var appStore

    var body: some View {
        NavigationStack {
            Group {
                if appStore.conversationHistory.isEmpty {
                    ContentUnavailableView(
                        "No History",
                        systemImage: "clock.arrow.circlepath",
                        description: Text(
                            "Start transcribing or signing to build your conversation history."
                        )
                    )
                } else {
                    List(appStore.conversationHistory.reversed()) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(entry.role.label)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tint)
                                Spacer()
                                Text(entry.timestamp, style: .time)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Text(entry.message)
                                .font(.body)
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("History")
        }
    }
}

extension ConversationRole {
    fileprivate var label: String {
        switch self {
        case .userSigned: "You (Sign)"
        case .userSpoke: "You (Speech)"
        case .assistantSpoke: "Assistant"
        }
    }
}
