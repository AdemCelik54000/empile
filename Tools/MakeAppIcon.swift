// Draws Empile's app icon: a small tower (stone, spring, glass, tilted stone) on a deep night-blue sky.
// Usage: swift Tools/MakeAppIcon.swift Empile/Assets.xcassets/AppIcon.appiconset/AppIcon.png
import AppKit

let side: CGFloat = 1024
let unit: CGFloat = 132
let corner = unit * 0.2

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func shade(_ base: NSColor, _ amount: CGFloat) -> NSColor {
    var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
    base.usingColorSpace(.sRGB)?.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
    return NSColor(hue: hue, saturation: saturation, brightness: min(max(brightness + amount, 0), 1), alpha: alpha)
}

func gradient(_ rect: CGRect, _ top: NSColor, _ bottom: NSColor) {
    NSGradient(starting: bottom, ending: top)?.draw(in: rect, angle: 90)
}

/// A rounded block with a soft shadow, a vertical gradient, a bevel and a pattern. `rect` is in AppKit
/// coordinates (origin bottom-left).
func block(_ rect: CGRect, base: NSColor, rotation: CGFloat = 0, pattern: (CGRect) -> Void) {
    guard let context = NSGraphicsContext.current?.cgContext else { return }
    context.saveGState()
    context.translateBy(x: rect.midX, y: rect.midY)
    context.rotate(by: rotation)
    let local = CGRect(x: -rect.width / 2, y: -rect.height / 2, width: rect.width, height: rect.height)
    let outline = NSBezierPath(roundedRect: local, xRadius: corner, yRadius: corner)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -10), blur: 26, color: NSColor.black.withAlphaComponent(0.45).cgColor)
    base.setFill()
    outline.fill()
    context.restoreGState()
    context.saveGState()
    outline.addClip()
    gradient(local, shade(base, 0.08), shade(base, -0.08))
    pattern(local)
    NSColor.white.withAlphaComponent(0.3).setFill()
    NSRect(x: local.minX, y: local.maxY - 6, width: local.width, height: 6).fill()
    NSColor.black.withAlphaComponent(0.14).setFill()
    NSRect(x: local.minX, y: local.minY, width: local.width, height: 6).fill()
    context.restoreGState()
    shade(base, -0.25).setStroke()
    let edge = NSBezierPath(roundedRect: local.insetBy(dx: 2, dy: 2), xRadius: corner - 2, yRadius: corner - 2)
    edge.lineWidth = 4
    edge.stroke()
    context.restoreGState()
}

func speckles(_ rect: CGRect, seed: Int) {
    var state = UInt64(seed)
    func random() -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat(state >> 33) / CGFloat(UInt32.max >> 1)
    }
    for _ in 0..<Int(rect.width * rect.height / 900) {
        let radius = 3 + random() * 5
        let point = CGPoint(x: rect.minX + 10 + random() * (rect.width - 20), y: rect.minY + 10 + random() * (rect.height - 20))
        (random() > 0.5 ? NSColor.white.withAlphaComponent(0.25) : NSColor.black.withAlphaComponent(0.18)).setFill()
        NSBezierPath(ovalIn: CGRect(x: point.x - radius, y: point.y - radius, width: 2 * radius, height: 2 * radius)).fill()
    }
}

// Exactly 1024 × 1024 pixels (not scaled for the Mac's Retina screen).
guard let canvas = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(side), pixelsHigh: Int(side), bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
), let drawing = NSGraphicsContext(bitmapImageRep: canvas) else { fatalError("Could not create the canvas") }
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = drawing
gradient(CGRect(x: 0, y: 0, width: side, height: side), color(0x1E2740), color(0x0B0F1C))

let stone = color(0xA7A197)
let platformTop: CGFloat = 268
let platform = CGRect(x: (side - 5 * unit) / 2, y: platformTop - 58, width: 5 * unit, height: 58)
let platformPath = NSBezierPath(roundedRect: platform, xRadius: 20, yRadius: 20)
NSGraphicsContext.current?.saveGraphicsState()
platformPath.addClip()
gradient(platform, color(0x5C6578), color(0x3F4657))
NSGraphicsContext.current?.restoreGraphicsState()

func row(_ index: CGFloat, columns: CGFloat) -> CGRect {
    CGRect(x: (side - columns * unit) / 2, y: platformTop + index * unit, width: columns * unit, height: unit)
}

block(row(0, columns: 3), base: stone) { speckles($0, seed: 7) }
block(row(1, columns: 2), base: color(0xEE8D62)) { rect in
    let path = NSBezierPath()
    let segments = 10
    for index in 0...segments {
        let x = rect.minX + 16 + (rect.width - 32) * CGFloat(index) / CGFloat(segments)
        let y = rect.midY + (index.isMultiple(of: 2) ? 1 : -1) * rect.height * 0.26
        if index == 0 {
            path.move(to: CGPoint(x: x, y: y))
        } else {
            path.line(to: CGPoint(x: x, y: y))
        }
    }
    path.lineWidth = 9
    path.lineJoinStyle = .round
    path.lineCapStyle = .round
    shade(color(0xEE8D62), -0.22).withAlphaComponent(0.6).setStroke()
    path.stroke()
}
block(row(2, columns: 2), base: color(0x7CC4DE, 0.9)) { rect in
    NSColor.white.withAlphaComponent(0.45).setStroke()
    var x = rect.minX - rect.height
    while x < rect.maxX {
        let streak = NSBezierPath()
        streak.move(to: CGPoint(x: x, y: rect.minY))
        streak.line(to: CGPoint(x: x + rect.height, y: rect.maxY))
        streak.lineWidth = 11
        streak.stroke()
        x += 46
    }
}
let top = row(3, columns: 1).offsetBy(dx: unit * 0.12, dy: -4)
block(top, base: stone, rotation: -0.12) { speckles($0, seed: 3) }

NSGraphicsContext.restoreGraphicsState()

// The App Store refuses icons with transparency: copy into an opaque image before saving.
guard let rendered = canvas.cgImage,
      let opaque = CGContext(data: nil, width: Int(side), height: Int(side), bitsPerComponent: 8, bytesPerRow: 0,
                             space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                             bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
else { fatalError("Could not flatten the icon") }
opaque.draw(rendered, in: CGRect(x: 0, y: 0, width: side, height: side))
guard let flattened = opaque.makeImage(),
      let png = NSBitmapImageRep(cgImage: flattened).representation(using: .png, properties: [:])
else { fatalError("Could not encode the icon") }
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
print("Wrote", CommandLine.arguments[1])
