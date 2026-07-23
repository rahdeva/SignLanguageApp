//
//  SignVideoPlayerView.swift
//  SignLanguageApp
//
//  Created by Antigravity on 23/07/26.
//

import SwiftUI
import AVKit
import AVFoundation

struct SignVideoPlayerView: View {
    let word: String
    let englishWord: String
    @State private var player: AVPlayer?
    @State private var hasLocalVideo: Bool = false
    @State private var isPlaying: Bool = true
    @State private var pulseAnimation: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if hasLocalVideo, let player = player {
                    VideoPlayer(player: player)
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .onDisappear {
                            player.pause()
                        }
                } else {
                    // Fallback Animated Demonstration Video Card
                    fallbackVideoCard
                }
            }
        }
        .onAppear {
            setupPlayer()
        }
        .onChange(of: word) { _, _ in
            setupPlayer()
        }
    }

    private var fallbackVideoCard: some View {
        ZStack {
            // Background with rich gradient & subtle glass effect
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.85),
                            Color.indigo.opacity(0.95)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.blue.opacity(0.3), radius: 10, x: 0, y: 5)

            VStack(spacing: 14) {
                HStack {
                    Label("CONTOH ISYARAT VIDEO", systemImage: "play.rectangle.fill")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())

                    Spacer()

                    Image(systemName: "livephoto")
                        .foregroundColor(.cyan)
                        .font(.title3)
                }

                Spacer(minLength: 0)

                // Animated Gesture Video Icon
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 72, height: 72)
                        .scaleEffect(pulseAnimation ? 1.15 : 1.0)
                        .opacity(pulseAnimation ? 0.6 : 1.0)
                        .animation(
                            .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                            value: pulseAnimation
                        )

                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(spacing: 4) {
                    Text(word)
                        .font(.title.weight(.black))
                        .foregroundColor(.white)

                    if !englishWord.isEmpty && englishWord != word {
                        Text("(\(englishWord))")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }

                Spacer(minLength: 0)

                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption)
                    Text("Peragakan gerakan isyarat ini di depan kamera")
                        .font(.caption.weight(.medium))
                }
                .foregroundColor(.white.opacity(0.85))
            }
            .padding(18)
        }
        .frame(height: 220)
        .onAppear {
            pulseAnimation = true
        }
    }

    private func setupPlayer() {
        let cleanedName = word.lowercased().replacingOccurrences(of: " ", with: "_")
        let targetNorm = word.lowercased().replacingOccurrences(of: " ", with: "")
        var foundURL: URL? = nil

        // 1. Check App Bundle (Works on physical iPhones, iPad, and Simulator)
        if let url = Bundle.main.url(forResource: cleanedName, withExtension: "mp4") ??
                     Bundle.main.url(forResource: cleanedName, withExtension: "mp4", subdirectory: "SignVideos") ??
                     Bundle.main.url(forResource: word.lowercased(), withExtension: "mp4") {
            foundURL = url
        }

        // 2. Check SignLanguageApp/SignVideos local workspace folder
        if foundURL == nil {
            let localVideoPath = "/Users/fuadagussalim/Developer/C4/SignLanguageApp/SignLanguageApp/SignVideos/\(cleanedName).mp4"
            if FileManager.default.fileExists(atPath: localVideoPath) {
                foundURL = URL(fileURLWithPath: localVideoPath)
            }
        }

        // 3. Check archive-2 directory
        if foundURL == nil {
            let archivePath = "/Users/fuadagussalim/Developer/C4/SignLanguageApp/archive-2"
            let fm = FileManager.default
            if let subdirs = try? fm.contentsOfDirectory(atPath: archivePath) {
                for dir in subdirs {
                    let parts = dir.components(separatedBy: "_")
                    let rawGloss = parts.count > 1 ? parts.dropFirst().joined(separator: "_") : dir
                    let folderNorm = rawGloss.lowercased().replacingOccurrences(of: " ", with: "")

                    if folderNorm == targetNorm || dir.lowercased().contains(targetNorm) {
                        let folderPath = (archivePath as NSString).appendingPathComponent(dir)
                        if let files = try? fm.contentsOfDirectory(atPath: folderPath) {
                            if let videoFile = files.first(where: { $0.hasSuffix(".mp4") || $0.hasSuffix(".mov") }) {
                                let fullPath = (folderPath as NSString).appendingPathComponent(videoFile)
                                foundURL = URL(fileURLWithPath: fullPath)
                                break
                            }
                        }
                    }
                }
            }
        }

        if let url = foundURL {
            let newPlayer = AVPlayer(url: url)
            newPlayer.actionAtItemEnd = .none
            newPlayer.isMuted = true
            
            // Loop video playback
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: newPlayer.currentItem,
                queue: .main
            ) { [weak newPlayer] _ in
                newPlayer?.seek(to: .zero)
                newPlayer?.play()
            }
            
            self.player = newPlayer
            self.hasLocalVideo = true
            newPlayer.play()
        } else {
            self.hasLocalVideo = false
            self.player = nil
        }
    }
}
