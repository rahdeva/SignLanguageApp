//
//  Theme.swift
//  SignLanguageApp
//
//  Design tokens dari SignLanguage.dc.html — warm neutral paper, satu accent teal.
//  Semua warna hangat (bukan putih klinis). Caption besar, kontras tinggi.
//

import SwiftUI

// MARK: - Tema

/// Tiga tema sesuai layar Pengaturan pada desain.
enum AppTheme: String, CaseIterable, Identifiable, Codable {
    case light     // Terang  — kertas hangat
    case dark      // Gelap   — near-black hangat
    case contrast  // Kontras tinggi — hitam murni / putih murni

    var id: String { rawValue }

    var label: String {
        switch self {
        case .light: return "Terang"
        case .dark: return "Gelap"
        case .contrast: return "Kontras tinggi"
        }
    }

    /// Warna swatch untuk baris pemilih tema di Pengaturan.
    var swatch: Color {
        switch self {
        case .light: return Palette.paperLight
        case .dark: return Palette.paperDark
        case .contrast: return .black
        }
    }

    /// Pemetaan ke skema warna sistem (agar kontrol native ikut menyesuaikan).
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark, .contrast: return .dark
        }
    }
}

// MARK: - Palette

/// Palet yang menghasilkan warna sesuai tema aktif. Nilai diambil langsung
/// dari komentar warna di file desain.
struct Palette {
    let theme: AppTheme

    // Nilai mentah (dipakai juga oleh swatch statis).
    static let paperLight = Color(hex: 0xF6F2EA)
    static let paperDark = Color(hex: 0x14110D)
    static let inkLight = Color(hex: 0x241F1A)
    static let inkDark = Color(hex: 0xF4EEE4)
    static let tealLight = Color(hex: 0x2F8F86)
    static let tealDark = Color(hex: 0x66C2B7)

    /// Latar layar.
    var background: Color {
        switch theme {
        case .light: return Self.paperLight
        case .dark: return Self.paperDark
        case .contrast: return .black
        }
    }

    /// Kartu (riwayat, pengaturan).
    var card: Color {
        switch theme {
        case .light: return .white
        case .dark: return Color(hex: 0x211C16)
        case .contrast: return Color(hex: 0x121212)
        }
    }

    /// Teks utama / caption final (solid).
    var ink: Color {
        switch theme {
        case .light: return Self.inkLight
        case .dark: return Self.inkDark
        case .contrast: return .white
        }
    }

    /// Teks sekunder.
    var muted: Color {
        switch theme {
        case .light: return Color(hex: 0x6F665A)
        case .dark: return Color(hex: 0xA79E90)
        case .contrast: return Color(hex: 0xCCCCCC)
        }
    }

    /// Caption partial (volatile) — redup + italic.
    var partial: Color {
        switch theme {
        case .light: return Color(hex: 0x9A9081)
        case .dark: return Color(hex: 0x7C7367)
        case .contrast: return Color(hex: 0x9E9E9E)
        }
    }

    /// Accent teal (tombol mulai, dot, caret).
    var accent: Color {
        switch theme {
        case .light: return Self.tealLight
        case .dark, .contrast: return Self.tealDark
        }
    }

    /// Chip "Mendengarkan".
    var accentSoft: Color {
        switch theme {
        case .light: return Color(hex: 0xE4F0EE)
        case .dark, .contrast: return Color(hex: 0x66C2B7).opacity(0.16)
        }
    }

    var accentSoftInk: Color {
        switch theme {
        case .light: return Color(hex: 0x247068)
        case .dark, .contrast: return Color(hex: 0x8FD6CD)
        }
    }

    /// Tombol berhenti (merah bata hangat).
    var danger: Color { Color(hex: 0xD64C3F) }

    /// Warna teks di atas tombol accent.
    var onAccent: Color {
        theme == .contrast || theme == .dark ? Color(hex: 0x0B0906) : .white
    }

    /// Tombol sekunder (Kembali / Selesai).
    var subtleButton: Color {
        switch theme {
        case .light: return Color(hex: 0xEDE7DB)
        case .dark: return Color(hex: 0x2C271F)
        case .contrast: return Color(hex: 0x1E1E1E)
        }
    }

    var warning: Color { Color(hex: 0xC98A2B) }
    var warningSoft: Color { Color(hex: 0xFBEBD6) }
}

// MARK: - Ukuran & aksesibilitas

enum Metrics {
    /// Tap target minimum sesuai desain (≥ 60pt).
    static let minTap: CGFloat = 60
    /// Tombol utama full-width.
    static let primaryButtonHeight: CGFloat = 76
    static let secondaryButtonHeight: CGFloat = 68
    static let screenMargin: CGFloat = 24
    /// Ukuran caption dasar (44pt) — dikalikan fontScale (0.75–1.5).
    static let baseCaptionSize: CGFloat = 44
    static let cornerLarge: CGFloat = 24
    static let cornerMedium: CGFloat = 20
}

// MARK: - Color(hex:)

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
