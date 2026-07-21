//
//  MessageBubbleView.swift
//  SignLanguageApp
//
//  Created by Muhammad Hisyam Kamil on 21/07/26.
//

import SwiftUI

struct MessageBubbleView: View {
    let content: String
    let role: MessageRole
    let timestamp: Date
    var isPending: Bool = false

    private var isLeftAligned: Bool { role == .sign }
    private var accentColor: Color { role == .sign ? .blue : .green }

    var body: some View {
        HStack {
            if !isLeftAligned { Spacer(minLength: 60) }

            VStack(alignment: isLeftAligned ? .leading : .trailing, spacing: 4) {
                Text(content)
                    .font(.body)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(accentColor.opacity(isPending ? 0.6 : 1))
                    .clipShape(.rect(cornerRadius: 18))
                    .overlay(alignment: isLeftAligned ? .bottomLeading : .bottomTrailing) {
                        Image(systemName: "arrowtriangle.down.fill")
                            .font(.caption)
                            .foregroundStyle(accentColor.opacity(isPending ? 0.6 : 1))
                            .offset(x: isLeftAligned ? 6 : -6, y: 4)
                    }

                Text(timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }

            if isLeftAligned { Spacer(minLength: 60) }
        }
        .padding(.horizontal, 12)
        .opacity(isPending ? 0.7 : 1)
    }
}

#Preview("Sign (left)") {
    VStack(spacing: 16) {
        MessageBubbleView(
            content: "Saya mau pergi ke rumah sakit",
            role: .sign,
            timestamp: .now
        )
        MessageBubbleView(
            content: "Oh baik, saya antar ya",
            role: .speech,
            timestamp: .now
        )
        MessageBubbleView(
            content: "Terima kasih...",
            role: .sign,
            timestamp: .now,
            isPending: true
        )
    }
    .padding()
}
