//
//  RootView.swift
//  SignLanguageApp
//
//  Created by Muhammad Hisyam Kamil on 17/07/26.
//

import SwiftUI

/// Navigation tabs for the two main pipelines plus history log.
enum AppTab: String, CaseIterable {
    case speechToText, signToSpeech, history

    var title: String {
        switch self {
        case .speechToText: "Speech"
        case .signToSpeech: "Sign"
        case .history: "History"
        }
    }

    var icon: String {
        switch self {
        case .speechToText: "mic"
        case .signToSpeech: "camera"
        case .history: "clock"
        }
    }
}

/// Root view — shows onboarding on first launch, then the tabbed main interface.
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
                            Label(
                                AppTab.speechToText.title,
                                systemImage: AppTab.speechToText.icon
                            )
                        }
                        .tag(AppTab.speechToText)

                    SignToSpeechView()
                        .tabItem {
                            Label(
                                AppTab.signToSpeech.title,
                                systemImage: AppTab.signToSpeech.icon
                            )
                        }
                        .tag(AppTab.signToSpeech)

                    HistoryView()
                        .tabItem {
                            Label(
                                AppTab.history.title,
                                systemImage: AppTab.history.icon
                            )
                        }
                        .tag(AppTab.history)
                    
                    UnifiedView()
                        .tabItem {
                            Label(
                                AppTab.history.title,
                                systemImage: AppTab.history.icon
                            )
                        }
                        .tag(AppTab.history)

                    SettingsView()
                        .tabItem { Label("Settings", systemImage: "gearshape") }
                }
                .environment(appStore)
                .task { await appStore.checkPermissions() }
            }
        }
        .animation(.default, value: showOnboarding)
    }
}
