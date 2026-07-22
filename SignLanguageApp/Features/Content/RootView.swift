//
//  RootView.swift
//  SignLanguageApp
//
//  Created by Muhammad Hisyam Kamil on 17/07/26.
//

import SwiftUI

/// Navigation tabs for the two main pipelines plus history log.
enum AppTab: String, CaseIterable {
    case conversation, history, settings

    var titleKey: LocalizedStringKey {
        switch self {
        case .conversation: "tab.conversation"
        case .history:      "tab.history"
        case .settings:     "tab.settings"
        }
    }

    var icon: String {
        switch self {
        case .conversation: "hand.wave"
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
    @State private var selectedTab: AppTab = .conversation
    @State private var showOnboarding = !UserDefaults.standard.bool(
        forKey: "hasSeenOnboarding"
    )
    @State private var showSplash = true

    var body: some View {
        ZStack {
            if showSplash {
                SplashView()
                    .transition(.opacity)
            } else {
                Group {
                    if showOnboarding {
                        OnboardingView(isPresented: $showOnboarding)
                            .transition(.opacity)
                    } else {
                        TabView(selection: $selectedTab) {
                            SignView()
                                .tabItem {
                                    Label(AppTab.conversation.titleKey, systemImage: AppTab.conversation.icon)
                                }
                                .tag(AppTab.conversation)

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
                .transition(.opacity)
            }
        }
        // Re-render entire subtree when app language changes
        .id(appStore.languageSettings.appLanguage)
        .environment(\.locale, appStore.languageSettings.appLanguage.locale)
        .animation(.default, value: showOnboarding)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeOut(duration: 0.5)) {
                    showSplash = false
                }
            }
        }
    }
}

#Preview {
    RootView()
}
