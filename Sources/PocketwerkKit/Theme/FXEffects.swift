import SwiftUI

/// Draws one frame of each animated background into a GraphicsContext.
/// Particle counts stay small (under ~200 shapes, batched into a few paths) to keep CPU low.
enum FXRenderer {
    static func framesPerSecond(_ kind: FXKind) -> Double {
        switch kind {
        case .plasma: 60
        case .arcs, .blobs, .waves, .marble, .aurora, .fog, .driftingLight, .lava, .curtains, .ripples: 45
        default: 30
        }
    }

    static func draw(_ f: FXFrame, into gc: inout GraphicsContext) {
        guard f.w > 1, f.h > 1 else { return }
        switch f.p.kind {
        case .arcs: arcs(f, &gc)
        case .curtains: curtains(f, &gc)
        case .waves: waves(f, &gc)
        case .marble: marble(f, &gc)
        case .snow: snow(f, &gc)
        case .embers: embers(f, &gc)
        case .glyphRain: glyphRain(f, &gc)
        case .blobs: blobs(f, &gc)
        case .fur: fur(f, &gc)
        case .rain: rain(f, &gc)
        case .fog: fog(f, &gc)
        case .driftingLight: driftingLight(f, &gc)
        case .lava: lava(f, &gc)
        case .aurora: aurora(f, &gc)
        case .starfield: starfield(f, &gc)
        case .plasma: gc.fill(Path(f.rect), with: .color(f.color(0).color))
        case .bubbles: bubbles(f, &gc)
        case .ripples: ripples(f, &gc)
        }
    }

    // MARK: Helpers

    private static func fillVertical(_ gc: GraphicsContext, _ f: FXFrame, _ colors: [RGBA]) {
        gc.fill(Path(f.rect), with: .linearGradient(Gradient(colors: colors.map(\.color)),
                                                     startPoint: .zero, endPoint: CGPoint(x: 0, y: f.h)))
    }

    private static func glow(_ gc: GraphicsContext, _ c: CGPoint, _ r: Double, _ color: RGBA, _ alpha: Double) {
        guard r > 0.2, alpha > 0.003 else { return }
        let rect = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
        gc.fill(Path(ellipseIn: rect), with: .radialGradient(Gradient(colors: [color.alpha(alpha).color, color.alpha(0).color]),
                                                             center: c, startRadius: 0, endRadius: r))
    }

    private static func dot(_ path: inout Path, _ c: CGPoint, _ r: Double) {
        path.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    }

    private static func wrap(_ v: Double, _ m: Double) -> Double {
        let r = v.truncatingRemainder(dividingBy: m)
        return r < 0 ? r + m : r
    }

    /// Base fill: the optional base color, or a darkened palette color.
    private static func base(_ f: FXFrame, _ fallback: RGBA) -> RGBA { f.p.base ?? fallback }

    // MARK: Bands of light

    static func arcs(_ f: FXFrame, _ gc: inout GraphicsContext) {
        let b = base(f, f.color(0).darker(0.82))
        fillVertical(gc, f, [b.lighter(0.07), b])
        var g = gc
        g.blendMode = .plusLighter
        let n = 5 + max(0, min(3, f.p.style))
        for i in 0..<n {
            let fi = Double(i)
            let phase = hash01(i, 1) * 6.28
            let amp = f.h * (0.06 + 0.1 * hash01(i, 2))
            let freq = (1.1 + 1.6 * hash01(i, 3)) * 2 * .pi / f.w
            let sp = 0.35 + 0.5 * hash01(i, 4)
            let y0 = f.h * (0.16 + 0.68 * (fi + 0.5) / Double(n)) + f.p.drift * 20 * sin(f.t * 0.2)
            let color = f.color(1).mixed(with: f.color(2), n > 1 ? fi / Double(n - 1) : 0)
            var path = Path()
            var x = -12.0
            while x <= f.w + 12 {
                let wave1 = amp * sin(freq * x + f.t * sp + phase)
                let wave2 = amp * 0.35 * sin(freq * 0.47 * x - f.t * 0.6 * sp + phase * 2)
                let y = y0 + wave1 + wave2
                let d = f.push(x, y)
                let pt = CGPoint(x: x + d.dx * 0.3, y: y + d.dy)
                if path.isEmpty { path.move(to: pt) } else { path.addLine(to: pt) }
                x += 10
            }
            let scale = 0.6 + 0.8 * f.p3
            for (width, alpha) in [(26.0, 0.06), (10.0, 0.16), (3.5, 0.5), (1.2, 0.95)] {
                let col = width < 2 ? color.lighter(0.55) : color
                g.stroke(path, with: .color(col.alpha(min(1, alpha * f.k)).color),
                         style: StrokeStyle(lineWidth: width * scale, lineCap: .round, lineJoin: .round))
            }
        }
    }

    // MARK: Curtains

    static func curtains(_ f: FXFrame, _ gc: inout GraphicsContext) {
        let c0 = f.color(0), hi = f.color(1), trim = f.color(2)
        gc.fill(Path(f.rect), with: .color(c0.darker(0.6).color))
        let n = 11 + max(0, min(3, f.p.style)) * 3
        let foldW = f.w / Double(n) * 1.35
        for i in 0..<n {
            let sway = sin(f.t * 0.55 + Double(i) * 0.9) * f.w / Double(n) * 0.16
            let cx0 = (Double(i) + 0.5) * f.w / Double(n) + sway
            let d = f.push(cx0, f.h * 0.6, radius: f.minSide * 0.3)
            let cx = cx0 + d.dx
            let hem = f.h * (0.985 + 0.012 * sin(Double(i) * 1.7 + f.t * 0.8))
            var path = Path()
            path.move(to: CGPoint(x: cx - foldW / 2, y: 0))
            path.addLine(to: CGPoint(x: cx + foldW / 2, y: 0))
            path.addLine(to: CGPoint(x: cx + foldW / 2 + d.dx * 0.4, y: hem))
            path.addQuadCurve(to: CGPoint(x: cx - foldW / 2 + d.dx * 0.4, y: hem),
                              control: CGPoint(x: cx + d.dx * 0.4, y: hem + f.h * 0.02))
            path.closeSubpath()
            let stops = [c0.darker(0.55), c0, hi.alpha(1).mixed(with: c0, 0.35), c0, c0.darker(0.55)]
            gc.fill(path, with: .linearGradient(Gradient(colors: stops.map(\.color)),
                                                startPoint: CGPoint(x: cx - foldW / 2, y: 0), endPoint: CGPoint(x: cx + foldW / 2, y: 0)))
        }
        // Shade from the top, light from a spot.
        gc.fill(Path(f.rect), with: .linearGradient(Gradient(colors: [RGBA.black.alpha(0.45).color, .clear, RGBA.black.alpha(0.3).color]),
                                                    startPoint: .zero, endPoint: CGPoint(x: 0, y: f.h)))
        var g = gc
        g.blendMode = .plusLighter
        glow(g, CGPoint(x: f.w * (0.5 + 0.2 * sin(f.t * 0.13)), y: f.h * 0.15), f.minSide * 0.9, trim, 0.16 * f.k)
        // Valance with a trim line.
        let valance = CGRect(x: 0, y: 0, width: f.w, height: f.h * 0.07)
        gc.fill(Path(valance), with: .linearGradient(Gradient(colors: [c0.darker(0.4).color, c0.darker(0.15).color]),
                                                     startPoint: .zero, endPoint: CGPoint(x: 0, y: valance.maxY)))
        gc.fill(Path(CGRect(x: 0, y: valance.maxY - 2, width: f.w, height: 2)), with: .color(trim.alpha(0.8).color))
    }

    // MARK: Waves

    static func waves(_ f: FXFrame, _ gc: inout GraphicsContext) {
        let c0 = f.color(0)
        fillVertical(gc, f, [c0.darker(0.45), c0])
        let n = 5
        for i in 0..<n {
            let fi = Double(i) / Double(n - 1)
            let y0 = f.h * (0.32 + 0.14 * Double(i))
            let amp = f.h * 0.035 * (1 + Double(i) * 0.35) * (0.6 + 0.8 * f.p3)
            let freq = (1.4 + hash01(i, 5)) * 2 * .pi / f.w
            let sp = 0.6 + 0.35 * Double(i)
            let color = f.color(1).mixed(with: f.color(2), fi)
            var path = Path()
            var crest = Path()
            path.move(to: CGPoint(x: 0, y: f.h))
            var x = -8.0
            while x <= f.w + 8 {
                var y = y0 + amp * sin(freq * x + f.t * sp + Double(i)) + amp * 0.4 * sin(freq * 2.3 * x - f.t * sp * 0.7)
                y += f.push(x, y, strength: 0.6).dy
                let pt = CGPoint(x: x, y: y)
                path.addLine(to: pt)
                if crest.isEmpty { crest.move(to: pt) } else { crest.addLine(to: pt) }
                x += 8
            }
            path.addLine(to: CGPoint(x: f.w, y: f.h))
            path.closeSubpath()
            gc.fill(path, with: .linearGradient(Gradient(colors: [color.lighter(0.12).alpha(0.65 + 0.07 * Double(i)).color,
                                                                  color.darker(0.15).alpha(0.9).color]),
                                                startPoint: CGPoint(x: 0, y: y0 - amp), endPoint: CGPoint(x: 0, y: f.h)))
            gc.stroke(crest, with: .color(RGBA.white.alpha(0.18 * f.k).color), lineWidth: 1.3)
        }
    }

    // MARK: Marble

    static func marble(_ f: FXFrame, _ gc: inout GraphicsContext) {
        let c0 = f.color(0), cloud = f.color(1), vein = f.color(2)
        gc.fill(Path(f.rect), with: .linearGradient(Gradient(colors: [c0.lighter(0.05).color, c0.darker(0.05).color]),
                                                    startPoint: .zero, endPoint: CGPoint(x: f.w, y: f.h)))
        for i in 0..<5 {
            let c = CGPoint(x: f.w * (0.2 + 0.6 * hash01(i, 1)) + 30 * sin(f.t * 0.05 + Double(i)),
                            y: f.h * (0.2 + 0.6 * hash01(i, 2)))
            glow(gc, c, f.minSide * (0.35 + 0.25 * hash01(i, 3)), cloud, 0.22)
        }
        let n = 6 + max(0, min(4, f.p.style))
        for i in 0..<n {
            let y0 = f.h * (hash01(i, 7) * 1.2 - 0.1)
            let slope = (hash01(i, 8) - 0.5) * 0.9
            var path = Path()
            var x = -10.0
            while x <= f.w + 10 {
                let warp = 22 * sin(x * 0.012 + f.t * 0.09 + Double(i)) * sin(x * 0.029 - f.t * 0.06 + Double(i) * 2)
                var y = y0 + slope * x + warp + 8 * sin(x * 0.07 + Double(i) * 3)
                let d = f.push(x, y, strength: 0.5)
                y += d.dy
                let pt = CGPoint(x: x + d.dx, y: y)
                if path.isEmpty { path.move(to: pt) } else { path.addLine(to: pt) }
                x += 7
            }
            let weight = 0.5 + hash01(i, 9)
            gc.stroke(path, with: .color(vein.alpha(0.07 * f.k).color), style: StrokeStyle(lineWidth: 9 * weight, lineCap: .round, lineJoin: .round))
            gc.stroke(path, with: .color(vein.alpha(0.2 * f.k).color), style: StrokeStyle(lineWidth: 2.6 * weight, lineCap: .round, lineJoin: .round))
            gc.stroke(path, with: .color(vein.alpha(0.55 * f.k).color), style: StrokeStyle(lineWidth: 0.7 * weight, lineCap: .round, lineJoin: .round))
        }
    }

    // MARK: Snow

    static func snow(_ f: FXFrame, _ gc: inout GraphicsContext) {
        let sky = base(f, f.color(0))
        fillVertical(gc, f, [sky.darker(0.4), sky])
        let flake = f.color(1)
        let count = Int(60 + 110 * f.p3)
        var near = Path(), mid = Path(), far = Path()
        for i in 0..<count {
            let depth = hash01(i, 2)
            let r = 0.8 + 2.6 * depth * depth
            let v = 12 + 34 * depth
            let span = f.h + 20
            let y = wrap(hash01(i, 3) * span + f.t * v, span) - 10
            let x0 = hash01(i, 1) * f.w + sin(f.t * (0.4 + hash01(i, 4)) + Double(i)) * 14 + f.p.drift * f.t * 10 * (0.5 + depth)
            let pt = f.displaced(i, wrap(x0, f.w + 10) - 5, y)
            if depth > 0.66 { dot(&near, pt, r) } else if depth > 0.33 { dot(&mid, pt, r) } else { dot(&far, pt, r) }
        }
        gc.fill(far, with: .color(flake.alpha(0.45 * f.k).color))
        gc.fill(mid, with: .color(flake.alpha(0.7 * f.k).color))
        gc.fill(near, with: .color(flake.alpha(min(1, 0.95 * f.k)).color))
        // The pile settles over the first 30 seconds.
        let settle = min(1, f.age / 30)
        let pileH = f.h * 0.085 * settle * (0.6 + 0.4 * f.p3)
        guard pileH > 0.5 else { return }
        var pile = Path()
        pile.move(to: CGPoint(x: 0, y: f.h))
        var x = 0.0
        while x <= f.w + 6 {
            let y = f.h - pileH * (0.75 + 0.25 * sin(x * 0.021 + 1.3) * cos(x * 0.009))
            pile.addLine(to: CGPoint(x: x, y: y))
            x += 6
        }
        pile.addLine(to: CGPoint(x: f.w, y: f.h))
        pile.closeSubpath()
        gc.fill(pile, with: .linearGradient(Gradient(colors: [flake.color, flake.darker(0.12).color]),
                                            startPoint: CGPoint(x: 0, y: f.h - pileH), endPoint: CGPoint(x: 0, y: f.h)))
    }

    // MARK: Embers

    static func embers(_ f: FXFrame, _ gc: inout GraphicsContext) {
        let b = base(f, f.color(0).darker(0.8))
        fillVertical(gc, f, [b, b.mixed(with: f.color(1), 0.18)])
        var g = gc
        g.blendMode = .plusLighter
        glow(g, CGPoint(x: f.w / 2, y: f.h * 1.15), max(f.w, f.h) * 0.75, f.color(1), 0.4 * f.k)
        let count = Int(40 + 60 * f.p3)
        for i in 0..<count {
            let life = 4 + 4 * hash01(i, 1)
            let phase = wrap(f.t / life + hash01(i, 2), 1)
            let y = f.h + 10 - phase * (f.h + 30)
            let x = hash01(i, 3) * f.w + sin(f.t * 1.3 * hash01(i, 4) + Double(i)) * 22 * phase + f.p.drift * phase * 60
            let pt = f.displaced(i, x, y)
            let size = (1 + 2.4 * hash01(i, 5)) * (1 - phase * 0.6)
            let flicker = 0.6 + 0.4 * sin(f.t * 9 + Double(i) * 1.7)
            let alpha = flicker * (1 - phase) * f.k
            let col = f.color(2).mixed(with: f.color(1), phase)
            glow(g, pt, size * 4, col, alpha * 0.35)
            glow(g, pt, size * 1.3, col.lighter(0.4), min(1, alpha))
        }
    }

    // MARK: Glyph rain

    private static let glyphs: [Character] = Array("ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾗﾘﾙﾚﾛﾜ0123456789=+*<>:")

    static func glyphRain(_ f: FXFrame, _ gc: inout GraphicsContext) {
        gc.fill(Path(f.rect), with: .color(base(f, RGBA(0.01, 0.03, 0.02)).color))
        let size = 10 + 10 * f.p.p4
        let cols = max(1, Int(f.w / size))
        let rows = max(1, Int(f.h / size) + 1)
        let trail = Int(8 + 16 * f.p.p5)
        let font = Font.system(size: size * 0.92, weight: .medium, design: .monospaced)
        var resolved: [Character: GraphicsContext.ResolvedText] = [:]
        let tail = f.color(0), head = f.color(1)
        for col in 0..<cols where hash01(col, 7) < 0.8 {
            let speed = 5 + 9 * hash01(col, 1)
            let headRow = wrap(hash01(col, 2) * Double(rows * 2) + f.t * speed, Double(rows + trail))
            let x = (Double(col) + 0.5) * f.w / Double(cols)
            for kk in 0..<trail {
                let row = Int(headRow) - kk
                guard row >= 0, row < rows else { continue }
                // Some glyphs change now and then.
                let flip = hash01(col * 131 + row, 3) < 0.15 ? Int(f.t * 3) : 0
                let ch = glyphs[Int(hash01(col * 977 + row * 31 + flip, 4) * Double(glyphs.count)) % glyphs.count]
                let fade = pow(1 - Double(kk) / Double(trail), 1.6)
                let color = kk == 0 ? head : tail
                var text = resolved[ch] ?? gc.resolve(Text(String(ch)).font(font))
                resolved[ch] = text
                text.shading = .color(color.alpha(min(1, fade * f.k)).color)
                gc.draw(text, at: CGPoint(x: x, y: (Double(row) + 0.5) * size), anchor: .center)
            }
        }
    }

    // MARK: Blobs

    static func blobs(_ f: FXFrame, _ gc: inout GraphicsContext) {
        let b = base(f, f.color(0).darker(0.6))
        fillVertical(gc, f, [b.lighter(0.05), b.darker(0.2)])
        var g = gc
        g.blendMode = .screen
        let n = 6
        for i in 0..<n {
            let sx = 0.17 * (1 + hash01(i, 1)), sy = 0.13 * (1 + hash01(i, 2))
            let x = f.w * (0.5 + 0.38 * sin(f.t * sx + Double(i) * 1.7))
            let y = f.h * (0.5 + 0.36 * cos(f.t * sy + Double(i) * 2.3))
            let pt = f.displaced(i, x, y)
            let r = f.minSide * (0.38 + 0.22 * hash01(i, 3)) * (0.7 + 0.6 * f.p3)
            glow(g, pt, r, f.color(i), 0.75 * f.k)
        }
    }

    // MARK: Fur

    static func fur(_ f: FXFrame, _ gc: inout GraphicsContext) {
        let coat = f.color(0), belly = f.color(1), stripe = f.color(2)
        gc.fill(Path(f.rect), with: .color(coat.darker(0.3).color))
        let length = 9 + 13 * f.p3
        let spacing = max(6, min(12, length * 0.55))
        let cols = Int(f.w / spacing) + 2, rows = Int(f.h / spacing) + 2
        // Nine buckets: three colors times three shades.
        var paths = Array(repeating: Path(), count: 9)
        let period = f.w / 5.5
        for r in 0..<rows {
            for c in 0..<cols {
                let idx = r * cols + c
                let bx = (Double(c) - 0.5 + hash01(idx, 1) * 0.8) * spacing
                let by = (Double(r) - 0.5 + hash01(idx, 2) * 0.8) * spacing
                let s = sin(bx * 2 * .pi / period + 2.2 * sin(by * 0.018 + bx * 0.004) + Double(f.p.style))
                let colorIndex = s > 0.55 ? 2 : (s < -0.78 || by > f.h * 0.86 ? 1 : 0)
                let shade = Int(hash01(idx, 3) * 3)
                var angle = Double.pi / 2 + 0.35 + 0.25 * sin(bx * 0.01 + by * 0.013)
                angle += 0.07 * sin(f.t * 1.4 + bx * 0.03 + by * 0.02)
                var dx = cos(angle), dy = sin(angle)
                if let ptr = f.state.pointerPoint, f.state.influence > 0 {
                    // Comb: strands bend away from the pointer.
                    let vx = bx - Double(ptr.x), vy = by - Double(ptr.y)
                    let d = max(0.001, (vx * vx + vy * vy).squareRoot())
                    let rr = f.minSide * 0.18
                    let infl = exp(-(d / rr) * (d / rr)) * f.state.influence * 2.4
                    dx += vx / d * infl; dy += vy / d * infl
                    let len = max(0.001, (dx * dx + dy * dy).squareRoot())
                    dx /= len; dy /= len
                }
                let l = length * (0.8 + 0.4 * hash01(idx, 4))
                paths[colorIndex * 3 + shade].move(to: CGPoint(x: bx, y: by))
                paths[colorIndex * 3 + shade].addLine(to: CGPoint(x: bx + dx * l, y: by + dy * l))
            }
        }
        let colors = [coat, belly, stripe]
        for ci in 0..<3 {
            for sh in 0..<3 {
                let col = sh == 0 ? colors[ci].darker(0.12) : (sh == 1 ? colors[ci] : colors[ci].lighter(0.12))
                gc.stroke(paths[ci * 3 + sh], with: .color(col.color), style: StrokeStyle(lineWidth: 1.9, lineCap: .round))
            }
        }
        // Soft top light gives the coat some volume.
        gc.fill(Path(f.rect), with: .linearGradient(Gradient(colors: [RGBA.white.alpha(0.1 * f.k).color, .clear, RGBA.black.alpha(0.18).color]),
                                                    startPoint: .zero, endPoint: CGPoint(x: 0, y: f.h)))
    }

    // MARK: Rain

    static func rain(_ f: FXFrame, _ gc: inout GraphicsContext) {
        let b = base(f, f.color(0))
        fillVertical(gc, f, [b.darker(0.45), b.darker(0.15)])
        let drop = f.color(1)
        let slant = 0.12 + f.p.drift * 0.3
        let count = Int(70 + 110 * f.p3)
        var far = Path(), near = Path()
        for i in 0..<count {
            let v = 420 + 380 * hash01(i, 1)
            let len = 9 + 18 * hash01(i, 2)
            let span = f.h + len
            let y = wrap(hash01(i, 3) * span * 2 + f.t * v, span) - len
            var x = wrap(hash01(i, 4) * (f.w + f.h * slant) + y * slant, f.w + f.h * slant) - f.h * slant * 0.5
            x += f.push(x, y, strength: 0.8).dx
            let target = hash01(i, 5) > 0.8 ? 1 : 0
            let start = CGPoint(x: x, y: y), end = CGPoint(x: x + len * slant, y: y + len)
            if target == 1 { near.move(to: start); near.addLine(to: end) } else { far.move(to: start); far.addLine(to: end) }
        }
        gc.stroke(far, with: .color(drop.alpha(0.3 * f.k).color), lineWidth: 1)
        gc.stroke(near, with: .color(drop.alpha(min(1, 0.6 * f.k)).color), lineWidth: 1.4)
        // Splashes along the bottom.
        var splashes = Path()
        for i in 0..<14 {
            let phase = wrap(f.t * 1.3 + hash01(i, 6), 1)
            let r = 2 + 10 * phase
            let c = CGPoint(x: hash01(i + Int(f.t * 1.3 + hash01(i, 6)) * 17, 7) * f.w, y: f.h - 6 - 8 * hash01(i, 8))
            splashes.addEllipse(in: CGRect(x: c.x - r, y: c.y - r * 0.3, width: r * 2, height: r * 0.6))
        }
        gc.stroke(splashes, with: .color(drop.alpha(0.25 * f.k).color), lineWidth: 0.8)
        // Drops sliding down the glass.
        var beads = Path(), shine = Path()
        for i in 0..<16 {
            let r = 1.5 + 3 * hash01(i, 9)
            let y = wrap(hash01(i, 10) * f.h + f.t * 7 * hash01(i, 11), f.h + 10) - 5
            let c = CGPoint(x: hash01(i, 12) * f.w, y: y)
            dot(&beads, c, r)
            dot(&shine, CGPoint(x: c.x - r * 0.35, y: c.y - r * 0.35), r * 0.3)
        }
        gc.fill(beads, with: .color(drop.alpha(0.16).color))
        gc.stroke(beads, with: .color(drop.alpha(0.35).color), lineWidth: 0.6)
        gc.fill(shine, with: .color(RGBA.white.alpha(0.7).color))
    }

    // MARK: Fog

    static func fog(_ f: FXFrame, _ gc: inout GraphicsContext) {
        fillVertical(gc, f, [f.color(0), f.color(1)])
        let mist = f.color(2)
        let n = 9
        for i in 0..<n {
            let span = f.w * 1.8
            let speed = (7 + 12 * hash01(i, 1)) * (1 + f.p.drift)
            let x0 = wrap(hash01(i, 2) * span + f.t * speed, span) - f.w * 0.4
            let y0 = f.h * (0.1 + 0.85 * hash01(i, 3))
            let d = f.push(x0, y0, radius: f.minSide * 0.45, strength: 1.4)
            let rx = f.w * (0.3 + 0.3 * hash01(i, 4))
            var g = gc
            g.translateBy(x: x0 + d.dx, y: y0 + d.dy)
            g.scaleBy(x: 1, y: 0.42)
            glow(g, .zero, rx, mist, (0.2 + 0.15 * f.p3) * f.k)
        }
    }

    // MARK: Drifting light

    static func driftingLight(_ f: FXFrame, _ gc: inout GraphicsContext) {
        let b = base(f, f.color(0))
        gc.fill(Path(f.rect), with: .linearGradient(Gradient(colors: [b.darker(0.15).color, b.darker(0.6).color]),
                                                    startPoint: .zero, endPoint: CGPoint(x: f.w, y: f.h)))
        var g = gc
        g.blendMode = .plusLighter
        // Slow rays from the top left.
        let origin = CGPoint(x: -f.w * 0.1, y: -f.h * 0.25)
        let far = (f.w * f.w + f.h * f.h).squareRoot() * 1.4
        for i in 0..<4 {
            let a = 0.55 + 0.22 * Double(i) + 0.05 * sin(f.t * 0.12 + Double(i) * 1.9)
            let spread = 0.035 + 0.025 * hash01(i, 1)
            var ray = Path()
            ray.move(to: origin)
            ray.addLine(to: CGPoint(x: origin.x + cos(a - spread) * far, y: origin.y + sin(a - spread) * far))
            ray.addLine(to: CGPoint(x: origin.x + cos(a + spread) * far, y: origin.y + sin(a + spread) * far))
            ray.closeSubpath()
            g.fill(ray, with: .radialGradient(Gradient(colors: [f.color(2).alpha(0.16 * f.k).color, .clear]),
                                              center: origin, startRadius: 0, endRadius: far * 0.7))
        }
        for i in 0..<6 {
            var x = f.w * (0.5 + 0.42 * sin(f.t * 0.09 * (1 + hash01(i, 2)) + Double(i) * 2.1))
            var y = f.h * (0.5 + 0.4 * cos(f.t * 0.07 * (1 + hash01(i, 3)) + Double(i) * 1.3))
            if let ptr = f.state.pointerPoint {
                // Lights lean toward the pointer.
                x += (Double(ptr.x) - x) * 0.25 * f.state.influence
                y += (Double(ptr.y) - y) * 0.25 * f.state.influence
            }
            glow(g, CGPoint(x: x, y: y), f.minSide * (0.2 + 0.2 * hash01(i, 4)) * (0.7 + 0.6 * f.p3),
                 i % 2 == 0 ? f.color(1) : f.color(2), 0.5 * f.k)
        }
        var motes = Path()
        for i in 0..<40 {
            let y = wrap(hash01(i, 5) * f.h - f.t * (3 + 6 * hash01(i, 6)), f.h)
            let x = hash01(i, 7) * f.w + 10 * sin(f.t * 0.3 + Double(i))
            dot(&motes, CGPoint(x: x, y: y), 0.6 + 1.1 * hash01(i, 8))
        }
        g.fill(motes, with: .color(f.color(2).alpha(0.5 * f.k).color))
    }

    // MARK: Lava

    static func lava(_ f: FXFrame, _ gc: inout GraphicsContext) {
        let b = base(f, f.color(0))
        fillVertical(gc, f, [b.darker(0.35), b])
        var g = gc
        g.blendMode = .plusLighter
        glow(g, CGPoint(x: f.w / 2, y: f.h), f.w * 0.7, f.color(1), 0.35 * f.k)
        let n = 8
        var centers: [(CGPoint, Double)] = []
        for i in 0..<n {
            let y = f.h * (0.5 + 0.5 * sin(f.t * 0.22 * (0.5 + hash01(i, 1)) + Double(i) * 1.3))
            let x = f.w * (0.12 + 0.76 * hash01(i, 2)) + sin(f.t * 0.3 + Double(i)) * f.w * 0.05
            let r = f.minSide * (0.07 + 0.07 * hash01(i, 3)) * (0.7 + 0.6 * f.p3)
            centers.append((f.displaced(i, x, y), r))
        }
        // Metaballs: blurred discs cut at an alpha threshold. Three thresholds give shading.
        let layers: [(Double, RGBA)] = [(0.42, f.color(1).darker(0.25)), (0.6, f.color(1)), (0.8, f.color(2))]
        for (threshold, color) in layers {
            gc.drawLayer { layer in
                layer.addFilter(.alphaThreshold(min: threshold, color: color.color))
                layer.addFilter(.blur(radius: f.minSide * 0.05))
                layer.drawLayer { inner in
                    for (c, r) in centers {
                        inner.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(.black))
                    }
                    inner.fill(Path(ellipseIn: CGRect(x: -f.w * 0.1, y: f.h * 0.93, width: f.w * 1.2, height: f.h * 0.3)), with: .color(.black))
                    inner.fill(Path(ellipseIn: CGRect(x: f.w * 0.1, y: -f.h * 0.2, width: f.w * 0.8, height: f.h * 0.25)), with: .color(.black))
                }
            }
        }
    }

    // MARK: Aurora

    static func aurora(_ f: FXFrame, _ gc: inout GraphicsContext) {
        let b = base(f, f.color(0))
        fillVertical(gc, f, [b.darker(0.45), b])
        var stars = Path()
        for i in 0..<60 {
            let tw = 0.5 + 0.5 * sin(f.t * 2 + Double(i) * 1.3)
            dot(&stars, CGPoint(x: hash01(i, 1) * f.w, y: hash01(i, 2) * f.h * 0.8), 0.4 + 0.7 * hash01(i, 3) * tw)
        }
        gc.fill(stars, with: .color(RGBA.white.alpha(0.7).color))
        gc.drawLayer { layer in
            layer.blendMode = .plusLighter
            layer.addFilter(.blur(radius: 10))
            for i in 0..<3 {
                let color = i == 1 ? f.color(2) : f.color(1).mixed(with: f.color(2), Double(i) * 0.25)
                var path = Path()
                var top: [CGPoint] = [], bottom: [CGPoint] = []
                var x = -20.0
                while x <= f.w + 20 {
                    var yb = f.h * (0.42 + 0.12 * Double(i)) + f.h * 0.08 * sin(x * 0.006 + f.t * 0.25 + Double(i) * 1.7)
                        + f.h * 0.04 * sin(x * 0.017 - f.t * 0.4 + Double(i))
                    yb += f.push(x, yb, strength: 0.7).dy
                    let hh = f.h * (0.26 + 0.1 * sin(x * 0.01 + f.t * 0.3 + Double(i))) * (0.7 + 0.6 * f.p3)
                    bottom.append(CGPoint(x: x, y: yb)); top.append(CGPoint(x: x, y: yb - hh))
                    x += 10
                }
                path.addLines(bottom + top.reversed())
                path.closeSubpath()
                let minY = top.map(\.y).min() ?? 0, maxY = bottom.map(\.y).max() ?? CGFloat(f.h)
                layer.fill(path, with: .linearGradient(Gradient(stops: [
                    .init(color: color.alpha(0).color, location: 0),
                    .init(color: color.alpha(0.45 * f.k).color, location: 0.75),
                    .init(color: color.lighter(0.3).alpha(min(1, 0.8 * f.k)).color, location: 0.93),
                    .init(color: color.alpha(0).color, location: 1),
                ]), startPoint: CGPoint(x: 0, y: minY), endPoint: CGPoint(x: 0, y: maxY)))
            }
        }
    }

    // MARK: Starfield

    static func starfield(_ f: FXFrame, _ gc: inout GraphicsContext) {
        let b = base(f, f.color(0))
        gc.fill(Path(f.rect), with: .radialGradient(Gradient(colors: [b.lighter(0.06).color, b.darker(0.5).color]),
                                                    center: CGPoint(x: f.w / 2, y: f.h / 2), startRadius: 0, endRadius: max(f.w, f.h) * 0.7))
        var g = gc
        g.blendMode = .plusLighter
        glow(g, CGPoint(x: f.w * 0.3, y: f.h * 0.35), f.minSide * 0.6, f.color(1), 0.14 * f.k)
        glow(g, CGPoint(x: f.w * 0.75, y: f.h * 0.7), f.minSide * 0.5, f.color(2), 0.12 * f.k)
        var cx = f.w / 2, cy = f.h / 2
        if let ptr = f.state.pointerPoint {
            // Parallax: the vanishing point follows the pointer a little.
            cx += (Double(ptr.x) - cx) * 0.2 * f.state.influence
            cy += (Double(ptr.y) - cy) * 0.2 * f.state.influence
        }
        let scale = max(f.w, f.h) * 0.5
        let count = Int(90 + 90 * f.p3)
        var buckets = Array(repeating: Path(), count: 4)
        for i in 0..<count {
            let sx = hash01(i, 1) * 2 - 1, sy = hash01(i, 2) * 2 - 1
            let z = 1 - wrap(f.t * 0.05 * (0.6 + 0.8 * hash01(i, 3)) + hash01(i, 4), 1) * 0.94
            let x1 = cx + sx / z * scale * 0.35, y1 = cy + sy / z * scale * 0.35
            let z0 = min(1, z + 0.025)
            let x0 = cx + sx / z0 * scale * 0.35, y0 = cy + sy / z0 * scale * 0.35
            guard x1 > -4, x1 < f.w + 4, y1 > -4, y1 < f.h + 4 else { continue }
            let bucket = min(3, Int((1 - z) * 4))
            buckets[bucket].move(to: CGPoint(x: x0, y: y0))
            buckets[bucket].addLine(to: CGPoint(x: x1, y: y1))
        }
        for (k, path) in buckets.enumerated() {
            let a = (0.25 + 0.25 * Double(k)) * f.k
            g.stroke(path, with: .color(RGBA.white.alpha(min(1, a)).color), style: StrokeStyle(lineWidth: 0.7 + 0.6 * Double(k), lineCap: .round))
        }
    }

    // MARK: Bubbles

    static func bubbles(_ f: FXFrame, _ gc: inout GraphicsContext) {
        let b = base(f, f.color(0))
        fillVertical(gc, f, [b, b.mixed(with: f.color(2), 0.6)])
        var g = gc
        g.blendMode = .plusLighter
        glow(g, CGPoint(x: f.w * 0.5, y: -f.h * 0.1), f.w * 0.7, RGBA.white, 0.18 * f.k)
        let rim = f.color(1)
        var rims = Path(), fills = Path(), shines = Path()
        let count = Int(22 + 30 * f.p3)
        for i in 0..<count {
            let size = hash01(i, 1)
            let r = 2.5 + 15 * size * size
            let v = 16 + 30 * (1 - size * 0.6)
            let span = f.h + r * 2 + 10
            let y = f.h + r - wrap(hash01(i, 2) * span + f.t * v, span)
            let x = hash01(i, 3) * f.w + sin(f.t * 1.4 * (0.5 + hash01(i, 4)) + Double(i)) * 6 * (r / 8)
            let c = f.displaced(i, x, y)
            dot(&rims, c, r)
            dot(&fills, c, r)
            shines.addEllipse(in: CGRect(x: c.x - r * 0.55, y: c.y - r * 0.6, width: r * 0.45, height: r * 0.3))
        }
        gc.fill(fills, with: .color(rim.alpha(0.07 * f.k).color))
        gc.stroke(rims, with: .color(rim.alpha(min(1, 0.5 * f.k)).color), lineWidth: 1)
        gc.fill(shines, with: .color(RGBA.white.alpha(0.75).color))
    }

    // MARK: Ripples

    static func ripples(_ f: FXFrame, _ gc: inout GraphicsContext) {
        gc.fill(Path(f.rect), with: .linearGradient(Gradient(colors: [f.color(0).color, f.color(1).color]),
                                                    startPoint: .zero, endPoint: CGPoint(x: f.w, y: f.h)))
        var g = gc
        g.blendMode = .plusLighter
        for i in 0..<3 {
            let c = CGPoint(x: f.w * (0.5 + 0.4 * sin(f.t * 0.11 + Double(i) * 2)), y: f.h * (0.5 + 0.4 * cos(f.t * 0.09 + Double(i))))
            glow(g, c, f.minSide * 0.5, f.color(2), 0.1 * f.k)
        }
        let ring = f.color(2)
        // Drops at fixed intervals, each spreading three rings.
        let interval = 0.9 - 0.5 * f.p3
        let latest = Int(floor(f.t / interval))
        for j in 0..<5 {
            let m = latest - j
            let age = f.t - Double(m) * interval
            let life = 3.6
            guard age >= 0, age < life else { continue }
            let c = CGPoint(x: hash01(m, 1) * f.w, y: hash01(m, 2) * f.h)
            for (n, scale) in [1.0, 0.72, 0.48].enumerated() {
                let r = age * 46 * scale
                guard r > 1 else { continue }
                let alpha = (1 - age / life) * (0.5 - 0.12 * Double(n)) * f.k
                g.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r * 0.8, width: r * 2, height: r * 1.6)),
                         with: .color(ring.alpha(alpha).color), lineWidth: 1.4)
            }
        }
        // Rings left by the moving pointer.
        for item in f.state.rings {
            let age = f.state.now - item.born
            let r = age * 80
            guard r > 1, age < 2.6 else { continue }
            let alpha = (1 - age / 2.6) * 0.55 * f.k
            g.stroke(Path(ellipseIn: CGRect(x: item.point.x - r, y: item.point.y - r * 0.8, width: r * 2, height: r * 1.6)),
                     with: .color(ring.alpha(alpha).color), lineWidth: 1.6)
        }
    }
}
