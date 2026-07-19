//
//  ConversationComponentView.swift
//  SignLanguageApp
//
//  Created by Antigravity on 17/07/26.
//

import SwiftUI

/// A reusable component that displays real-time transcription or translation status and output,
/// matching the iPhone 17 wireframes from Low Fidelity-New-Banget.
struct ConversationComponentView: View {
    let title: String
    let subtitle: String
    let iconName: String
    let senderLabel: String
    let messageText: String
    let isActive: Bool
    
    // Custom colors or accents if needed
    var accentColor: Color = .blue
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Status / Header Info
            HStack(spacing: 8) {
                // Circular icon badge
                iconBadge
                
                // Title and description
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .fontWeight(.semibold)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fontWeight(.medium)
                }
                
                Spacer()
            }
            .accessibilityElement(children: .combine)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.background)
                    .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
            )

            
            // Transcription Text Container
            VStack(alignment: .leading, spacing: 8) {
                Text(senderLabel)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.blue)
                
                Text(messageText.isEmpty ? "..." : "“\(messageText)”")
                    .font(.body)
//                    .foregroundStyle(messageText.isEmpty ? .tertiary : .primary)
//                    .italic(!messageText.isEmpty)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fontWeight(.semibold)
//                    .padding()
//                    .background(
//                        RoundedRectangle(cornerRadius: 12)
//                            .fill(.quaternary.opacity(0.3))
//                    )
            }
            .padding(.top, 4)
        }
        .padding(20)
//        .background(
//            Group {
//                if #available(iOS 26, *) {
//                    RoundedRectangle(cornerRadius: 16)
////                        .glassEffect(.regular)
//                } else {
//                    RoundedRectangle(cornerRadius: 16)
////                        .fill(.ultraThinMaterial)
//                }
//            }
//        )
    }
    
    @ViewBuilder
    private var iconBadge: some View {
        ZStack {
            Circle()
                .fill(accentColor.opacity(1))
                .frame(width: 44, height: 44)
            
            Image(systemName: iconName)
                .font(.title3.weight(.medium))
                .foregroundStyle(.white)
                .symbolEffect(.pulse, isActive: isActive)
        }
    }
}

#Preview("Sign to Text Active") {
    VStack{
        ConversationComponentView(
            title: "Sign to Text",
            subtitle: "Camera input translating in real-time",
            iconName: "hand.raised.fill",
            senderLabel: "Teman Tuli Transcribe:",
            messageText: "Saya sedang pergi ke rumah ibu yang sedang sakit, maaf terima kasih",
            isActive: true,
            accentColor: .blue
        )
        SeparatorLine()
        ConversationComponentView(
            title: "Speech to Text",
            subtitle: "Voice input transcribing in real-time",
            iconName: "mic.fill",
            senderLabel: "Care Giver Transcribe:",
            messageText: "Oh begitu, saya paham maksud anda! Dimengerti",
            isActive: false,
            accentColor: .blue
        )
    }
    
}

#Preview("Speech to Text Idle") {
    ConversationComponentView(
        title: "Speech to Text",
        subtitle: "Voice input transcribing in real-time",
        iconName: "mic.fill",
        senderLabel: "Care Giver Transcribe:",
        messageText: "Oh begitu, saya paham maksud anda! Dimengerti",
        isActive: false,
        accentColor: .blue
    )
    .padding()
}
