//
//  SpeechToTextExampleView.swift
//  SignLanguageApp
//
//  Root view fitur Speech-to-Text Example.
//  Panggil dari ContentView untuk mencoba:
//
//      struct ContentView: View {
//          var body: some View {
//              SpeechToTextExampleView()
//          }
//      }
//

import SwiftUI

/// Root view fitur Speech-to-Text — layar utama live caption.
///
/// Menampilkan seluruh antarmuka transkripsi real-time: izin, caption,
/// riwayat, pengaturan, dan state error/download. Implementasi ini
/// mengambil alih seluruh layar dan menyediakan navigasi internal.
///
/// Tidak ada:
/// - Language selection
/// - Model download screen
/// - "Menyiapkan Bahasa Indonesia"
///
/// Bahasa Indonesia (id-ID) dikonfigurasi otomatis.
///
/// # Cara pakai
/// ```swift
/// struct ContentView: View {
///     var body: some View {
///         SpeechToTextExampleView()
///     }
/// }
/// ```
public struct SpeechToTextExampleView: View {
    @State private var vm = CaptionViewModel()

    public init() {}

    public var body: some View {
        let p = vm.palette
        ZStack {
            p.background.ignoresSafeArea()
            content
        }
        .tint(p.accent)
        .preferredColorScheme(vm.theme.colorScheme)
        .task { await vm.bootstrap() }
        .animation(.easeInOut(duration: 0.25), value: vm.screen)
        .animation(.easeInOut(duration: 0.25), value: vm.isListening)
    }

    @ViewBuilder
    private var content: some View {
        switch vm.phase {
        case .permission:
            PermissionView(vm: vm)
        case .preparing:
            PreparingView(palette: vm.palette)
        case .ready:
            MainScaffold(vm: vm)
        case .error(let message):
            ErrorStateView(vm: vm, message: message)
        }
    }
}

// MARK: - Scaffold utama (Home / Riwayat / Pengaturan)

struct MainScaffold: View {
    @Bindable var vm: CaptionViewModel

    var body: some View {
        VStack(spacing: 0) {
            TopBar(vm: vm)
            switch vm.screen {
            case .home:
                HomeView(vm: vm)
            case .history:
                HistoryView(vm: vm)
            case .settings:
                SettingsView(vm: vm)
            }
        }
    }
}

// MARK: - Top bar

struct TopBar: View {
    @Bindable var vm: CaptionViewModel

    var body: some View {
        let p = vm.palette
        HStack {
            if vm.screen == .home {
                TextBarButton(title: "Riwayat", palette: p) { vm.go(.history) }
            } else {
                Color.clear.frame(width: Metrics.minTap, height: Metrics.minTap)
            }
            Spacer()
            if vm.isListening {
                ListeningPill(palette: p)
                    .transition(.opacity.combined(with: .scale))
            }
            Spacer()
            if vm.screen == .home {
                TextBarButton(title: "Pengaturan", palette: p) { vm.go(.settings) }
            } else {
                Color.clear.frame(width: Metrics.minTap, height: Metrics.minTap)
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: Metrics.minTap)
        .padding(.top, 6)
    }
}

struct TextBarButton: View {
    let title: String
    let palette: Palette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(palette.accent)
                .frame(minWidth: Metrics.minTap, minHeight: Metrics.minTap)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Listening pill

struct ListeningPill: View {
    let palette: Palette
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 9) {
            Circle()
                .fill(palette.accent)
                .frame(width: 11, height: 11)
                .scaleEffect(pulse ? 1.5 : 1)
                .opacity(pulse ? 0.35 : 1)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)
            Text("Mendengarkan")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(palette.accentSoftInk)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 8)
        .background(Capsule().fill(palette.accentSoft))
        .onAppear { pulse = true }
    }
}

// MARK: - Tombol utama full-width

struct PrimaryActionButton: View {
    let vm: CaptionViewModel

    var body: some View {
        let p = vm.palette
        Button {
            Task { await vm.toggle() }
        } label: {
            HStack(spacing: 12) {
                if vm.isListening {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(p.onAccent)
                        .frame(width: 20, height: 20)
                    Text("Berhenti")
                } else {
                    MicGlyph(color: p.onAccent)
                        .frame(width: 24, height: 24)
                    Text("Mulai mendengarkan")
                }
            }
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(p.onAccent)
            .frame(maxWidth: .infinity)
            .frame(minHeight: Metrics.primaryButtonHeight)
            .background(
                RoundedRectangle(cornerRadius: Metrics.cornerLarge)
                    .fill(vm.isListening ? p.danger : p.accent)
            )
            .shadow(color: p.accent.opacity(0.28), radius: 11, y: 8)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Metrics.screenMargin)
    }
}

// MARK: - Ikon mic

struct MicGlyph: View {
    var color: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Capsule()
                    .fill(color)
                    .frame(width: w * 0.34, height: h * 0.52)
                    .position(x: w / 2, y: h * 0.34)
                Path { path in
                    path.addArc(center: CGPoint(x: w / 2, y: h * 0.42),
                                radius: w * 0.34,
                                startAngle: .degrees(20),
                                endAngle: .degrees(160),
                                clockwise: false)
                }
                .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                Rectangle()
                    .fill(color)
                    .frame(width: 2, height: h * 0.18)
                    .position(x: w / 2, y: h * 0.82)
            }
        }
    }
}

// MARK: - Preparing

struct PreparingView: View {
    let palette: Palette

    var body: some View {
        VStack(spacing: 18) {
            ProgressView()
                .controlSize(.large)
                .tint(palette.accent)
            Text("Menyiapkan…")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(palette.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.background)
    }
}

#Preview {
    SpeechToTextExampleView()
}
