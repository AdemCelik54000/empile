import UIKit

/// The only place colors are defined. Each one adapts to light and dark mode.
/// SwiftUI uses them through `Color(uiColor:)`; the game scene resolves them for its current style.
enum Palette {
    static let skyTop = UIColor(light: UIColor(hex: 0xA9D8FF), dark: UIColor(hex: 0x0B0A2A))
    static let skyBottom = UIColor(light: UIColor(hex: 0xFFE1F0), dark: UIColor(hex: 0x3B1E63))
    /// The sky as the score climbs: the first pair is the starting sky, then a new one every few thousand points.
    static let skies: [(top: UIColor, bottom: UIColor)] = [
        (skyTop, skyBottom),
        (UIColor(light: UIColor(hex: 0xFFC796), dark: UIColor(hex: 0x1E0B2E)),
         UIColor(light: UIColor(hex: 0xFF9FC4), dark: UIColor(hex: 0x7A2E5A))),
        (UIColor(light: UIColor(hex: 0xC8B8FF), dark: UIColor(hex: 0x120A33)),
         UIColor(light: UIColor(hex: 0xFFD6EC), dark: UIColor(hex: 0x4A2E8F))),
        (UIColor(light: UIColor(hex: 0x8FA8FF), dark: UIColor(hex: 0x060B2E)),
         UIColor(light: UIColor(hex: 0xE0D4FF), dark: UIColor(hex: 0x1F3A8A))),
        (UIColor(light: UIColor(hex: 0xFFE59A), dark: UIColor(hex: 0x1F1408)),
         UIColor(light: UIColor(hex: 0xFFC1A1), dark: UIColor(hex: 0x6E3B14))),
    ]
    static let platform = UIColor(light: UIColor(hex: 0x3D3A8C), dark: UIColor(hex: 0x5A4FB8))
    static let pillar = UIColor(light: UIColor(hex: 0x7A74D6), dark: UIColor(hex: 0x2C2466))
    static let guide = UIColor.label
    static let shadow = UIColor(
        light: UIColor(hex: 0x1A2233, alpha: 0.3),
        dark: UIColor(hex: 0x000000, alpha: 0.6)
    )
    static let dust = UIColor(light: UIColor(hex: 0xC7B5F0), dark: UIColor(hex: 0x9E8AD6))
    static let highlight = UIColor.white
    static let shade = UIColor.black
    static let stone = UIColor(light: UIColor(hex: 0x3FC1A5), dark: UIColor(hex: 0x52D6BA))
    static let spring = UIColor(light: UIColor(hex: 0xFF5FA2), dark: UIColor(hex: 0xFF7AB6))
    /// See-through: the sky shows behind it.
    static let glass = UIColor(
        light: UIColor(hex: 0x8FCFE6, alpha: Tuning.Look.glassFillOpacity),
        dark: UIColor(hex: 0x7CC4DE, alpha: Tuning.Look.glassFillOpacity)
    )
    static let gold = UIColor(light: UIColor(hex: 0xE3B23C), dark: UIColor(hex: 0xEDC25A))
    /// Glass shards, more opaque than the block so they read as sparkles.
    static let shard = UIColor(light: UIColor(hex: 0xBFE6F3), dark: UIColor(hex: 0xA6DCEE))
    /// Floating points: dark over the light sky, light over the night sky.
    static let scoreText = UIColor.label
    /// Perfect placements, combos and records: a warm, glowing gold.
    static let celebration = UIColor(light: UIColor(hex: 0xE89B0C), dark: UIColor(hex: 0xFFC94A))
    /// A small dark bird over the light sky, a pale one over the night sky.
    static let bird = UIColor(light: UIColor(hex: 0x3D4656), dark: UIColor(hex: 0xBAC4D4))
    static let beak = UIColor(light: UIColor(hex: 0xE8963A), dark: UIColor(hex: 0xF2AD55))
    /// Motes drifting in the sky: pearly over the day sky, warm starlight over the night sky.
    static let mote = UIColor(light: UIColor(hex: 0xFFFFFF), dark: UIColor(hex: 0xFFE59E))
    /// Wind streaks: light enough to read as air, visible over the sky in both modes.
    static let wind = UIColor(light: UIColor(hex: 0x5E7FD6), dark: UIColor(hex: 0xCFDCFF))
    /// The game's accent, for buttons and highlights in the interface: a bright blue.
    static let accent = UIColor(light: UIColor(hex: 0x2F6BFF), dark: UIColor(hex: 0x5C8DFF))

    static func base(of kind: BlockKind) -> UIColor {
        switch kind {
        case .stone: stone
        case .spring: spring
        case .glass: glass
        case .gold: gold
        }
    }
}

extension UIColor {
    convenience init(light: UIColor, dark: UIColor) {
        self.init { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        }
    }

    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        let channel = { (shift: UInt32) in CGFloat((hex >> shift) & 0xFF) / 255 }
        self.init(red: channel(16), green: channel(8), blue: channel(0), alpha: alpha)
    }

    /// Same hue and brightness with less color: 0 keeps it, 1 makes it grey.
    func desaturated(by amount: CGFloat) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        guard getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else { return self }
        return UIColor(hue: hue, saturation: saturation * (1 - amount.clamped(to: 0...1)), brightness: brightness, alpha: alpha)
    }

    /// Same hue, brighter (positive amount) or darker (negative amount).
    func adjustingBrightness(by amount: CGFloat) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        guard getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else { return self }
        return UIColor(hue: hue, saturation: saturation, brightness: (brightness + amount).clamped(to: 0...1), alpha: alpha)
    }
}
