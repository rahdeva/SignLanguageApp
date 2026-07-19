//
//  HomeView.swift
//  SignLanguageApp
//
//  Created by Cyintia Limmanto on 19/07/26.
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Welcome Header
                    VStack(alignment: .leading, spacing: 8) {

                        Text("How would you like to communicate today?")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    // Main Feature Cards
                    VStack(spacing: 20) {
                        
                        // FEATURE 1: Sign to Speech
                        NavigationLink(destination: SignToSpeechView()) {
                            FeatureCard(
                                title: "Sign to Speech",
                                subtitle: "Translate sign language into spoken words.",
                                iconName: "hand.raised.fill",
                                gradientColors: [Color.blue, Color.cyan]
                            )
                        }
                        
                        // FEATURE 2: Speech to Text
                        NavigationLink(destination: SpeechToTextView()) {
                            FeatureCard(
                                title: "Speech to Text",
                                subtitle: "Transcribe spoken words for you to read.",
                                iconName: "waveform.circle.fill",
                                gradientColors: [Color.teal, Color.mint]
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 40)
            }
            .navigationTitle("SigningOut")
            .background(Color(UIColor.systemGroupedBackground).edgesIgnoringSafeArea(.all))
        }
        .tint(.primary)
    }
}

#Preview {
    HomeView()
}
