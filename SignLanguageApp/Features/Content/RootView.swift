//
//  RootView.swift
//  SignLanguageApp
//
//  Created by Muhammad Hisyam Kamil on 17/07/26.
//

import SwiftUI

/// Navigation tabs for the two main pipelines plus history log.
enum AppTab: String, CaseIterable {
    case sign, history, settings

    var titleKey: LocalizedStringKey {
        switch self {
        case .sign: "tab.sign"
        case .history:      "tab.history"
        case .settings:     "tab.settings"
        }
    }

    var icon: String {
        switch self {
        case .sign: "hand.palm.facing.fill"
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
    @State private var selectedTab: AppTab = .sign
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
//                    TwoWayConversationView()
//                        .tabItem {
//                            Label(AppTab.conversation.titleKey, systemImage: AppTab.conversation.icon)
//                        }
//                        .tag(AppTab.conversation)

//                    SpeechToTextView()
//                        .tabItem {
//                            Label(AppTab.speechToText.titleKey, systemImage: AppTab.speechToText.icon)
//                        }
//                        .tag(AppTab.speechToText)
//
//                    SignToSpeechView()
//                        .tabItem {
//                            Label(AppTab.signToSpeech.titleKey, systemImage: AppTab.signToSpeech.icon)
//                        }
//                        .tag(AppTab.signToSpeech)

                    HistoryView()
                        .tabItem {
                            Label(AppTab.history.titleKey, systemImage: AppTab.history.icon)
                        }
                        .tag(AppTab.history)
                    
                    SignView()
                        .tabItem {
                            Label(AppTab.sign.titleKey, systemImage: AppTab.sign.icon)
                        }
                        .tag(AppTab.sign)

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
        .id(appStore.languageSettings.appLanguage)
        .environment(\.locale, appStore.languageSettings.appLanguage.locale)
        .animation(.default, value: showOnboarding)
    }
}
