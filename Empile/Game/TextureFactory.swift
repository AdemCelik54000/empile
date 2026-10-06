import SpriteKit
import UIKit

/// Draws every texture of the game in code: rounded blocks with a soft shadow, a subtle gradient,
/// a bevel and a pattern per kind (so blocks stay recognizable without relying on color).
@MainActor
final class TextureFactory {
    private struct BlockKey: Hashable {
        let kind: BlockKind
        let shape: BlockShape
        let variant: Int
        /// A spring that has already fired.
        let isSpent: Bool
    }

    private struct PreviewKey: Hashable {
        let kind: BlockKind
        let shape: BlockShape
        let style: UIUserInterfaceStyle
        let displayScale: CGFloat
    }

    private var blockCache: [BlockKey: SKTexture] = [:]
    private var previewCache: [PreviewKey: UIImage] = [:]
    private var traits = UITraitCollection(userInterfaceStyle: .light)
    private var displayScale: CGFloat = 1

    /// Size of a block sprite: its footprint plus room for the shadow.
    static func spriteSize(for shape: BlockShape) -> CGSize {
        shape.size(unit: Tuning.World.unit).outset(by: Tuning.Look.shadowPadding)
    }

    func configure(style: UIUserInterfaceStyle, displayScale: CGFloat) {
        guard style != traits.userInterfaceStyle || displayScale != self.displayScale else { return }
        traits = UITraitCollection(userInterfaceStyle: style)
        self.displayScale = displayScale
        blockCache.removeAll()
    }

    func resolve(_ color: UIColor) -> UIColor {
        color.resolvedColor(with: traits)
    }

    func block(_ kind: BlockKind, shape: BlockShape, variant: Int, isSpent: Bool = false) -> SKTexture {
        let key = BlockKey(kind: kind, shape: shape, variant: variant, isSpent: isSpent)
        if let cached = blockCache[key] { return cached }
        let texture = SKTexture(image: renderBlock(key, traits: traits, scale: displayScale))
        blockCache[key] = texture
        return texture
    }

    /// The same drawing as in the game, for the hand. Independent of the scene's current style,
    /// so SwiftUI can ask for either appearance at any time.
    func preview(of kind: BlockKind, shape: BlockShape, style: UIUserInterfaceStyle, displayScale: CGFloat) -> UIImage {
        let key = PreviewKey(kind: kind, shape: shape, style: style, displayScale: displayScale)
        if let cached = previewCache[key] { return cached }
        let blockKey = BlockKey(kind: kind, shape: shape, variant: 0, isSpent: false)
        let image = renderBlock(blockKey, traits: UITraitCollection(userInterfaceStyle: style), scale: displayScale)
        previewCache[key] = image
        return image
    }

    /// A small sharp triangle, tinted by the emitter, for glass shards.
    func shard(size: CGFloat) -> SKTexture {
        let image = renderer(size: CGSize(width: size, height: size)).image { _ in
            let path = UIBezierPath()
            path.move(to: CGPoint(x: size * 0.5, y: 0))
            path.addLine(to: CGPoint(x: size, y: size))
            path.addLine(to: CGPoint(x: 0, y: size * 0.7))
            path.close()
            UIColor.white.setFill()
            path.fill()
        }
        return SKTexture(image: image)
    }

    /// A four-pointed star with curved sides, tinted by the emitter, for sparkles.
    func sparkle(size: CGFloat) -> SKTexture {
        let image = renderer(size: CGSize(width: size, height: size)).image { _ in
            let center = size / 2
            let pinch = size * Tuning.Celebration.sparklePinch
            let path = UIBezierPath()
            path.move(to: CGPoint(x: center, y: 0))
            path.addQuadCurve(to: CGPoint(x: size, y: center), controlPoint: CGPoint(x: center + pinch, y: center - pinch))
            path.addQuadCurve(to: CGPoint(x: center, y: size), controlPoint: CGPoint(x: center + pinch, y: center + pinch))
            path.addQuadCurve(to: CGPoint(x: 0, y: center), controlPoint: CGPoint(x: center - pinch, y: center + pinch))
            path.addQuadCurve(to: CGPoint(x: center, y: 0), controlPoint: CGPoint(x: center - pinch, y: center - pinch))
            path.close()
            UIColor.white.setFill()
            path.fill()
        }
        return SKTexture(image: image)
    }

    enum BirdPose: CaseIterable {
        case perched
        case wingsUp
        case wingsDown
    }

    /// A small round bird facing right, its feet at the bottom middle of the picture.
    func bird(_ pose: BirdPose) -> SKTexture {
        let size = Tuning.Birds.size
        let width = size.width
        let height = size.height
        // Drawn on a 30 × 24 grid, scaled to the bird size.
        let grid = CGSize(width: 30, height: 24)
        let body = resolve(Palette.bird)
        let wing = body.adjustingBrightness(by: -Tuning.Birds.wingShade)
        let image = renderer(size: size).image { context in
            let cg = context.cgContext
            cg.scaleBy(x: width / grid.width, y: height / grid.height)
            func triangle(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> UIBezierPath {
                let path = UIBezierPath()
                path.move(to: a)
                path.addLine(to: b)
                path.addLine(to: c)
                path.close()
                return path
            }
            body.setFill()
            triangle(CGPoint(x: 6, y: 12), CGPoint(x: 0, y: 8), CGPoint(x: 1, y: 15)).fill()
            UIBezierPath(ovalIn: CGRect(x: 5, y: 9, width: 18, height: 11)).fill()
            UIBezierPath(ovalIn: CGRect(x: 16, y: 4, width: 10, height: 10)).fill()
            self.resolve(Palette.beak).setFill()
            triangle(CGPoint(x: 25, y: 7.5), CGPoint(x: 30, y: 9.5), CGPoint(x: 25, y: 11)).fill()
            if pose == .perched {
                cg.setStrokeColor(self.resolve(Palette.beak).cgColor)
                cg.setLineWidth(1.4)
                cg.setLineCap(.round)
                for x in [12.0, 16.0] {
                    cg.move(to: CGPoint(x: x, y: 19))
                    cg.addLine(to: CGPoint(x: x, y: 23.3))
                    cg.move(to: CGPoint(x: x - 1.5, y: 23.3))
                    cg.addLine(to: CGPoint(x: x + 1.5, y: 23.3))
                }
                cg.strokePath()
            }
            wing.setFill()
            switch pose {
            case .perched:
                UIBezierPath(ovalIn: CGRect(x: 7, y: 11, width: 12, height: 6)).fill()
            case .wingsUp:
                triangle(CGPoint(x: 9, y: 13), CGPoint(x: 6, y: 0), CGPoint(x: 18, y: 12)).fill()
            case .wingsDown:
                triangle(CGPoint(x: 9, y: 13), CGPoint(x: 7, y: 23), CGPoint(x: 18, y: 14)).fill()
            }
            self.resolve(Palette.shade).setFill()
            UIBezierPath(ovalIn: CGRect(x: 21.2, y: 6.8, width: 2.4, height: 2.4)).fill()
        }
        return SKTexture(image: image)
    }

    func platform(size: CGSize) -> SKTexture {
        let base = resolve(Palette.platform)
        let rect = CGRect(origin: .zero, size: size)
        let image = renderer(size: size).image { context in
            let outline = UIBezierPath(roundedRect: rect, cornerRadius: Tuning.Look.platformCornerRadius)
            outline.addClip()
            fillVerticalGradient(in: rect, top: base.adjustingBrightness(by: Tuning.Look.gradientSpread),
                                 bottom: base.adjustingBrightness(by: -Tuning.Look.gradientSpread),
                                 context: context.cgContext)
            drawBevel(in: rect)
        }
        return SKTexture(image: image)
    }

    /// A tiny vertical gradient, meant to be stretched over a large sprite.
    func verticalGradient(top: UIColor, bottom: UIColor) -> SKTexture {
        let size = CGSize(width: 1, height: Tuning.Look.gradientTextureHeight)
        let image = renderer(size: size).image { context in
            fillVerticalGradient(in: CGRect(origin: .zero, size: size), top: resolve(top), bottom: resolve(bottom),
                                 context: context.cgContext)
        }
        return SKTexture(image: image)
    }

    /// The color at the top, fading to fully transparent at the bottom.
    func verticalFade(of color: UIColor) -> SKTexture {
        let resolved = resolve(color)
        return verticalGradient(top: resolved, bottom: resolved.withAlphaComponent(0))
    }

    /// A soft round dot that fades to transparent at its edge, for particles. Tinted by the emitter.
    func softDot(diameter: CGFloat) -> SKTexture {
        let size = CGSize(width: diameter, height: diameter)
        let image = renderer(size: size).image { context in
            let colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: nil)
            else { return }
            let center = CGPoint(x: diameter / 2, y: diameter / 2)
            context.cgContext.drawRadialGradient(gradient, startCenter: center, startRadius: 0,
                                                 endCenter: center, endRadius: diameter / 2, options: [])
        }
        return SKTexture(image: image)
    }

    // MARK: - Blocks

    private func renderBlock(_ key: BlockKey, traits: UITraitCollection, scale: CGFloat) -> UIImage {
        let size = key.shape.size(unit: Tuning.World.unit)
        let rect = CGRect(origin: CGPoint(x: Tuning.Look.shadowPadding, y: Tuning.Look.shadowPadding), size: size)
        let resolvedBase = Palette.base(of: key.kind).resolvedColor(with: traits)
        let base = key.isSpent ? resolvedBase.desaturated(by: Tuning.Look.spentSpringFade) : resolvedBase
        let shadow = Palette.shadow.resolvedColor(with: traits)
        let outline = TextureFactory.outlinePath(of: key.shape, in: rect)
        return renderer(size: TextureFactory.spriteSize(for: key.shape), scale: scale).image { context in
            let cgContext = context.cgContext

            cgContext.saveGState()
            cgContext.setShadow(offset: CGSize(width: 0, height: Tuning.Look.shadowOffset),
                                blur: Tuning.Look.shadowBlur, color: shadow.cgColor)
            cgContext.addPath(outline)
            cgContext.setFillColor(base.cgColor)
            cgContext.fillPath()
            cgContext.restoreGState()

            cgContext.saveGState()
            cgContext.addPath(outline)
            cgContext.clip()
            fillVerticalGradient(in: rect, top: base.adjustingBrightness(by: Tuning.Look.gradientSpread),
                                 bottom: base.adjustingBrightness(by: -Tuning.Look.gradientSpread),
                                 context: cgContext)
            drawPattern(for: key, base: base, in: rect, context: cgContext)
            drawBevel(of: key.shape, in: rect)
            // Stroked inside the clip, so the edge stays within the piece.
            cgContext.addPath(outline)
            cgContext.setLineWidth(Tuning.Look.edgeWidth * 2)
            cgContext.setStrokeColor(base.adjustingBrightness(by: -Tuning.Look.edgeDarkening).cgColor)
            cgContext.strokePath()
            cgContext.restoreGState()
        }
    }

    /// The piece's outline in image coordinates, outer corners rounded, inner corners softened.
    private static func outlinePath(of shape: BlockShape, in rect: CGRect) -> CGPath {
        let unit = Tuning.World.unit
        let corners = shape.outline
        let points = corners.map { CGPoint(x: rect.minX + CGFloat($0.x) * unit, y: rect.maxY - CGFloat($0.y) * unit) }
        let path = CGMutablePath()
        guard let last = points.last, let first = points.first else { return path }
        path.move(to: CGPoint(x: (last.x + first.x) / 2, y: (last.y + first.y) / 2))
        for index in points.indices {
            let radius = corners[index].isConvex ? Tuning.Look.blockCornerRadius : Tuning.Look.innerCornerRadius
            path.addArc(tangent1End: points[index], tangent2End: points[(index + 1) % points.count], radius: radius)
        }
        path.closeSubpath()
        return path
    }

    private func drawPattern(for key: BlockKey, base: UIColor, in rect: CGRect, context: CGContext) {
        switch key.kind {
        case .stone: drawSpeckles(in: rect, seed: seed(for: key), context: context)
        case .spring: drawCoils(of: key.shape, in: rect, base: base, isSpent: key.isSpent)
        case .glass: drawGlints(in: rect, context: context)
        case .gold: drawSparkles(of: key.shape, in: rect, seed: seed(for: key), context: context)
        }
    }

    /// Gold: a soft diagonal sheen and small four-point sparkles.
    private func drawSparkles(of shape: BlockShape, in rect: CGRect, seed: UInt64, context: CGContext) {
        let white = resolve(Palette.highlight)
        context.setStrokeColor(white.withAlphaComponent(Tuning.Look.sheenOpacity).cgColor)
        context.setLineWidth(rect.height * 0.25)
        context.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        context.addLine(to: CGPoint(x: rect.minX + rect.height, y: rect.minY))
        context.strokePath()
        var generator = SeededGenerator(seed: seed)
        let unit = Tuning.World.unit
        let count = max(1, Int((CGFloat(shape.area) * Tuning.Look.sparklesPerUnit).rounded()))
        context.setFillColor(white.withAlphaComponent(Tuning.Look.sparkleOpacity).cgColor)
        for index in 0..<count {
            let cell = shape.cells[index % shape.cells.count]
            let x = rect.minX + (CGFloat(cell.column) + CGFloat.random(in: 0.25...0.75, using: &generator)) * unit
            let y = rect.maxY - (CGFloat(cell.row) + CGFloat.random(in: 0.25...0.75, using: &generator)) * unit
            let size = Tuning.Look.sparkleSize
            let star = CGMutablePath()
            star.move(to: CGPoint(x: x, y: y - size))
            star.addQuadCurve(to: CGPoint(x: x + size, y: y), control: CGPoint(x: x, y: y))
            star.addQuadCurve(to: CGPoint(x: x, y: y + size), control: CGPoint(x: x, y: y))
            star.addQuadCurve(to: CGPoint(x: x - size, y: y), control: CGPoint(x: x, y: y))
            star.addQuadCurve(to: CGPoint(x: x, y: y - size), control: CGPoint(x: x, y: y))
            context.addPath(star)
            context.fillPath()
        }
    }

    /// Spring: a zigzag coil along every row of the piece. Flattened once the spring has fired.
    private func drawCoils(of shape: BlockShape, in rect: CGRect, base: UIColor, isSpent: Bool) {
        let unit = Tuning.World.unit
        base.adjustingBrightness(by: -Tuning.Look.edgeDarkening).withAlphaComponent(Tuning.Look.coilOpacity).setStroke()
        for run in shape.horizontalRuns {
            let row = CGRect(x: rect.minX + CGFloat(run.firstColumn) * unit,
                             y: rect.maxY - CGFloat(run.row + 1) * unit,
                             width: CGFloat(run.length) * unit, height: unit)
            let segments = max(2, Int(CGFloat(run.length) * Tuning.Look.coilTurnsPerUnit * 2))
            let amplitude = unit * Tuning.Look.coilAmplitude * (isSpent ? Tuning.Look.spentSpringFade : 1)
            let inset = row.insetBy(dx: Tuning.Look.coilLineWidth * 2, dy: 0)
            let path = UIBezierPath()
            for index in 0...segments {
                let x = inset.minX + inset.width * CGFloat(index) / CGFloat(segments)
                let y = row.midY + (index.isMultiple(of: 2) ? -amplitude : amplitude)
                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            path.lineWidth = Tuning.Look.coilLineWidth
            path.lineJoinStyle = .round
            path.lineCapStyle = .round
            path.stroke()
        }
    }

    /// Glass: diagonal light streaks across a see-through body.
    private func drawGlints(in rect: CGRect, context: CGContext) {
        let spacing = Tuning.Look.glintSpacing
        context.setStrokeColor(UIColor.white.withAlphaComponent(Tuning.Look.glintOpacity).cgColor)
        context.setLineWidth(Tuning.Look.glintWidth)
        var x = rect.minX - rect.height
        while x < rect.maxX {
            context.move(to: CGPoint(x: x, y: rect.maxY))
            context.addLine(to: CGPoint(x: x + rect.height, y: rect.minY))
            x += spacing
        }
        context.strokePath()
    }

    /// Stone: light and dark grains scattered over the face.
    private func drawSpeckles(in rect: CGRect, seed: UInt64, context: CGContext) {
        var generator = SeededGenerator(seed: seed)
        let unitArea = Tuning.World.unit * Tuning.World.unit
        let count = Int(rect.width * rect.height / unitArea * Tuning.Look.stoneSpecklesPerUnit)
        let light = resolve(Palette.highlight).withAlphaComponent(Tuning.Look.stoneSpeckleLightOpacity).cgColor
        let dark = resolve(Palette.shade).withAlphaComponent(Tuning.Look.stoneSpeckleDarkOpacity).cgColor
        let margin = Tuning.Look.stoneSpeckleRadius.upperBound
        let area = rect.insetBy(dx: margin, dy: margin)
        for _ in 0..<count {
            let radius = CGFloat.random(in: Tuning.Look.stoneSpeckleRadius, using: &generator)
            let x = CGFloat.random(in: area.minX...area.maxX, using: &generator)
            let y = CGFloat.random(in: area.minY...area.maxY, using: &generator)
            context.setFillColor(Bool.random(using: &generator) ? light : dark)
            context.fillEllipse(in: CGRect(x: x - radius, y: y - radius, width: 2 * radius, height: 2 * radius))
        }
    }

    /// Stable from one launch to the next (unlike `hashValue`), and different for every piece and variant.
    private func seed(for key: BlockKey) -> UInt64 {
        key.shape.cells.reduce(UInt64(key.variant) &+ 1) { $0 &* 31 &+ UInt64($1.column * 8 + $1.row + 1) }
    }

    // MARK: - Shared drawing

    /// Light catching the top edge, a touch of shade on the bottom edge. Expects a clip to the outline.
    private func drawBevel(in rect: CGRect) {
        let height = Tuning.Look.bevelHeight
        resolve(Palette.highlight).withAlphaComponent(Tuning.Look.bevelHighlightOpacity).setFill()
        UIRectFillUsingBlendMode(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: height), .normal)
        resolve(Palette.shade).withAlphaComponent(Tuning.Look.bevelShadeOpacity).setFill()
        UIRectFillUsingBlendMode(CGRect(x: rect.minX, y: rect.maxY - height, width: rect.width, height: height), .normal)
    }

    /// The same bevel on every exposed top and bottom edge of a piece, steps included.
    private func drawBevel(of shape: BlockShape, in rect: CGRect) {
        let unit = Tuning.World.unit
        let height = Tuning.Look.bevelHeight
        for cell in shape.cells {
            let x = rect.minX + CGFloat(cell.column) * unit
            let top = rect.maxY - CGFloat(cell.row + 1) * unit
            if !shape.contains(column: cell.column, row: cell.row + 1) {
                resolve(Palette.highlight).withAlphaComponent(Tuning.Look.bevelHighlightOpacity).setFill()
                UIRectFillUsingBlendMode(CGRect(x: x, y: top, width: unit, height: height), .normal)
            }
            if !shape.contains(column: cell.column, row: cell.row - 1) {
                resolve(Palette.shade).withAlphaComponent(Tuning.Look.bevelShadeOpacity).setFill()
                UIRectFillUsingBlendMode(CGRect(x: x, y: top + unit - height, width: unit, height: height), .normal)
            }
        }
    }

    private func fillVerticalGradient(in rect: CGRect, top: UIColor, bottom: UIColor, context: CGContext) {
        let colors = [top.cgColor, bottom.cgColor] as CFArray
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: nil)
        else { return }
        context.drawLinearGradient(gradient, start: CGPoint(x: rect.midX, y: rect.minY),
                                   end: CGPoint(x: rect.midX, y: rect.maxY), options: [])
    }

    private func renderer(size: CGSize, scale: CGFloat? = nil) -> UIGraphicsImageRenderer {
        let format = UIGraphicsImageRendererFormat.preferred()
        format.scale = scale ?? displayScale
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format)
    }
}
