//
//  SessionListView.swift
//  SignLanguageApp
//
//  Created by Muhammad Hisyam Kamil on 21/07/26.
//

import SwiftData
import SwiftUI

struct SessionListView: View {
    @Query(sort: \ChatSession.createdAt, order: .reverse)
    private var sessions: [ChatSession]

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    ContentUnavailableView {
                        Label("history.empty_title", systemImage: "clock.arrow.circlepath")
                    } description: {
                        Text("history.empty_desc")
                    }
                } else {
                    List(sessions) { session in
                        NavigationLink {
                            SessionDetailView(session: session)
                        } label: {
                            SessionRowView(session: session)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("history.title")
        }
    }
}

private struct SessionRowView: View {
    let session: ChatSession

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.title ?? String(localized: "history.session_untitled"))
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                if session.isActive {
                    Text("session.active")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }

            HStack(spacing: 8) {
                Text(session.createdAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("•")
                    .foregroundStyle(.secondary)
                Text(String.localizedStringWithFormat(NSLocalizedString("history.session_messages", comment: ""), session.messageCount))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SessionListView()
}
