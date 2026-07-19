//
//  RootView.swift
//  SignLanguageApp
//
//  Created by Muhammad Hisyam Kamil on 17/07/26.
//

import SwiftUI

/// Navigation tabs for the two main pipelines plus history log.
enum AppTab: String, CaseIterable {
    case home, history, settings
    
    var title: String {
        switch self {
        case .home: "Home"
        case .history: "History"
        case .settings: "Settings"
        }
    }
    
    var icon: String {
        switch self {
        case .home: "house.fill"
        case .history: "clock"
        case .settings: "gearshape"
        }
    }
}

/// Root view — shows onboarding on first launch, then the tabbed main interface.
struct RootView: View {
    @State private var appStore = AppStore()
    @State private var selectedTab: AppTab = .home
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
                    HomeView()
                        .tabItem {
                            Label(
                                AppTab.home.title,
                                systemImage: AppTab.home.icon
                            )
                        }
                        .tag(AppTab.home)

                    HistoryView()
                        .tabItem {
                            Label(
                                AppTab.history.title,
                                systemImage: AppTab.history.icon
                            )
                        }
                        .tag(AppTab.history)

                    SettingsView()
                        .tabItem {
                            Label(
                                AppTab.settings.title,
                                systemImage: AppTab.settings.icon)
                        }
                        .tag(AppTab.settings)
                }
                .environment(appStore)
                .task { await appStore.checkPermissions() }
            }
        }
        .animation(.default, value: showOnboarding)
    }
}
