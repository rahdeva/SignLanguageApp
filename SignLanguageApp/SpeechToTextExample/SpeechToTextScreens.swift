//
//  Screens.swift
//  SignLanguageApp
//
//  Home (live caption), Riwayat, Pengaturan, dan state penting
//  (izin, unduh model, sinyal rendah, error) — sesuai SignLanguage.dc.html.
//

import SwiftUI

// MARK: - HOME

struct HomeView: View {
    @Bindable var vm: CaptionViewModel

    var body: some View {
        let p = vm.palette
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                if vm.hasContent || vm.isListening {
                    CaptionStream(vm: vm)
                } else {
                    EmptyStateView(palette: p)
                }
                if vm.isLowSignal {
                    LowSignalBanner(palette: p)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            PrimaryActionButton(vm: vm)
                .padding(.top, 10)
                .padding(.bottom, 8)
        }
        .animation(.easeInOut(duration: 0.2), value: vm.isLowSignal)
    }
}

struct EmptyStateView: View {
    let palette: Palette

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle().fill(palette.accentSoft).frame(width: 96, height: 96)
                MicGlyph(color: palette.accent).frame(width: 44, height: 44)
            }
            Text("Ketuk untuk mulai")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(palette.ink)
            Text("Apa yang diucapkan akan muncul di sini dengan huruf besar.")
                .font(.system(size: 20))
                .foregroundStyle(palette.muted)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Aliran caption: baris final (solid) + partial (redup, italic, caret).
struct CaptionStream: View {
    @Bindable var vm: CaptionViewModel
    private let bottomID = "caption-bottom"

    var body: some View {
        let p = vm.palette
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(vm.transcript) { line in
                        Text(line.text)
                            .foregroundStyle(p.ink)
                    }
                    if !vm.partial.isEmpty {
                        PartialLine(text: vm.partial, palette: p)
                    }
                    Color.clear.frame(height: 1).id(bottomID)
                }
                .font(.system(size: vm.captionPointSize, weight: .semibold))
                .lineSpacing(vm.captionPointSize * 0.16)
                .tracking(-0.5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
            }
            .onChange(of: vm.transcript.count) { scrollToBottom(proxy) }
            .onChange(of: vm.partial) { scrollToBottom(proxy) }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(bottomID, anchor: .bottom)
        }
    }
}

/// Baris partial dengan caret berkedip.
struct PartialLine: View {
    let text: String
    let palette: Palette
    @State private var caretOn = true

    var body: some View {
        (
            Text(text).italic()
            + Text(" ")
        )
        .foregroundStyle(palette.partial)
        .fontWeight(.medium)
        .overlay(alignment: .bottomTrailing) {
            Caret(color: palette.accent, on: caretOn)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever()) { caretOn.toggle() }
        }
    }
}

struct Caret: View {
    let color: Color
    let on: Bool
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: 3, height: 34)
            .opacity(on ? 1 : 0)
            .offset(x: 8, y: -4)
    }
}

struct LowSignalBanner: View {
    let palette: Palette
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(palette.warning)
            Text("Suara belum jelas — dekatkan perangkat.")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(palette.ink)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Capsule().fill(palette.warningSoft))
        .padding(.horizontal, 20)
    }
}

// MARK: - RIWAYAT

struct HistoryView: View {
    @Bindable var vm: CaptionViewModel

    var body: some View {
        let p = vm.palette
        VStack(spacing: 0) {
            HStack {
                Text("Riwayat")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(p.ink)
                Spacer()
            }
            .padding(.horizontal, Metrics.screenMargin)
            .padding(.bottom, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    ForEach(vm.historyGroups) { group in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(group.label.uppercased())
                                .font(.system(size: 15, weight: .bold))
                                .tracking(1)
                                .foregroundStyle(p.partial)
                                .padding(.horizontal, 8)
                            ForEach(group.items) { item in
                                HistoryCard(item: item, palette: p)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }

            SubtleButton(title: "Kembali", palette: p) { vm.go(.home) }
                .padding(.horizontal, Metrics.screenMargin)
                .padding(.bottom, 8)
        }
    }
}

struct HistoryCard: View {
    let item: TranscriptLine
    let palette: Palette
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.timeLabel)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(palette.partial)
            Text(item.text)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(palette.ink)
                .lineSpacing(6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 18).fill(palette.card))
    }
}

// MARK: - PENGATURAN

struct SettingsView: View {
    @Bindable var vm: CaptionViewModel

    var body: some View {
        let p = vm.palette
        VStack(spacing: 0) {
            HStack {
                Text("Pengaturan")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(p.ink)
                Spacer()
            }
            .padding(.horizontal, Metrics.screenMargin)
            .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    fontSizeCard(p)
                    themeSection(p)
                    languageSection(p)
                    if let cap = vm.capability { diagnosticsCard(p, cap) }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }

            SubtleButton(title: "Selesai", palette: p) { vm.go(.home) }
                .padding(.horizontal, Metrics.screenMargin)
                .padding(.bottom, 8)
        }
    }

    private func fontSizeCard(_ p: Palette) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Ukuran teks").font(.system(size: 19, weight: .bold)).foregroundStyle(p.ink)
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(p.background)
                Text("Contoh teks")
                    .font(.system(size: 38 * vm.fontScale, weight: .bold))
                    .foregroundStyle(p.ink)
                    .padding(14)
            }
            .frame(minHeight: 96)
            HStack(spacing: 14) {
                Text("A").font(.system(size: 16, weight: .bold)).foregroundStyle(p.partial)
                Slider(value: $vm.fontScale, in: 0.75...1.5, step: 0.05)
                    .tint(p.accent)
                    .frame(minHeight: 34)
                Text("A").font(.system(size: 30, weight: .bold)).foregroundStyle(p.partial)
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: Metrics.cornerMedium).fill(p.card))
    }

    private func themeSection(_ p: Palette) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Tema", p)
            VStack(spacing: 0) {
                ForEach(Array(vm.availableThemes.enumerated()), id: \.element) { index, theme in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { vm.theme = theme }
                    } label: {
                        HStack(spacing: 14) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(theme.swatch)
                                .frame(width: 26, height: 26)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.black.opacity(0.1)))
                            Text(theme.label)
                                .font(.system(size: 19, weight: .semibold))
                                .foregroundStyle(p.ink)
                            Spacer()
                            if vm.theme == theme {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(p.accent)
                            }
                        }
                        .padding(.horizontal, 18)
                        .frame(minHeight: 62)
                    }
                    .buttonStyle(.plain)
                    if index < vm.availableThemes.count - 1 {
                        Divider().overlay(p.background)
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: Metrics.cornerMedium).fill(p.card))
        }
    }

    private func languageSection(_ p: Palette) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Bahasa", p)
            HStack {
                Text("Bahasa pengenalan").font(.system(size: 19, weight: .semibold)).foregroundStyle(p.ink)
                Spacer()
                Text("Indonesia").font(.system(size: 19, weight: .semibold)).foregroundStyle(p.partial)
            }
            .padding(.horizontal, 18)
            .frame(minHeight: 62)
            .background(RoundedRectangle(cornerRadius: Metrics.cornerMedium).fill(p.card))
        }
    }

    private func diagnosticsCard(_ p: Palette, _ cap: SpeechCapabilityReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Info teknis", p)
            VStack(alignment: .leading, spacing: 8) {
                infoRow("Engine", cap.chosenEngine, p)
                infoRow("On-device", cap.sfSupportsOnDevice ? "Ya (offline)" : "Tidak — perlu server", p)
                infoRow("id-ID di SpeechTranscriber", cap.analyzerSupportsLocale ? "Ya" : "Belum", p)
            }
            .padding(18)
            .background(RoundedRectangle(cornerRadius: Metrics.cornerMedium).fill(p.card))
        }
    }

    private func infoRow(_ key: String, _ value: String, _ p: Palette) -> some View {
        HStack(alignment: .top) {
            Text(key).font(.system(size: 15, weight: .semibold)).foregroundStyle(p.muted)
            Spacer()
            Text(value).font(.system(size: 15, weight: .semibold)).foregroundStyle(p.ink)
                .multilineTextAlignment(.trailing)
        }
    }

    private func sectionLabel(_ text: String, _ p: Palette) -> some View {
        Text(text.uppercased())
            .font(.system(size: 15, weight: .bold))
            .tracking(1)
            .foregroundStyle(p.partial)
            .padding(.horizontal, 8)
    }
}

// MARK: - State: izin

struct PermissionView: View {
    @Bindable var vm: CaptionViewModel

    var body: some View {
        let p = vm.palette
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle().fill(p.accentSoft).frame(width: 100, height: 100)
                MicGlyph(color: p.accent).frame(width: 48, height: 48)
            }
            Text("Izinkan mikrofon")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(p.ink)
                .multilineTextAlignment(.center)
            Text("SignLanguage butuh mikrofon untuk mengubah suara menjadi teks. Suara diproses di perangkat.")
                .font(.system(size: 21))
                .foregroundStyle(p.muted)
                .multilineTextAlignment(.center)
            Spacer()
            VStack(spacing: 12) {
                Button {
                    Task { await vm.requestPermissionAndStart() }
                } label: {
                    Text("Izinkan mikrofon")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(p.onAccent)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 72)
                        .background(RoundedRectangle(cornerRadius: 22).fill(p.accent))
                }
                .buttonStyle(.plain)
                Button {
                    vm.phase = .ready
                } label: {
                    Text("Nanti saja")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(p.muted)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: Metrics.minTap)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - State: error / berisik

struct ErrorStateView: View {
    @Bindable var vm: CaptionViewModel
    let message: String

    var body: some View {
        let p = vm.palette
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle().fill(p.warningSoft).frame(width: 100, height: 100)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(p.warning)
            }
            Text("Ada kendala")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(p.ink)
            Text(message)
                .font(.system(size: 21))
                .foregroundStyle(p.muted)
                .multilineTextAlignment(.center)
            Spacer()
            VStack(spacing: 12) {
                Button { Task { await vm.retryFromError() } } label: {
                    Text("Coba lagi")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(p.onAccent)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: Metrics.primaryButtonHeight)
                        .background(RoundedRectangle(cornerRadius: Metrics.cornerLarge).fill(p.accent))
                }
                .buttonStyle(.plain)
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Buka Pengaturan")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(p.muted)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: Metrics.minTap)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Tombol sekunder

struct SubtleButton: View {
    let title: String
    let palette: Palette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(palette.ink)
                .frame(maxWidth: .infinity)
                .frame(minHeight: Metrics.secondaryButtonHeight)
                .background(RoundedRectangle(cornerRadius: 22).fill(palette.subtleButton))
        }
        .buttonStyle(.plain)
    }
}
