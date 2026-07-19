//
//  FeatureCard.swift
//  SignLanguageApp
//
//  Created by Cyintia Limmanto on 19/07/26.
//

import SwiftUI

struct FeatureCard: View {
    var title: String
    var subtitle: String
    var iconName: String
    var gradientColors: [Color]
    
    var body: some View {
        HStack(spacing: 20) {
            // Icon / Asset Area
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 70, height: 70)
                
                Image(systemName: iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 35, height: 35)
                    .foregroundColor(.white)
            }
            
            // Text Area
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(20)
        .background(
            LinearGradient(
                gradient: Gradient(colors: gradientColors),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(24)
        .shadow(color: gradientColors[0].opacity(0.3), radius: 15, x: 0, y: 10)
    }
}

#Preview {
    FeatureCard(title: "Sign to Speech", subtitle: "Turn your sign language skills into a voice assistant", iconName: "mouth", gradientColors: [AppStyle.Color.secondaryText, AppStyle.Color.accent])
}
