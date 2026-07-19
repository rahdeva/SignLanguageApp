//
//  FeatureCard.swift
//  SignLanguageApp
//
//  Created by Cyintia Limmanto on 19/07/26.
//

import SwiftUI
import UIKit

struct FeatureCard: View {
    var title: String
    var description: String
    var characterAsset: String
    var cardColor: Color
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            cardColor

            characterImage
                .resizable()
                .scaledToFill()
                .frame(
                    width: AppStyle.Layout.featureCardCharacterWidth,
                    height: AppStyle.Layout.featureCardCharacterHeight,
                    alignment: .bottomTrailing
                )
                .scaleEffect(
                    AppStyle.Layout.featureCardCharacterScale,
                    anchor: .bottomTrailing
                )

            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.primary.opacity(0.85))
                        .lineSpacing(4)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.trailing, AppStyle.Layout.featureCardTextTrailingSpace)
                .padding(.bottom, AppStyle.Layout.featureCardButtonBottomPadding)

                Spacer(minLength: 0)

                HStack {
                    Text("Begin")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Image(systemName: "arrow.right.circle.fill")
                        .imageScale(.large)
                }
                .foregroundColor(.accentColor)
                .padding(.horizontal, AppStyle.Layout.featureCardButtonHorizontalPadding)
                .padding(.vertical, AppStyle.Layout.featureCardButtonVerticalPadding)
                .background(Color(UIColor.systemBackground))
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(AppStyle.Layout.featureCardContentInset)
        }
        .frame(maxWidth: .infinity, minHeight: AppStyle.Layout.featureCardHeight)
        .clipShape(RoundedRectangle(cornerRadius: AppStyle.Layout.featureCardCornerRadius, style: .continuous))
    }

    private var characterImage: Image {
        if UIImage(named: characterAsset) != nil {
            Image(characterAsset)
        } else {
            Image(systemName: characterAsset)
        }
    }
}

#Preview {
    FeatureCard(
        title: "Sign to Speech",
        description: "Lorem ipsum dolor sit amet, consectetur adipiscing elit.",
        characterAsset: "person_signing",
        cardColor: Color("CardColor1")
    )
}
