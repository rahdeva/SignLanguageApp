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
                                    .font(AppStyle.Font.emphasizedCaption)
                                    .foregroundStyle(AppStyle.Color.accent)
                                Spacer()
                                Text(entry.timestamp, style: .time)
                                    .font(AppStyle.Font.smallCaption)
                                    .foregroundStyle(AppStyle.Color.secondaryText)
                            }
                            Text(entry.message)
                                .font(AppStyle.Font.body)
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

#Preview {
    HistoryView()
        .environment(AppStore())
}
