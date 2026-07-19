//
//  SeparatorLine.swift
//  StellaApp
//
//  Created by Antigravity on 17/07/26.
//

import SwiftUI

/// A horizontal separator line matching the layout specifications.
struct SeparatorLine: View {
    var color: Color = .secondary.opacity(0.2)
    var height: CGFloat = 1
    
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: height)
            .frame(maxWidth: .infinity)
    }
}

#Preview {
    VStack(spacing: 20) {
        Text("Above")
        SeparatorLine()
        Text("Below")
    }
    .padding()
}
