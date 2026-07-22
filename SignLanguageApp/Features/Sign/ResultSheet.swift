//
//  ResultSheet.swift
//  SignLanguageApp
//
//  Created by Cyintia Limmanto on 22/07/26.
//  Refactored by Antigravity with live button callbacks & dynamic statistics.
//

import SwiftUI

struct ResultSheet: View {
    var currentChallenge: PracticeChallenge
    var resultIcon: String
    var resultColor: Color
    var resultTitle: String
    var resultDesc: String
    var completedCount: Int
    var durationSeconds: Int
    var onPlayAgain: () -> Void
    var onSaveToHistory: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    private var accuracyText: String {
        guard !currentChallenge.targetTokens.isEmpty else { return "0%" }
        let ratio = Double(completedCount) / Double(currentChallenge.targetTokens.count)
        return "\(Int(ratio * 100))%"
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
            
            Image(systemName: resultIcon)
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(resultColor)
                .padding(.top, 4)
            
            Text(resultTitle)
                .font(.title2)
                .fontWeight(.heavy)
                .foregroundStyle(.primary)
            
            Text(resultDesc)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("PERTANYAAN & TARGET")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fontWeight(.bold)
                
                Text("\"\(currentChallenge.question)\"")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(0..<currentChallenge.targetTokens.count, id: \.self) { idx in
                            let token = currentChallenge.targetTokens[idx]
                            let isCaptured = idx < completedCount
                            
                            ResultChip(
                                text: token,
                                isDetected: isCaptured,
                                showsCheckmark: isCaptured
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(20)
            
            HStack(spacing: 12) {
                StatBox(value: "\(completedCount)/\(currentChallenge.targetTokens.count)", label: "Kata benar")
                StatBox(value: accuracyText, label: "Akurasi")
                StatBox(value: "\(durationSeconds)s", label: "Waktu")
            }
            
            Spacer(minLength: 12)
            
            VStack(spacing: 12) {
                // Primary Button: Main Lagi
                Button(action: {
                    dismiss()
                    onPlayAgain()
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Main Lagi")
                    }
                    .font(.headline)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color("TealColor"))
                    .cornerRadius(16)
                }
                .buttonStyle(.plain)
                
                // Secondary Button: Simpan ke Riwayat
                Button(action: {
                    dismiss()
                    onSaveToHistory()
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.down.fill")
                        Text("Simpan ke Riwayat")
                    }
                    .font(.headline)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(UIColor.tertiarySystemGroupedBackground))
                    .cornerRadius(16)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 16)
        }
        .padding(.horizontal, 20)
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
    }
}

private struct ResultChip: View {
    let text: String
    let isDetected: Bool
    let showsCheckmark: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            if showsCheckmark {
                Image(systemName: "checkmark")
                    .font(.caption.bold())
                    .foregroundColor(.green)
            }
            Text(text)
                .font(.caption.weight(.bold))
                .foregroundColor(isDetected ? .green : .secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isDetected ? Color.green.opacity(0.15) : Color.primary.opacity(0.06))
        .cornerRadius(12)
    }
}

private struct StatBox: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}
