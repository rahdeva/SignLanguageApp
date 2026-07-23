//
//  AppStyle.swift
//  Stella
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
        static let featureCardTitle: SwiftUI.Font = .title3.weight(.bold)
        static let featureCardDescription: SwiftUI.Font = .subheadline
        static let featureCardButton: SwiftUI.Font = .caption.weight(.semibold)
    }

    enum Color {
        static let accent = SwiftUI.Color.accentColor
        static let secondaryText = SwiftUI.Color.secondary
        static let tertiaryText = SwiftUI.Color(.tertiaryLabel)
        static let stopAction = SwiftUI.Color.red
        static let panelBackground = SwiftUI.Color(.quaternaryLabel).opacity(0.3)
        static let shadow = SwiftUI.Color.black.opacity(0.15)
        static let featureCardButtonBackground = SwiftUI.Color(uiColor: .systemBackground)
    }

    enum Layout {
        static let featureCardHeight: CGFloat = 190
        static let featureCardHorizontalSpacing: CGFloat = 12
        static let featureCardTextSpacing: CGFloat = 6
        static let featureCardContentInset: CGFloat = 24
        static let featureCardTopImageSpacing: CGFloat = 8
        static let featureCardCharacterWidth: CGFloat = 130
        static let featureCardCharacterHeight: CGFloat = 130
        static let featureCardCharacterScale: CGFloat = 1.2
        static let featureCardTextTrailingSpace: CGFloat = 132
        static let featureCardTextBottomPadding: CGFloat = 20
        static let featureCardButtonHorizontalPadding: CGFloat = 32
        static let featureCardButtonVerticalPadding: CGFloat = 12
        static let featureCardButtonBottomPadding: CGFloat = 20
        static let featureCardCornerRadius: CGFloat = 32
        static let featureCardButtonCornerRadius: CGFloat = 14
    }
}
