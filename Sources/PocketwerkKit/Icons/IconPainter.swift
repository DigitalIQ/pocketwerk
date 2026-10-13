import AppKit
import CoreImage
import SwiftUI

/// Draws one composed icon into a bitmap context (y up). Used by `IconRenderer` only.
struct IconPainter {
    let ctx: CGContext
    let canvas: CGFloat
    let spec: IconSpec
    let style: GroupStyle
    let name: String
    let items: [DockItem]

    private static let ciContext = CIContext(options: [.cacheIntermediates: false])

    /// The artwork square, 0.832 of the canvas, centered.
    var art: CGRect {
        let edge = (canvas * IconRenderer.artScale).rounded()
        return CGRect(x: (canvas - edge) / 2, y: (canvas - edge) / 2, width: edge, height: edge)
    }

    var background: Background { spec.background ?? style.background }

    func paint() {
        let a = art
        if spec.shape == .folder {
            let back = Self.folderBack(in: a), front = Self.folderFront(in: a)
            plate(back, darken: 0.18, highlight: false)
            plate(front, darken: 0, highlight: true)
            content(in: front.boundingBox, clip: front)
        } else if let path = Self.shapePath(spec.shape, in: a) {
            plate(path, darken: 0, highlight: true)
            content(in: a, clip: path)
        } else {
            content(in: a, clip: nil)
        }
    }

    // MARK: Shapes

    static func shapePath(_ shape: IconShape, in r: CGRect) -> CGPath? {
        switch shape {
        case .squircle:
            return RoundedRectangle(cornerRadius: r.width * IconRenderer.cornerRatio, style: .continuous).path(in: r).cgPath
        case .roundedSquare:
            return CGPath(roundedRect: r, cornerWidth: r.width * 0.13, cornerHeight: r.width * 0.13, transform: nil)
        case .square:
            return CGPath(roundedRect: r, cornerWidth: r.width * 0.035, cornerHeight: r.width * 0.035, transform: nil)
        case .circle:
            return CGPath(ellipseIn: r, transform: nil)
        case .folder:
            return folderBack(in: r).union(folderFront(in: r))
        case .none:
            return nil
        }
    }

    /// Back panel with the tab, in y-up coordinates.
    static func folderBack(in r: CGRect) -> CGPath {
        let w = r.width, h = r.height
        let body = RoundedRectangle(cornerRadius: w * 0.09, style: .continuous)
            .path(in: CGRect(x: r.minX, y: r.minY + h * 0.06, width: w, height: h * 0.78)).cgPath
        let tab = RoundedRectangle(cornerRadius: w * 0.06, style: .continuous)
            .path(in: CGRect(x: r.minX, y: r.minY + h * 0.6, width: w * 0.44, height: h * 0.32)).cgPath
        return body.union(tab)
    }

    /// Front panel, a little lower than the back so the tab shows.
    static func folderFront(in r: CGRect) -> CGPath {
        let w = r.width, h = r.height
        return RoundedRectangle(cornerRadius: w * 0.09, style: .continuous)
            .path(in: CGRect(x: r.minX, y: r.minY + h * 0.06, width: w, height: h * 0.7)).cgPath
    }

    // MARK: Plate

    private func plate(_ path: CGPath, darken: Double, highlight: Bool) {
        let edge = path.boundingBox.width
        ctx.saveGState()
        if spec.lift {
            ctx.setShadow(offset: CGSize(width: 0, height: -canvas * 0.012), blur: canvas * 0.035,
                          color: RGBA.black.alpha(0.32 * spec.opacity).cgColor)
        }
        ctx.setAlpha(min(1, max(0.02, spec.opacity)))
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        ctx.addPath(path)
        ctx.clip()
        BackgroundPainter.paint(background, in: ctx, rect: path.boundingBox, canvas: canvas)
        if darken > 0 {
            ctx.setFillColor(RGBA.black.alpha(darken).cgColor)
            ctx.fill(path.boundingBox)
        }
        if spec.matte > 0.01 {
            ctx.setFillColor(RGBA.white.alpha(0.1 * spec.matte).cgColor)
            ctx.fill(path.boundingBox)
            if let grain = TextureFactory.grain {
                ctx.saveGState()
                ctx.setBlendMode(.overlay)
                ctx.setAlpha(min(1, spec.matte * 0.7))
                ctx.draw(grain, in: CGRect(x: 0, y: 0, width: canvas * 0.4, height: canvas * 0.4), byTiling: true)
                ctx.restoreGState()
            }
        }
        if spec.glossy && highlight {
            let r = path.boundingBox
            let gloss = CGGradient(colorsSpace: nil, colors: [RGBA.white.alpha(0.34).cgColor, RGBA.white.alpha(0.06).cgColor,
                                                              RGBA.white.alpha(0).cgColor] as CFArray, locations: [0, 0.35, 0.55])!
            ctx.drawLinearGradient(gloss, start: CGPoint(x: r.midX, y: r.maxY), end: CGPoint(x: r.midX, y: r.minY), options: [])
            // Thin inner rim, bright at the top.
            ctx.addPath(path)
            ctx.setLineWidth(max(1, edge * 0.008))
            ctx.replacePathWithStrokedPath()
            ctx.clip()
            let rim = CGGradient(colorsSpace: nil, colors: [RGBA.white.alpha(0.5).cgColor, RGBA.white.alpha(0.05).cgColor] as CFArray,
                                 locations: [0, 1])!
            ctx.drawLinearGradient(rim, start: CGPoint(x: r.midX, y: r.maxY), end: CGPoint(x: r.midX, y: r.minY), options: [])
        }
        ctx.endTransparencyLayer()
        ctx.restoreGState()
        if let border = spec.border, border.width > 0, highlight {
            stroke(path, border: border, edge: edge)
        }
    }

    private func stroke(_ path: CGPath, border: BorderStyle, edge: CGFloat) {
        // Border width is given in points for a ~64 pt tile; scale with the icon.
        let width = max(1, CGFloat(border.width) * edge / 64 * 1.4)
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        ctx.addPath(path)
        ctx.setLineWidth(width * 2) // half falls outside the clip: an inner border
        ctx.replacePathWithStrokedPath()
        ctx.clip()
        let r = path.boundingBox
        if let colors = border.gradient, colors.count >= 2 {
            let g = CGGradient(colorsSpace: nil, colors: colors.map(\.cgColor) as CFArray, locations: nil)!
            ctx.drawLinearGradient(g, start: CGPoint(x: r.minX, y: r.maxY), end: CGPoint(x: r.maxX, y: r.minY), options: [])
        } else {
            ctx.setFillColor(border.color.cgColor)
            ctx.fill(r)
        }
        ctx.restoreGState()
    }

    // MARK: Content

    private func content(in rect: CGRect, clip: CGPath?) {
        ctx.saveGState()
        if let clip { ctx.addPath(clip); ctx.clip() }
        switch spec.content {
        case .itemGrid(let count):
            grid(in: rect, count: count)
        case .itemStack:
            stack(in: rect)
        case .symbol(let symbol):
            self.symbol(symbol, in: rect)
        case .emoji(let emoji):
            text(emoji.isEmpty ? "🙂" : String(emoji.prefix(2)), in: rect, emoji: true)
        case .text(let word):
            text(word.isEmpty ? name : word, in: rect, emoji: false)
        case .monogram:
            text(Self.monogram(name), in: rect, emoji: false)
        case .image(let path):
            ownImage(path, in: rect, fill: clip != nil)
        }
        ctx.restoreGState()
    }

    /// First letters of the first two words, upper case.
    static func monogram(_ name: String) -> String {
        let words = name.split { !$0.isLetter && !$0.isNumber }
        let letters = words.prefix(2).compactMap(\.first).map { String($0).uppercased() }
        return letters.isEmpty ? "•" : letters.joined()
    }

    /// Grid size for a requested count: 0 = auto from the item count.
    static func gridDimension(count: Int, items: Int) -> Int {
        let n = count == 0 ? items : count
        if n <= 4 { return 2 }
        if n <= 9 { return 3 }
        return 4
    }

    private func grid(in rect: CGRect, count: Int) {
        let dim = Self.gridDimension(count: count, items: items.count)
        let inner = spec.shape == .none ? rect : rect.insetBy(dx: rect.width * 0.15, dy: rect.height * 0.15)
        let edge = min(inner.width, inner.height)
        let gap = edge * (spec.dense ? 0.035 : 0.075)
        let cell = (edge - gap * CGFloat(dim - 1)) / CGFloat(dim)
        let origin = CGPoint(x: inner.midX - edge / 2, y: inner.midY + edge / 2)
        for k in 0..<(dim * dim) {
            let row = k / dim, col = k % dim
            let r = CGRect(x: origin.x + CGFloat(col) * (cell + gap), y: origin.y - CGFloat(row + 1) * cell - CGFloat(row) * gap,
                           width: cell, height: cell)
            if k < items.count {
                drawItem(items[k], in: r)
            } else {
                ctx.setFillColor(spec.foreground.alpha(0.14).cgColor)
                let p = spec.roundItems ? CGPath(ellipseIn: r.insetBy(dx: cell * 0.06, dy: cell * 0.06), transform: nil)
                    : RoundedRectangle(cornerRadius: cell * 0.22, style: .continuous).path(in: r.insetBy(dx: cell * 0.06, dy: cell * 0.06)).cgPath
                ctx.addPath(p)
                ctx.fillPath()
            }
        }
    }

    private func drawItem(_ item: DockItem, in r: CGRect) {
        let icon = ItemIconCache.shared.baseIcon(for: item)
        if spec.roundItems {
            ctx.saveGState()
            ctx.addEllipse(in: r)
            ctx.clip()
            // App icons carry their own margin; zoom so the circle is filled.
            icon.draw(in: r.insetBy(dx: -r.width * 0.2, dy: -r.height * 0.2), from: .zero, operation: .sourceOver, fraction: 1)
            ctx.restoreGState()
        } else {
            icon.draw(in: r.insetBy(dx: -r.width * 0.06, dy: -r.height * 0.06), from: .zero, operation: .sourceOver, fraction: 1)
        }
    }

    private func stack(in rect: CGRect) {
        let opts = spec.stack
        let depth = min(4, max(2, opts.depth))
        var list = items
        if opts.shuffle {
            var rng = SeededRandom(string: name)
            list.shuffle(using: &rng)
        }
        let inner = rect.insetBy(dx: rect.width * 0.1, dy: rect.height * 0.1)
        let edge = min(inner.width, inner.height)
        let card = edge * CGFloat(min(1, max(0.4, opts.scale)))
        let step = edge * CGFloat(min(0.3, max(0.02, opts.spacing)))
        let dir: CGVector = switch opts.direction {
        case .downRight: CGVector(dx: 1, dy: -1)
        case .down: CGVector(dx: 0, dy: -1)
        case .downLeft: CGVector(dx: -1, dy: -1)
        }
        let span = step * CGFloat(depth - 1)
        let frontCenter = CGPoint(x: inner.midX - dir.dx * span / 2, y: inner.midY - dir.dy * span / 2)
        for k in stride(from: depth - 1, through: 0, by: -1) {
            let shrink = 1 - CGFloat(k) * 0.06
            let size = card * shrink
            let c = CGPoint(x: frontCenter.x + dir.dx * step * CGFloat(k), y: frontCenter.y + dir.dy * step * CGFloat(k))
            let r = CGRect(x: c.x - size / 2, y: c.y - size / 2, width: size, height: size)
            let alpha = opts.fade ? 1 - CGFloat(k) * 0.22 : 1
            ctx.saveGState()
            ctx.setAlpha(alpha)
            ctx.setShadow(offset: CGSize(width: 0, height: -size * 0.03), blur: size * 0.08, color: RGBA.black.alpha(0.3).cgColor)
            if k < list.count {
                let icon = ItemIconCache.shared.baseIcon(for: list[k])
                if opts.blur && k > 0, let blurred = blur(icon, pixels: Int(size), sigma: Double(size) * 0.025 * Double(k)) {
                    ctx.draw(blurred, in: r)
                } else {
                    icon.draw(in: r, from: .zero, operation: .sourceOver, fraction: 1)
                }
            } else {
                ctx.setFillColor(spec.foreground.alpha(0.25).cgColor)
                ctx.addPath(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous).path(in: r.insetBy(dx: size * 0.1, dy: size * 0.1)).cgPath)
                ctx.fillPath()
            }
            ctx.restoreGState()
        }
    }

    private func blur(_ image: NSImage, pixels: Int, sigma: Double) -> CGImage? {
        var rect = CGRect(x: 0, y: 0, width: pixels, height: pixels)
        guard pixels > 0, let cg = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { return nil }
        let ci = CIImage(cgImage: cg)
        let out = ci.clampedToExtent().applyingGaussianBlur(sigma: sigma).cropped(to: ci.extent)
        return Self.ciContext.createCGImage(out, from: ci.extent)
    }

    private func symbol(_ symbolName: String, in rect: CGRect) {
        let pack = IconPacks.pack(id: spec.pack)
        let edge = min(rect.width, rect.height)
        let pointSize = edge * 0.42
        let fg = spec.foreground
        var config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
        switch pack.finish {
        case .flat, .embossed: config = config.applying(.init(paletteColors: [fg.nsColor]))
        case .duotone: config = config.applying(.init(hierarchicalColor: fg.nsColor))
        case .multicolor: config = config.applying(.init(hierarchicalColor: fg.nsColor)).applying(.preferringMulticolor())
        }
        guard let base = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
                ?? NSImage(systemSymbolName: "questionmark", accessibilityDescription: nil),
              let img = base.withSymbolConfiguration(config) else { return }
        let s = img.size
        let fit = min(1, edge * 0.62 / max(s.width, s.height))
        let r = CGRect(x: rect.midX - s.width * fit / 2, y: rect.midY - s.height * fit / 2, width: s.width * fit, height: s.height * fit)
        if pack.finish == .embossed {
            // Raised look: a soft shadow, then a light-to-dark gradient inside the symbol.
            ctx.saveGState()
            ctx.setShadow(offset: CGSize(width: 0, height: -edge * 0.018), blur: edge * 0.03, color: RGBA.black.alpha(0.35).cgColor)
            ctx.beginTransparencyLayer(auxiliaryInfo: nil)
            img.draw(in: r)
            ctx.setBlendMode(.sourceIn)
            let g = CGGradient(colorsSpace: nil, colors: [fg.lighter(0.45).cgColor, fg.cgColor, fg.darker(0.25).cgColor] as CFArray,
                               locations: [0, 0.5, 1])!
            ctx.drawLinearGradient(g, start: CGPoint(x: r.midX, y: r.maxY), end: CGPoint(x: r.midX, y: r.minY), options: [])
            ctx.endTransparencyLayer()
            ctx.restoreGState()
        } else {
            ctx.saveGState()
            ctx.setShadow(offset: CGSize(width: 0, height: -edge * 0.01), blur: edge * 0.02, color: RGBA.black.alpha(0.18).cgColor)
            img.draw(in: r)
            ctx.restoreGState()
        }
    }

    private func text(_ string: String, in rect: CGRect, emoji: Bool) {
        let edge = min(rect.width, rect.height)
        var size = edge * (emoji ? 0.5 : 0.42)
        func font(_ s: CGFloat) -> NSFont {
            let f = NSFont.systemFont(ofSize: s, weight: emoji ? .regular : .heavy)
            return f.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: s) } ?? f
        }
        var attrs: [NSAttributedString.Key: Any] = [.font: font(size), .foregroundColor: spec.foreground.nsColor]
        var measured = (string as NSString).size(withAttributes: attrs)
        let maxWidth = edge * 0.78
        if measured.width > maxWidth {
            size *= maxWidth / measured.width
            attrs[.font] = font(size)
            measured = (string as NSString).size(withAttributes: attrs)
        }
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -edge * 0.012), blur: edge * 0.025, color: RGBA.black.alpha(emoji ? 0.25 : 0.2).cgColor)
        (string as NSString).draw(at: CGPoint(x: rect.midX - measured.width / 2, y: rect.midY - measured.height / 2), withAttributes: attrs)
        ctx.restoreGState()
    }

    private func ownImage(_ path: String, in rect: CGRect, fill: Bool) {
        guard let img = OwnImageCache.image(path) else {
            symbol("photo", in: rect)
            return
        }
        let s = img.size
        guard s.width > 0, s.height > 0 else { return }
        let scale = fill ? max(rect.width / s.width, rect.height / s.height) : min(rect.width / s.width, rect.height / s.height)
        let r = CGRect(x: rect.midX - s.width * scale / 2, y: rect.midY - s.height * scale / 2, width: s.width * scale, height: s.height * scale)
        img.draw(in: r, from: .zero, operation: .sourceOver, fraction: 1)
    }
}

/// Own images used as icons, loaded once.
enum OwnImageCache {
    private static var images: [String: NSImage] = [:]

    static func image(_ path: String) -> NSImage? {
        if let hit = images[path] { return hit }
        guard let img = NSImage(contentsOfFile: path) else { return nil }
        if images.count > 32 { images.removeAll() }
        images[path] = img
        return img
    }
}

// MARK: - Background painting (static, for icons and thumbnails)

/// Paints a `Background` into a CGContext without animation: the picture an icon shows when it matches the theme.
enum BackgroundPainter {
    static func paint(_ bg: Background, in ctx: CGContext, rect r: CGRect, canvas: CGFloat) {
        switch bg {
        case .solid(let c):
            ctx.setFillColor(c.cgColor)
            ctx.fill(r)
        case .gradient(let colors, let angle):
            linear(colors, angle: angle, ctx, r)
        case .mesh(let colors):
            mesh(colors, ctx, r)
        case .glass(let tint, let intensity):
            let amount = min(1, tint.a * intensity)
            let base = amount < 0.05 || !tint.isDark ? RGBA(0.86, 0.88, 0.92) : RGBA(0.2, 0.21, 0.24)
            let c = base.mixed(with: tint.opaque, amount * 0.85)
            linear([c.lighter(0.12), c, c.darker(0.08)], angle: 90, ctx, r)
        case .fx(let p):
            let colors = p.palette.isEmpty ? [RGBA.white] : p.palette
            let base = p.base ?? colors[0].darker(p.kind == .marble || p.kind == .fog ? 0 : 0.35)
            ctx.setFillColor(base.cgColor)
            ctx.fill(r)
            glows(colors + [colors[0]], ctx, r, alpha: 0.75)
        case .wallpaper(_, let dim):
            linear([RGBA(0.34, 0.4, 0.5), RGBA(0.18, 0.2, 0.26)].map { $0.darker(dim) }, angle: 90, ctx, r)
        case .texture(let name, let tint):
            if let tile = TextureFactory.tile(TextureKind(name: name), tint: tint) {
                let edge = max(8, canvas * 0.42)
                ctx.saveGState()
                ctx.clip(to: r)
                ctx.draw(tile, in: CGRect(x: r.minX, y: r.minY, width: edge, height: edge), byTiling: true)
                ctx.restoreGState()
            } else {
                ctx.setFillColor(tint.cgColor)
                ctx.fill(r)
            }
        case .image(let path, let dim, _):
            ctx.setFillColor(RGBA(0.3, 0.3, 0.32).cgColor)
            ctx.fill(r)
            if let img = OwnImageCache.image(path) {
                let s = img.size
                let scale = max(r.width / max(1, s.width), r.height / max(1, s.height))
                img.draw(in: CGRect(x: r.midX - s.width * scale / 2, y: r.midY - s.height * scale / 2,
                                    width: s.width * scale, height: s.height * scale))
            }
            ctx.setFillColor(RGBA.black.alpha(dim).cgColor)
            ctx.fill(r)
        }
    }

    /// angle: 0 = left to right, 90 = top to bottom (screen space).
    static func linear(_ colors: [RGBA], angle: Double, _ ctx: CGContext, _ r: CGRect) {
        guard colors.count > 1 else {
            ctx.setFillColor((colors.first ?? .black).cgColor)
            ctx.fill(r)
            return
        }
        let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors.map(\.cgColor) as CFArray, locations: nil)!
        let rad = angle * .pi / 180
        let dx = cos(rad) * r.width / 2, dy = -sin(rad) * r.height / 2 // y up
        ctx.drawLinearGradient(g, start: CGPoint(x: r.midX - dx, y: r.midY - dy), end: CGPoint(x: r.midX + dx, y: r.midY + dy),
                               options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }

    static func mesh(_ colors: [RGBA], _ ctx: CGContext, _ r: CGRect) {
        guard colors.count > 1 else { linear(colors, angle: 0, ctx, r); return }
        let laid = MeshFill.layout(colors)
        ctx.setFillColor(RGBA.average(colors).cgColor)
        ctx.fill(r)
        for (i, p) in MeshFill.points.enumerated() {
            let c = CGPoint(x: r.minX + CGFloat(p.x) * r.width, y: r.maxY - CGFloat(p.y) * r.height)
            radial(laid[i], at: c, radius: r.width * 0.62, alpha: 1, ctx)
        }
    }

    static func glows(_ colors: [RGBA], _ ctx: CGContext, _ r: CGRect, alpha: Double) {
        let spots: [CGPoint] = [CGPoint(x: 0.2, y: 0.25), CGPoint(x: 0.8, y: 0.35), CGPoint(x: 0.45, y: 0.8), CGPoint(x: 0.9, y: 0.9)]
        for (i, s) in spots.enumerated() where i < colors.count {
            radial(colors[i], at: CGPoint(x: r.minX + s.x * r.width, y: r.minY + s.y * r.height), radius: r.width * 0.55, alpha: alpha, ctx)
        }
    }

    static func radial(_ color: RGBA, at c: CGPoint, radius: CGFloat, alpha: Double, _ ctx: CGContext) {
        let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                           colors: [color.alpha(alpha).cgColor, color.alpha(0).cgColor] as CFArray, locations: [0, 1])!
        ctx.drawRadialGradient(g, startCenter: c, startRadius: 0, endCenter: c, endRadius: radius, options: [])
    }
}
