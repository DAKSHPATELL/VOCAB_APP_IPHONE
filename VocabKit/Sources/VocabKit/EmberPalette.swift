import SwiftUI

public extension Color {
    /// `Color(hex: 0xFF5A1F)`
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

/// The whole visual identity: near-black ground, ember reds and oranges on top.
/// Nothing else is allowed in — no blues, no greens, no neutral greys that are
/// not warm-tinted.
public enum Ember {

    // Ground — warm-tinted blacks rather than pure #000, which reads flat on OLED.
    public static let void = Color(hex: 0x05_03_04)
    public static let pitch = Color(hex: 0x0A_05_06)
    public static let ash = Color(hex: 0x12_09_09)
    public static let soot = Color(hex: 0x1C_0D_0C)

    // Fire
    public static let blood = Color(hex: 0xB0_14_14)
    public static let crimson = Color(hex: 0xE0_2A_18)
    public static let ember = Color(hex: 0xFF_4D_1C)
    public static let flame = Color(hex: 0xFF_6A_1F)
    public static let orange = Color(hex: 0xFF_8A_28)
    public static let amber = Color(hex: 0xFF_A9_3D)
    public static let gold = Color(hex: 0xFF_C7_6B)

    // Type
    public static let bone = Color(hex: 0xF6_EC_E6)
    public static let smoke = Color(hex: 0xC9_B3_A8)
    public static let dust = Color(hex: 0x8A_75_6C)

    /// The signature gradient used for the headword itself.
    public static let headline = LinearGradient(
        colors: [gold, orange, ember, crimson],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    public static let hairline = LinearGradient(
        colors: [.clear, ember.opacity(0.85), orange.opacity(0.35), .clear],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Gender is colour-coded, but every colour stays inside the red/orange family.
    public static func accent(for entry: VocabEntry) -> Color {
        switch entry.gender {
        case .masculine: orange     // der
        case .feminine: crimson     // die
        case .neuter: amber         // das
        case nil: flame
        }
    }

    public static func accentGradient(for entry: VocabEntry) -> LinearGradient {
        let base = accent(for: entry)
        return LinearGradient(
            colors: [gold.opacity(0.95), base, base.opacity(0.75)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
