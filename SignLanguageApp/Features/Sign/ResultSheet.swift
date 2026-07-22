//
//  ResultSheet.swift
//  SignLanguageApp
//
//  Created by Cyintia Limmanto on 22/07/26.
//

import SwiftUI

struct ResultSheet: View {
    
    var currentChallenge: PracticeChallenge
    var resultIcon: String
    var resultColor: Color
    var resultTitle: String
    var resultDesc: String
    
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: resultIcon)
                .resizable()
                .scaledToFit()
                .frame(width: 102, height: 95)
                .foregroundColor(resultColor)
            
            Text(resultTitle)
                .font(.largeTitle)
                .fontWeight(.heavy)
                .foregroundStyle(.primary)
            
            Text(resultDesc)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("KALIMAT KAMU")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text("\"Saya naik motor\"")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 10) {
                    ForEach(0..<currentChallenge.targetTokens.count, id: \.self) { idx in
                        let token = currentChallenge.targetTokens[idx]
                        let isCaptured: Bool = true
                        
                        ResultChip(
                            text: token,
                            isDetected: isCaptured,
                            showsCheckmark: isCaptured
                        )
                    }
                }
                .padding(.vertical, 2)
                
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(20)
            
            HStack(spacing: 12) {
                StatBox(value: "3/3", label: "Kata benar")
                StatBox(value: "100%", label: "Akurasi")
                StatBox(value: "12s", label: "Waktu")
            }
            
            Spacer()
            
            VStack(spacing: 12) {
                // Primary Button
                Button(action: {
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Main Lagi")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color("TealColor"))
                    .cornerRadius(16)
                }
                
                // Secondary Button
                Button(action: {
                    // Action for Simpan ke Riwayat
                }) {
                    Text("Simpan ke Riwayat")
                        .font(.headline)
                        .foregroundColor(Color("TealColor"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(16)
                }
            }
            .padding(.bottom, 20)
        }
    }
}

struct ResultChip : View {
    let text: String
    var isDetected: Bool = true
    var showsCheckmark: Bool = true
    
    var body: some View {
        HStack(spacing: 4) {
            if showsCheckmark {
                Image(systemName: "checkmark")
                    .foregroundColor(isDetected ? .green : .red)
                    .font(.caption.bold())
            } else {
                Image(systemName: "multiply")
                    .foregroundColor(isDetected ? .green : .red)
                    .font(.caption.bold())
            }
            
            Text(text)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(isDetected ? .green : .blue)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isDetected ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
        .cornerRadius(12)
    }
}

struct StatBox: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
    }
}

#Preview {
    //    ResultSheet()
}
