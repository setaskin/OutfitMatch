//
//  ScanTheme.swift
//  OutfitMatch
//
//  Shared "Scan Line" visual system used across the whole app: a dark,
//  viewfinder/HUD-inspired palette that reflects what the app actually
//  does (a camera + on-device vision reading the photo), plus the two
//  bundled type families (Sora for display/UI, JetBrains Mono for
//  data-readout style labels).

import SwiftUI

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    static let scanBackground = Color(hex: 0x0B0E11)
    static let scanSurface = Color(hex: 0x12161A)
    static let scanSurfaceRaised = Color(hex: 0x181D22)
    static let scanInk = Color(hex: 0xF2F4F3)
    static let scanInkDim = Color(hex: 0x8B98A0)
    static let scanHairline = Color(hex: 0x2A3238)
    static let scanMint = Color(hex: 0x5EEAD4)
    static let scanAmber = Color(hex: 0xF5A623)
}

enum ScanFont {
    static func display(_ size: CGFloat, weight: DisplayWeight = .regular) -> Font {
        .custom(weight.postScriptName, size: size)
    }

    static func mono(_ size: CGFloat, medium: Bool = false) -> Font {
        .custom(medium ? "JetBrainsMonoRoman-Medium" : "JetBrainsMonoRoman-Regular", size: size)
    }

    enum DisplayWeight {
        case regular, semibold, bold

        var postScriptName: String {
            switch self {
            case .regular: return "Sora-Regular"
            case .semibold: return "Sora-SemiBold"
            case .bold: return "Sora-Bold"
            }
        }
    }
}
