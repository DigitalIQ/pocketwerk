import AppKit
import SwiftUI

/// Procedural textures for `Background.texture(name:tint:)`. Every texture is a seamless tile
/// drawn in code from a fixed seed, so it looks the same on every Mac and in every render.
enum TextureKind: String, CaseIterable, Sendable {
    case knit, paper, noise, ice, cardboard, linen, leopard, snowLeopard, tiger, terrazzo, denim, felt

    var title: String {
        switch self {
        case .knit: String(localized: "Knit")
        case .paper: String(localized: "Paper")
        case .noise: String(localized: "Grain")
        case .ice: String(localized: "Ice")
        case .cardboard: String(localized: "Cardboard")
        case .linen: String(localized: "Linen")
        case .leopard: String(localized: "Spots")
        case .snowLeopard: String(localized: "Alpine Spots")
        case .tiger: String(localized: "Stripes")
        case .terrazzo: String(localized: "Terrazzo")
        case .denim: String(localized: "Denim")
        case .felt: String(localized: "Felt")
        }
    }

    /// A tint that shows the texture at its best, used when a texture is picked in the studio.
    var suggestedTint: RGBA {
        switch self {
        case .knit: RGBA(hex: "#B5404E")
        case .paper: RGBA(hex: "#F3EBDA")
        case .noise: RGBA(hex: "#2E3138")
        case .ice: RGBA(hex: "#BFE3F2")
        case .cardboard: RGBA(hex: "#B98B5B")
        case .linen: RGBA(hex: "#E6DED0")
        case .leopard: RGBA(hex: "#D9A856")
        case .snowLeopard: RGBA(hex: "#D8D8D4")
        case .tiger: RGBA(hex: "#E07A22")
        case .terrazzo: RGBA(hex: "#EFEAE2")
        case .denim: RGBA(hex: "#2F4A7A")
        case .felt: RGBA(hex: "#1F6B4A")
        }
    }

    /// Unknown names fall back to grain, so old or hand-edited files still render.
    init(name: String) { self = TextureKind(rawValue: name) ?? .noise }
}

enum TextureFactory {
    /// Tile edge in points. The pixel tile is twice as large.
    static let tilePoints: CGFloat = 160
    private static var cache: [String: CGImage] = [:]

    /// Seamless tile for a texture and tint, cached.
    static func tile(_ kind: TextureKind, tint: RGBA) -> CGImage? {
        let key = "\(kind.rawValue)|\(tint.hex)|\(Int(tint.a * 100))"
        if let hit = cache[key] { return hit }
        let px = Int(tilePoints * 2)
        guard let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        var painter = TexturePainter(ctx: ctx, size: CGFloat(px), tint: tint.opaque, rng: SeededRandom(string: kind.rawValue))
        painter.paint(kind)
        let image = ctx.makeImage()
        if cache.count > 64 { cache.removeAll() }
        cache[key] = image
        return image
    }

    /// Fine grain used by the matte slider.
    static var grain: CGImage? { tile(.noise, tint: RGBA(0.5, 0.5, 0.5)) }
}

/// SwiftUI view that tiles a texture over its frame.
struct TextureFill: View {
    var kind: TextureKind
    var tint: RGBA

    var body: some View {
        if let tile = TextureFactory.tile(kind, tint: tint) {
            Image(decorative: tile, scale: 2).resizable(resizingMode: .tile)
        } else {
            tint.opaque.color
        }
    }
}

// MARK: - Painting

private struct TexturePainter {
    let ctx: CGContext
    let size: CGFloat
    let tint: RGBA
    var rng: SeededRandom

    var s: CGFloat { size / 320 } // unit scale, tiles are designed at 320 px

    mutating func paint(_ kind: TextureKind) {
        ctx.setFillColor(tint.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
        switch kind {
        case .knit: knit()
        case .paper: paper()
        case .noise: grain(0.09)
        case .ice: ice()
        case .cardboard: cardboard()
        case .linen: linen()
        case .leopard: spots(base: tint, ring: tint.darker(0.82), center: tint.darker(0.18), count: 16, hollow: false)
        case .snowLeopard: spots(base: tint, ring: RGBA(0.22, 0.22, 0.24), center: tint.darker(0.12), count: 11, hollow: true)
        case .tiger: tiger()
        case .terrazzo: terrazzo()
        case .denim: denim()
        case .felt: felt()
        }
    }

    // MARK: Helpers

    /// Draws `body` at every offset where the element would cross the tile edge, so the tile stays seamless.
    func wrapped(_ bounds: CGRect, _ body: (CGContext) -> Void) {
        for dx in [-size, 0, size] {
            for dy in [-size, 0, size] {
                let r = bounds.offsetBy(dx: dx, dy: dy)
                guard r.intersects(CGRect(x: 0, y: 0, width: size, height: size)) else { continue }
                ctx.saveGState()
                ctx.translateBy(x: dx, y: dy)
                body(ctx)
                ctx.restoreGState()
            }
        }
    }

    /// Adds per-pixel luminance noise directly to the bitmap.
    mutating func grain(_ amount: Double, mono: Bool = true) {
        guard let data = ctx.data else { return }
        let w = ctx.width, h = ctx.height, row = ctx.bytesPerRow
        let p = data.bindMemory(to: UInt8.self, capacity: row * h)
        for y in 0..<h {
            for x in 0..<w {
                let i = y * row + x * 4
                let n = (rng.unit() - 0.5) * 2 * amount * 255
                for c in 0..<3 {
                    let jitter = mono ? n : (rng.unit() - 0.5) * 2 * amount * 255
                    p[i + c] = UInt8(max(0, min(Double(p[i + 3]), Double(p[i + c]) + jitter)))
                }
            }
        }
    }

    mutating func fibers(count: Int, length: ClosedRange<Double>, alpha: Double, width: CGFloat) {
        for _ in 0..<count {
            let x = rng.range(0, Double(size)), y = rng.range(0, Double(size))
            let a = rng.range(0, .pi * 2), len = rng.range(length.lowerBound, length.upperBound) * Double(s)
            let light = rng.unit() > 0.5
            let color = (light ? RGBA.white : RGBA.black).alpha(rng.range(alpha * 0.4, alpha))
            let bend = rng.range(-0.6, 0.6)
            let end = CGPoint(x: x + cos(a) * len, y: y + sin(a) * len)
            let ctrl = CGPoint(x: x + cos(a + bend) * len * 0.5, y: y + sin(a + bend) * len * 0.5)
            let bounds = CGRect(x: min(x, end.x) - 4, y: min(y, end.y) - 4, width: abs(end.x - x) + 8, height: abs(end.y - y) + 8)
            wrapped(bounds) { c in
                c.setStrokeColor(color.cgColor)
                c.setLineWidth(width * s)
                c.move(to: CGPoint(x: x, y: y))
                c.addQuadCurve(to: end, control: ctrl)
                c.strokePath()
            }
        }
    }

    mutating func blob(center: CGPoint, radius: CGFloat, lobes: Int, irregular: Double) -> CGPath {
        let path = CGMutablePath()
        let n = lobes * 2
        var pts: [CGPoint] = []
        for i in 0..<n {
            let a = Double(i) / Double(n) * .pi * 2
            let r = Double(radius) * rng.range(1 - irregular, 1 + irregular * 0.6)
            pts.append(CGPoint(x: center.x + cos(a) * r, y: center.y + sin(a) * r * 0.85))
        }
        path.move(to: CGPoint(x: (pts[0].x + pts[n - 1].x) / 2, y: (pts[0].y + pts[n - 1].y) / 2))
        for i in 0..<n {
            let next = pts[(i + 1) % n]
            path.addQuadCurve(to: CGPoint(x: (pts[i].x + next.x) / 2, y: (pts[i].y + next.y) / 2), control: pts[i])
        }
        path.closeSubpath()
        return path
    }

    // MARK: Textures

    mutating func knit() {
        // Rows of V stitches: two slanted loops per stitch, lit from the top.
        let w = 20 * s, h = 16 * s
        let cols = Int((size / w).rounded()), rows = Int((size / h).rounded())
        let light = tint.lighter(0.22), dark = tint.darker(0.35)
        ctx.setFillColor(tint.darker(0.45).cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
        for r in 0...rows {
            for c in 0..<cols {
                let cx = (CGFloat(c) + 0.5) * w, cy = CGFloat(r) * h
                for side in [-1.0, 1.0] {
                    let jitter = rng.range(-0.04, 0.04)
                    let rect = CGRect(x: -w * 0.27, y: -h * 0.62, width: w * 0.54, height: h * 1.24)
                    wrapped(CGRect(x: cx - w, y: cy - h, width: w * 2, height: h * 2)) { g in
                        g.saveGState()
                        g.translateBy(x: cx + side * w * 0.22, y: cy)
                        g.rotate(by: CGFloat(side * (0.5 + jitter)))
                        let path = CGPath(ellipseIn: rect, transform: nil)
                        g.addPath(path)
                        g.clip()
                        let colors = [light.cgColor, tint.cgColor, dark.cgColor] as CFArray
                        let grad = CGGradient(colorsSpace: nil, colors: colors, locations: [0, 0.45, 1])!
                        g.drawLinearGradient(grad, start: CGPoint(x: 0, y: rect.maxY), end: CGPoint(x: 0, y: rect.minY), options: [])
                        g.resetClip()
                        g.addPath(path)
                        g.setStrokeColor(RGBA.black.alpha(0.18).cgColor)
                        g.setLineWidth(0.8 * s)
                        g.strokePath()
                        g.restoreGState()
                    }
                }
            }
        }
        grain(0.035)
    }

    mutating func paper() {
        ctx.setFillColor(tint.lighter(0.04).cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
        // Soft cloudy variation.
        for _ in 0..<10 {
            let c = CGPoint(x: rng.range(0, Double(size)), y: rng.range(0, Double(size)))
            let r = CGFloat(rng.range(40, 110)) * s
            let col = (rng.unit() > 0.5 ? RGBA.white : tint.darker(0.3)).alpha(0.06)
            wrapped(CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)) { g in
                let grad = CGGradient(colorsSpace: nil, colors: [col.cgColor, col.alpha(0).cgColor] as CFArray, locations: [0, 1])!
                g.drawRadialGradient(grad, startCenter: c, startRadius: 0, endCenter: c, endRadius: r, options: [])
            }
        }
        fibers(count: 90, length: 6...22, alpha: 0.07, width: 0.7)
        grain(0.03)
    }

    mutating func ice() {
        // Frosty patches, then cracks with a bright edge.
        for _ in 0..<12 {
            let c = CGPoint(x: rng.range(0, Double(size)), y: rng.range(0, Double(size)))
            let r = CGFloat(rng.range(30, 90)) * s
            let col = (rng.unit() > 0.4 ? RGBA.white.alpha(0.22) : tint.darker(0.25).alpha(0.18))
            wrapped(CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)) { g in
                let grad = CGGradient(colorsSpace: nil, colors: [col.cgColor, col.alpha(0).cgColor] as CFArray, locations: [0, 1])!
                g.drawRadialGradient(grad, startCenter: c, startRadius: 0, endCenter: c, endRadius: r, options: [])
            }
        }
        for _ in 0..<9 {
            var p = CGPoint(x: rng.range(0, Double(size)), y: rng.range(0, Double(size)))
            var a = rng.range(0, .pi * 2)
            let path = CGMutablePath()
            path.move(to: p)
            for _ in 0..<Int(rng.range(5, 11)) {
                a += rng.range(-0.7, 0.7)
                let len = rng.range(10, 30) * Double(s)
                p = CGPoint(x: p.x + cos(a) * len, y: p.y + sin(a) * len)
                path.addLine(to: p)
            }
            let bounds = path.boundingBox.insetBy(dx: -4, dy: -4)
            wrapped(bounds) { g in
                g.addPath(path); g.setStrokeColor(tint.darker(0.35).alpha(0.35).cgColor); g.setLineWidth(1.6 * s); g.strokePath()
                g.addPath(path); g.setStrokeColor(RGBA.white.alpha(0.75).cgColor); g.setLineWidth(0.6 * s); g.strokePath()
            }
        }
        for _ in 0..<40 {
            let c = CGPoint(x: rng.range(0, Double(size)), y: rng.range(0, Double(size)))
            ctx.setFillColor(RGBA.white.alpha(rng.range(0.3, 0.8)).cgColor)
            let r = CGFloat(rng.range(0.4, 1.3)) * s
            ctx.fillEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        }
        grain(0.025)
    }

    mutating func cardboard() {
        // Corrugation bands, fibers and speckles.
        let bands = 20
        let bw = size / CGFloat(bands)
        for i in 0..<bands {
            let x = CGFloat(i) * bw
            let grad = CGGradient(colorsSpace: nil, colors: [tint.darker(0.12).cgColor, tint.lighter(0.06).cgColor, tint.darker(0.12).cgColor] as CFArray, locations: [0, 0.5, 1])!
            ctx.saveGState()
            ctx.clip(to: CGRect(x: x, y: 0, width: bw, height: size))
            ctx.drawLinearGradient(grad, start: CGPoint(x: x, y: 0), end: CGPoint(x: x + bw, y: 0), options: [])
            ctx.restoreGState()
        }
        fibers(count: 140, length: 4...16, alpha: 0.12, width: 0.8)
        for _ in 0..<70 {
            let c = CGPoint(x: rng.range(0, Double(size)), y: rng.range(0, Double(size)))
            ctx.setFillColor(tint.darker(rng.range(0.4, 0.7)).alpha(0.5).cgColor)
            let r = CGFloat(rng.range(0.4, 1.4)) * s
            ctx.fillEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        }
        grain(0.045)
    }

    mutating func linen() {
        let step = 3 * s
        var y: CGFloat = 0
        while y < size {
            let dark = rng.unit() > 0.5
            ctx.setFillColor((dark ? RGBA.black : RGBA.white).alpha(rng.range(0.03, 0.12)).cgColor)
            ctx.fill(CGRect(x: 0, y: y, width: size, height: step * CGFloat(rng.range(0.3, 0.6))))
            y += step
        }
        var x: CGFloat = 0
        while x < size {
            let dark = rng.unit() > 0.5
            ctx.setFillColor((dark ? RGBA.black : RGBA.white).alpha(rng.range(0.03, 0.1)).cgColor)
            ctx.fill(CGRect(x: x, y: 0, width: step * CGFloat(rng.range(0.3, 0.6)), height: size))
            x += step
        }
        // Slubs: short thicker threads.
        for _ in 0..<26 {
            let p = CGPoint(x: rng.range(0, Double(size)), y: rng.range(0, Double(size)))
            let len = CGFloat(rng.range(8, 26)) * s
            let horizontal = rng.unit() > 0.5
            let r = horizontal ? CGRect(x: p.x, y: p.y, width: len, height: 1.4 * s) : CGRect(x: p.x, y: p.y, width: 1.4 * s, height: len)
            let col = RGBA.white.alpha(0.12)
            wrapped(r) { g in g.setFillColor(col.cgColor); g.fill(r) }
        }
        grain(0.03)
    }

    mutating func spots(base: RGBA, ring: RGBA, center: RGBA, count: Int, hollow: Bool) {
        grain(0.03)
        let grid = Int(Double(count).squareRoot().rounded(.up))
        let cell = size / CGFloat(grid)
        for gy in 0..<grid {
            for gx in 0..<grid {
                let c = CGPoint(x: (CGFloat(gx) + CGFloat(rng.range(0.2, 0.8))) * cell,
                                y: (CGFloat(gy) + CGFloat(rng.range(0.2, 0.8))) * cell)
                let r = cell * CGFloat(rng.range(0.24, 0.34))
                let inner = blob(center: c, radius: r * 0.8, lobes: 4, irregular: 0.25)
                let lobes = Int(rng.range(4, 7))
                var marks: [CGPath] = []
                let start = rng.range(0, .pi * 2)
                for k in 0..<lobes {
                    // Leave one gap so the ring looks open, like a real rosette.
                    if k == lobes - 1 && rng.unit() > 0.4 { continue }
                    let a = start + Double(k) / Double(lobes) * .pi * 2
                    let p = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r * 0.85)
                    marks.append(blob(center: p, radius: r * CGFloat(rng.range(0.3, 0.42)), lobes: 3, irregular: 0.35))
                }
                wrapped(CGRect(x: c.x - r * 1.6, y: c.y - r * 1.6, width: r * 3.2, height: r * 3.2)) { g in
                    if !hollow { g.addPath(inner); g.setFillColor(center.cgColor); g.fillPath() }
                    for m in marks { g.addPath(m) }
                    g.setFillColor(ring.cgColor)
                    g.fillPath()
                }
            }
        }
        // Small solid dots between rosettes.
        for _ in 0..<count {
            let c = CGPoint(x: rng.range(0, Double(size)), y: rng.range(0, Double(size)))
            let dot = blob(center: c, radius: CGFloat(rng.range(2.5, 5)) * s, lobes: 3, irregular: 0.3)
            wrapped(dot.boundingBox) { g in g.addPath(dot); g.setFillColor(ring.alpha(0.9).cgColor); g.fillPath() }
        }
    }

    mutating func tiger() {
        // Light belly glow, then tapered wavy stripes.
        let glow = CGGradient(colorsSpace: nil, colors: [tint.lighter(0.18).cgColor, tint.cgColor, tint.darker(0.08).cgColor] as CFArray, locations: [0, 0.5, 1])!
        ctx.drawLinearGradient(glow, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: size), options: [])
        let stripes = 7
        for i in 0..<stripes {
            let x0 = (CGFloat(i) + CGFloat(rng.range(0.1, 0.9))) * size / CGFloat(stripes)
            let len = size * CGFloat(rng.range(0.45, 0.85))
            let y0 = CGFloat(rng.range(0, Double(size)))
            let width = CGFloat(rng.range(7, 13)) * s
            let wave = rng.range(6, 14) * Double(s), phase = rng.range(0, 6)
            let path = CGMutablePath()
            let n = 18
            var left: [CGPoint] = [], right: [CGPoint] = []
            for k in 0...n {
                let t = CGFloat(k) / CGFloat(n)
                let y = y0 + t * len
                let x = x0 + CGFloat(sin(Double(t) * 5 + phase) * wave)
                let taper = sin(Double(t) * .pi) // thin at both ends
                let half = width * CGFloat(0.15 + 0.85 * taper) / 2
                left.append(CGPoint(x: x - half, y: y)); right.append(CGPoint(x: x + half, y: y))
            }
            path.addLines(between: left + right.reversed())
            path.closeSubpath()
            // A forked branch on some stripes.
            if rng.unit() > 0.5 {
                let b = left[n / 3]
                path.move(to: b)
                path.addQuadCurve(to: CGPoint(x: b.x - 16 * s, y: b.y + 26 * s), control: CGPoint(x: b.x - 2 * s, y: b.y + 16 * s))
                path.addLine(to: CGPoint(x: b.x + 3 * s, y: b.y + 8 * s))
                path.closeSubpath()
            }
            wrapped(path.boundingBox) { g in g.addPath(path); g.setFillColor(RGBA(0.09, 0.06, 0.04).cgColor); g.fillPath() }
        }
        fibers(count: 120, length: 3...8, alpha: 0.1, width: 0.6)
        grain(0.03)
    }

    mutating func terrazzo() {
        grain(0.02)
        let chips: [RGBA] = [tint.darker(0.45), RGBA(hex: "#C96B4B"), RGBA(hex: "#3E6E73"), RGBA(hex: "#E2B65A"), RGBA(hex: "#8A8F96"), tint.darker(0.2)]
        for _ in 0..<80 {
            let c = CGPoint(x: rng.range(0, Double(size)), y: rng.range(0, Double(size)))
            let r = rng.range(2.5, 11) * Double(s)
            let n = Int(rng.range(3, 7))
            let path = CGMutablePath()
            for k in 0..<n {
                let a = Double(k) / Double(n) * .pi * 2 + rng.range(-0.3, 0.3)
                let rr = r * rng.range(0.6, 1.2)
                let p = CGPoint(x: c.x + cos(a) * rr, y: c.y + sin(a) * rr)
                if k == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            path.closeSubpath()
            let col = chips[Int(rng.range(0, Double(chips.count))) % chips.count]
            wrapped(path.boundingBox) { g in g.addPath(path); g.setFillColor(col.cgColor); g.fillPath() }
        }
    }

    mutating func denim() {
        // Diagonal twill, bright weft flecks.
        let step = 4 * s
        var k: CGFloat = -size
        while k < size {
            ctx.setStrokeColor(RGBA.white.alpha(rng.range(0.06, 0.14)).cgColor)
            ctx.setLineWidth(1.3 * s)
            ctx.move(to: CGPoint(x: k, y: 0))
            ctx.addLine(to: CGPoint(x: k + size, y: size))
            ctx.strokePath()
            k += step
        }
        for _ in 0..<160 {
            let p = CGPoint(x: rng.range(0, Double(size)), y: rng.range(0, Double(size)))
            ctx.setFillColor(RGBA.white.alpha(rng.range(0.05, 0.18)).cgColor)
            ctx.fill(CGRect(x: p.x, y: p.y, width: CGFloat(rng.range(1, 5)) * s, height: 0.9 * s))
        }
        grain(0.05)
    }

    mutating func felt() {
        grain(0.06)
        fibers(count: 420, length: 2...7, alpha: 0.09, width: 0.6)
    }
}
