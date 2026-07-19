//
//  AppStyle.swift
//  SignLanguageApp
//
//  Created by Codex on 18/07/26.
//

import SwiftUI

enum AppStyle {
    enum TextSize {
        static let largeIcon: CGFloat = 72
        static let recordingIcon: CGFloat = 60
        static let idleIcon: CGFloat = 40
    }

    enum Font {
        static let largeIcon: SwiftUI.Font = .system(size: TextSize.largeIcon)
        static let recordingIcon: SwiftUI.Font = .system(size: TextSize.recordingIcon)
        static let idleIcon: SwiftUI.Font = .system(size: TextSize.idleIcon)
        static let primaryTitle: SwiftUI.Font = .largeTitle.weight(.bold)
        static let sectionTitle: SwiftUI.Font = .title2
        static let emphasizedSectionTitle: SwiftUI.Font = .title2.weight(.medium)
        static let actionTitle: SwiftUI.Font = .title2.weight(.semibold)
        static let toolbarIcon: SwiftUI.Font = .title3
        static let headline: SwiftUI.Font = .headline
        static let emphasizedHeadline: SwiftUI.Font = .headline.weight(.semibold)
        static let body: SwiftUI.Font = .body
        static let caption: SwiftUI.Font = .caption
        static let emphasizedCaption: SwiftUI.Font = .caption.weight(.semibold)
        static let smallCaption: SwiftUI.Font = .caption2
    }

    enum Color {
        static let accent = SwiftUI.Color.accentColor
        static let secondaryText = SwiftUI.Color.secondary
        static let tertiaryText = SwiftUI.Color(.tertiaryLabel)
        static let stopAction = SwiftUI.Color.red
        static let panelBackground = SwiftUI.Color(.quaternaryLabel).opacity(0.3)
        static let shadow = SwiftUI.Color.black.opacity(0.15)
    }
}
