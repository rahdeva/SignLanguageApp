//
//  HistoryView.swift
//  SignLanguageApp
//
//  Created by Muhammad Hisyam Kamil on 17/07/26.
//

import SwiftUI

/// Conversation history tab — shows all transcribed/spoken entries in reverse order.
struct HistoryView: View {
    @Environment(AppStore.self) private var appStore

    var body: some View {
        NavigationStack {
            Group {
                if appStore.conversationHistory.isEmpty {
                    ContentUnavailableView {
                        Label(
                            LocalizedStringKey("history.empty_title"),
                            systemImage: "clock.arrow.circlepath"
                        )
                    } description: {
                        Text("history.empty_desc", tableName: "Localizable")
                    }
                } else {
                    List(appStore.conversationHistory.reversed()) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(entry.role.label(for: appStore.languageSettings.appLanguage))
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
            .navigationTitle(Text("history.title", tableName: "Localizable"))
        }
    }
}

#Preview {
    HistoryView()
        .environment(AppStore())
}
