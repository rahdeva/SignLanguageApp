//
//  RootView.swift
//  SignLanguageApp
//
//  Created by Muhammad Hisyam Kamil on 17/07/26.
//

import SwiftUI

/// Navigation tabs for the two main pipelines plus history log.
enum AppTab: String, CaseIterable {
    case speechToText, signToSpeech, history, settings

    var titleKey: LocalizedStringKey {
        switch self {
        case .speechToText: "tab.speech"
        case .signToSpeech: "tab.sign"
        case .history:      "tab.history"
        case .settings:     "tab.settings"
        }
    }

    var icon: String {
        switch self {
        case .speechToText: "mic"
        case .signToSpeech: "camera"
        case .history:      "clock"
        case .settings:     "gearshape"
        }
    }
}

/// Root view — shows onboarding on first launch, then the tabbed main interface.
/// Injects both `AppStore` and the chosen `Locale` into the environment so all
/// child views automatically render in the correct language.
struct RootView: View {
    @State private var appStore = AppStore()
    @State private var selectedTab: AppTab = .speechToText
    @State private var showOnboarding = !UserDefaults.standard.bool(
        forKey: "hasSeenOnboarding"
    )

    var body: some View {
        Group {
            if showOnboarding {
                OnboardingView(isPresented: $showOnboarding)
                    .transition(.opacity)
            } else {
                TabView(selection: $selectedTab) {
                    SpeechToTextView()
                        .tabItem {
                            Label(AppTab.speechToText.titleKey, systemImage: AppTab.speechToText.icon)
                        }
                        .tag(AppTab.speechToText)

                    SignToSpeechView()
                        .tabItem {
                            Label(AppTab.signToSpeech.titleKey, systemImage: AppTab.signToSpeech.icon)
                        }
                        .tag(AppTab.signToSpeech)

                    HistoryView()
                        .tabItem {
                            Label(AppTab.history.titleKey, systemImage: AppTab.history.icon)
                        }
                        .tag(AppTab.history)

                    SettingsView()
                        .tabItem {
                            Label(AppTab.settings.titleKey, systemImage: AppTab.settings.icon)
                        }
                        .tag(AppTab.settings)
                }
                .environment(appStore)
                .task { await appStore.checkPermissions() }
            }
        }
        // Re-render entire subtree when app language changes
        .environment(\.locale, appStore.languageSettings.appLanguage.locale)
        .animation(.default, value: showOnboarding)
    }
}
