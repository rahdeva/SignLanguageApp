//
//  RootView.swift
//  SignLanguageApp
//
//  Created by Muhammad Hisyam Kamil on 17/07/26.
//

import SwiftUI
import UIKit

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
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "hasSeenOnboarding")

    var body: some View {
        Group {
            if showOnboarding {
                OnboardingView(isPresented: $showOnboarding)
                    .transition(.opacity)
            } else {
                TabView(selection: $selectedTab) {
                    SpeechToTextView()
                        .tabItem {
                            Label(AppTab.speechToText.title, systemImage: AppTab.speechToText.icon)
                        }
                        .tag(AppTab.speechToText)

                    SignToSpeechView()
                        .tabItem {
                            Label(AppTab.signToSpeech.title, systemImage: AppTab.signToSpeech.icon)
                        }
                        .tag(AppTab.signToSpeech)

                    HistoryView()
                        .tabItem {
                            Label(AppTab.history.title, systemImage: AppTab.history.icon)
                        }
                        .tag(AppTab.history)

                    SettingsView()
                        .tabItem {
                            Label("Settings", systemImage: "gearshape")
                        }
                }
                .environment(appStore)
                .task { await appStore.checkPermissions() }
            }
        }
        .animation(.default, value: showOnboarding)
    }
}

// MARK: - History Tab

private struct HistoryView: View {
    @Environment(AppStore.self) private var appStore

    var body: some View {
        NavigationStack {
            Group {
                if appStore.conversationHistory.isEmpty {
                    ContentUnavailableView(
                        "No History",
                        systemImage: "clock.arrow.circlepath",
                        description: Text(
                            "Start transcribing or signing to build your conversation history."
                        )
                    )
                } else {
                    List(appStore.conversationHistory.reversed()) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(entry.role.label)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tint)
                                Spacer()
                                Text(entry.timestamp, style: .time)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Text(entry.message)
                                .font(.body)
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("History")
        }
    }
}

extension ConversationRole {
    fileprivate var label: String {
        switch self {
        case .userSigned: "You (Sign)"
        case .userSpoke: "You (Speech)"
        case .assistantSpoke: "Assistant"
        }
    }
}

// MARK: - Settings Tab

private struct SettingsView: View {
    @State private var hasSeenOnboarding = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: $hasSeenOnboarding) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Show Onboarding on Launch")
                                .font(.body)
                            Text("Replay the introduction screens next time you open the app")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onChange(of: hasSeenOnboarding) { _, newValue in
                        UserDefaults.standard.set(!newValue, forKey: "hasSeenOnboarding")
                    }
                } header: {
                    Text("General")
                }

                Section {
                    Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
                        Label("App Permissions", systemImage: "hand.raised.fill")
                    }
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("Camera, microphone, and speech recognition permissions can be changed in system Settings.")
                }

                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
