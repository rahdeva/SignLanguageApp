//
//  SplashView.swift
//  SignLanguageApp
//
//  Created by Antigravity on 22/07/26.
//

import SwiftUI

struct SplashView: View {
    
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0.0

    private var backgroundColor: Color {
        if colorScheme == .dark {
            return Color(red: 14.0 / 255.0, green: 19.0 / 255.0, blue: 34.0 / 255.0)
        } else {
            return Color(uiColor: .systemBackground)
        }
    }
    
    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image("AppLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 240, height: 240)
                    .scaleEffect(scale)
                    .opacity(opacity)
                
//                Text("Stella")
//                    .font(.system(.title2, design: .rounded).weight(.semibold))
//                    .foregroundColor(.primary)
//                    .opacity(opacity)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}

#Preview {
    SplashView()
}
