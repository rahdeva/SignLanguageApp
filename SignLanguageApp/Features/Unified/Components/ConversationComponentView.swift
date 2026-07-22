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
    let showHeaderCard: Bool
    let onReadAloud: (() -> Void)?
    let labelActionIconName: String?
    let labelActionAccessibilityLabel: String?
    let labelActionTint: Color
    let onLabelAction: (() -> Void)?
    
    // Custom colors or accents if needed
    var accentColor: Color = .blue

    init(
        title: String,
        subtitle: String,
        iconName: String,
        senderLabel: String,
        messageText: String,
        isActive: Bool,
        showHeaderCard: Bool = true,
        accentColor: Color = .blue,
        onReadAloud: (() -> Void)? = nil,
        labelActionIconName: String? = nil,
        labelActionAccessibilityLabel: String? = nil,
        labelActionTint: Color = .blue,
        onLabelAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
        self.senderLabel = senderLabel
        self.messageText = messageText
        self.isActive = isActive
        self.showHeaderCard = showHeaderCard
        self.accentColor = accentColor
        self.onReadAloud = onReadAloud
        self.labelActionIconName = labelActionIconName
        self.labelActionAccessibilityLabel = labelActionAccessibilityLabel
        self.labelActionTint = labelActionTint
        self.onLabelAction = onLabelAction
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Status / Header Info
            if showHeaderCard {
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
            }

            
            // Transcription Text Container
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(senderLabel)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.blue)

                    if let onReadAloud {
                        Button(action: onReadAloud) {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.title3.weight(.semibold))
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                        .disabled(messageText.isEmpty)
                        .accessibilityLabel("Read \(senderLabel)")
                    }

                    if let labelActionIconName, let onLabelAction {
                        Button(action: onLabelAction) {
                            Image(systemName: labelActionIconName)
                                .font(.title3.weight(.semibold))
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(labelActionTint)
                        .accessibilityLabel(labelActionAccessibilityLabel ?? senderLabel)
                    }
                }
                
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
        .padding(.horizontal,20)
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
