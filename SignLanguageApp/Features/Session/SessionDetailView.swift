//
//  SessionDetailView.swift
//  SignLanguageApp
//
//  Created by Muhammad Hisyam Kamil on 21/07/26.
//

import SwiftUI

struct SessionDetailView: View {
    let session: ChatSession
    var onResume: ((ChatSession) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 4) {
                Text(session.title ?? String(localized: "history.session_untitled"))
                    .font(.title2.weight(.semibold))
                Text(session.createdAt, style: .date)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let endedAt = session.endedAt {
                    let minutes = Int(endedAt.timeIntervalSince(session.createdAt) / 60)
                    let messagesPart = String.localizedStringWithFormat(
                        NSLocalizedString("history.session_messages", comment: ""),
                        session.messageCount
                    )
                    let durationPart = minutes > 0
                        ? " • " + String.localizedStringWithFormat(
                            NSLocalizedString("history.session_duration", comment: ""),
                            minutes
                        )
                        : ""
                    Text(messagesPart + durationPart)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()

            Divider()

            // Messages
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(session.messages.sorted { $0.createdAt < $1.createdAt }) { message in
                        MessageBubbleView(
                            content: message.content,
                            role: message.role,
                            timestamp: message.createdAt
                        )
                    }
                }
                .padding(.vertical, 12)
            }

            // Resume button
            if session.endedAt != nil, let onResume {
                Divider()
                Button {
                    onResume(session)
                } label: {
                    Label("history.resume", systemImage: "arrow.forward.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
        }
        .navigationTitle("history.detail_title")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SessionDetailView(session: ChatSession())
    }
}
