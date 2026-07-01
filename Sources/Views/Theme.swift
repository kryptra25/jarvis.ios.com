import SwiftUI

/// Ported 1:1 from app/src/main/res/values/colors.xml in the Android project.
enum JarvisColor {
    static let bgPrimary        = Color(hex: 0x0A0E17)
    static let bgSecondary      = Color(hex: 0x111827)
    static let bubbleUser       = Color(hex: 0x1E3A5F)
    static let bubbleAI         = Color(hex: 0x151F2E)
    static let bgInput          = Color(hex: 0x1C2333)
    static let bgOfflineBanner  = Color(hex: 0x1A0A0A)

    static let accentBlue       = Color(hex: 0x4FC3F7)
    static let accentBlueDim    = Color(hex: 0x1565C0)

    static let textPrimary      = Color(hex: 0xE8EAF0)
    static let textSecondary    = Color(hex: 0x5A6478)

    static let statusListening  = Color(hex: 0x66BB6A)
    static let statusProcessing = Color(hex: 0xFFA726)
    static let statusSpeaking   = Color(hex: 0xAB47BC)
    static let statusSleeping   = Color(hex: 0x455A64)
    static let statusOffline    = Color(hex: 0xEF5350)
}

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
