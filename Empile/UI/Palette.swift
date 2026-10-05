import UIKit

/// The only place colors are defined. Each one adapts to light and dark mode.
/// SwiftUI uses them through `Color(uiColor:)`; the game scene resolves them for its current style.
enum Palette {
    static let skyTop = UIColor(light: UIColor(hex: 0xE6ECF4), dark: UIColor(hex: 0x0A0E17))
    static let skyBottom = UIColor(light: UIColor(hex: 0xF8F5EF), dark: UIColor(hex: 0x1A2030))
    static let platform = UIColor(light: UIColor(hex: 0x454B58), dark: UIColor(hex: 0x4D5566))
    static let pillar = UIColor(light: UIColor(hex: 0x6A7080), dark: UIColor(hex: 0x30374A))
    static let guide = UIColor.label
    static let shadow = UIColor(
        light: UIColor(hex: 0x1A2233, alpha: 0.3),
        dark: UIColor(hex: 0x000000, alpha: 0.6)
    )
    static let dust = UIColor(light: UIColor(hex: 0xB3AA9C), dark: UIColor(hex: 0x8F8A82))
    static let highlight = UIColor.white
    static let shade = UIColor.black
    static let stone = UIColor(light: UIColor(hex: 0x9A948B), dark: UIColor(hex: 0xA7A197))
    static let spring = UIColor(light: UIColor(hex: 0xE07A4F), dark: UIColor(hex: 0xEE8D62))
    /// See-through: the sky shows behind it.
    static let glass = UIColor(
        light: UIColor(hex: 0x8FCFE6, alpha: Tuning.Look.glassFillOpacity),
        dark: UIColor(hex: 0x7CC4DE, alpha: Tuning.Look.glassFillOpacity)
    )
    static let gold = UIColor(light: UIColor(hex: 0xE3B23C), dark: UIColor(hex: 0xEDC25A))
    /// Glass shards, more opaque than the block so they read as sparkles.
    static let shard = UIColor(light: UIColor(hex: 0xBFE6F3), dark: UIColor(hex: 0xA6DCEE))
    /// The game's accent, for buttons and highlights in the interface.
    /// Floating points: dark over the light sky, light over the night sky.
    static let scoreText = UIColor.label
    /// Perfect placements, combos and records: a warm, glowing gold.
    static let celebration = UIColor(light: UIColor(hex: 0xE89B0C), dark: UIColor(hex: 0xFFC94A))
    /// A small dark bird over the light sky, a pale one over the night sky.
    static let bird = UIColor(light: UIColor(hex: 0x3D4656), dark: UIColor(hex: 0xBAC4D4))
    static let beak = UIColor(light: UIColor(hex: 0xE8963A), dark: UIColor(hex: 0xF2AD55))
    /// Wind streaks: light enough to read as air, visible over the sky in both modes.
    static let wind = UIColor(light: UIColor(hex: 0x7F8BA0), dark: UIColor(hex: 0xC9D3E3))
    static let accent = UIColor(light: UIColor(hex: 0xD9683A), dark: UIColor(hex: 0xF08A5D))

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
