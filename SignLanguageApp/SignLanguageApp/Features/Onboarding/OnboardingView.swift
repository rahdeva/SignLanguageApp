//
//  OnboardingView.swift
//  SignLanguageApp
//
//  Created by Muhammad Hisyam Kamil on 17/07/26.
//

import SwiftUI

/// Full-screen onboarding shown on first launch. Accessible again from Settings.
struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0

    private let pages = OnboardingPage.samples
    private var isLastPage: Bool { currentPage == pages.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            // Paged content
            TabView(selection: $currentPage) {
                ForEach(pages.indices, id: \.self) { index in
                    pageCard(pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .animation(.default, value: currentPage)

            // Footer
            VStack(spacing: 16) {
                // Main action: Next → Get Started
                Button {
                    if isLastPage {
                        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                        isPresented = false
                    } else {
                        withAnimation { currentPage += 1 }
                    }
                } label: {
                    Text(isLastPage ? "Get Started" : "Next")
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)

                // Info about replaying via Settings
                Text("You can replay this anytime in Settings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 40)
            .padding(.top, 16)
        }
    }

    @ViewBuilder
    private func pageCard(_ page: OnboardingPage) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: page.icon)
                .font(.system(size: 72))
                .foregroundStyle(.tint)
                .symbolEffect(.bounce, options: .repeating)

            Text(page.title)
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)

            Text(page.subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
        .padding()
    }
}

// MARK: - Page Model

private struct OnboardingPage {
    let icon: String
    let title: String
    let subtitle: String

    static let samples: [OnboardingPage] = [
        OnboardingPage(
            icon: "waveform",
            title: "Speech to Text",
            subtitle: "Tap the microphone and start speaking. Your words appear on screen in real time."
        ),
        OnboardingPage(
            icon: "camera.fill",
            title: "Sign to Speech",
            subtitle: "Point your camera at sign language gestures. The app translates them into spoken words."
        ),
        OnboardingPage(
            icon: "clock.arrow.circlepath",
            title: "Conversation History",
            subtitle: "Every translation is saved so you can review, replay, or share past conversations."
        ),
    ]
}

#Preview {
    OnboardingView(isPresented: .constant(true))
}
