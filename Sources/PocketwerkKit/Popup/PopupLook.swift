import AppKit
import SwiftUI

/// Fonts and colors derived from a group style.
enum PopupLook {
    /// SwiftUI weight for an NSFont.Weight raw value.
    nonisolated static func weight(_ raw: Double) -> Font.Weight {
        switch raw {
        case ..<(-0.7): return .ultraLight
        case ..<(-0.5): return .thin
        case ..<(-0.2): return .light
        case ..<0.1: return .regular
        case ..<0.27: return .medium
        case ..<0.35: return .semibold
        case ..<0.5: return .bold
        case ..<0.6: return .heavy
        default: return .black
        }
    }

    private static var familyCache: [String: Bool] = [:]

    static func isInstalled(family: String) -> Bool {
        if let known = familyCache[family] { return known }
        let ok = NSFontManager.shared.availableMembers(ofFontFamily: family) != nil
        familyCache[family] = ok
        return ok
    }

    static func font(_ label: LabelStyle, size: CGFloat, weightBoost: Double = 0) -> Font {
        let w = weight(label.weight + weightBoost)
        if let family = label.family, !family.isEmpty, isInstalled(family: family) {
            return .custom(family, fixedSize: size).weight(w)
        }
        let design: Font.Design
        switch label.design {
        case .system: design = .default
        case .rounded: design = .rounded
        case .serif: design = .serif
        case .monospaced: design = .monospaced
        }
        return .system(size: size, weight: w, design: design)
    }

    /// Text color. Auto picks light or dark text from the background.
    static func labelColor(_ label: LabelStyle, lightText: Bool) -> Color {
        switch label.colorMode {
        case .auto: return lightText ? .white : Color(white: 0.08)
        case .white: return .white
        case .black: return .black
        case .custom: return label.color.color
        }
    }

    /// True when light text reads better on this background.
    nonisolated static func prefersLightText(_ background: Background, dark: Bool) -> Bool {
        func lum(_ c: RGBA) -> Double { 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b }
        func over(_ c: RGBA, base: Double) -> Double { lum(c) * c.a + base * (1 - c.a) }
        let base = dark ? 0.12 : 0.92
        switch background {
        case .solid(let c): return over(c, base: base) < 0.55
        case .gradient(let colors, _), .mesh(let colors):
            guard !colors.isEmpty else { return dark }
            return colors.map { over($0, base: base) }.reduce(0, +) / Double(colors.count) < 0.55
        case .glass(let tint, _): return over(tint, base: base) < 0.55
        case .texture(_, let tint): return over(tint, base: base) < 0.55
        case .fx(let p):
            if let b = p.base { return over(b, base: base) < 0.55 }
            guard !p.palette.isEmpty else { return true }
            return p.palette.map(lum).reduce(0, +) / Double(p.palette.count) < 0.6
        case .image, .wallpaper: return true
        }
    }

    /// Opaque stand-in for glass when Reduce Transparency is on.
    nonisolated static func opaque(_ background: Background, dark: Bool) -> Background {
        let base = dark ? RGBA(0.14, 0.14, 0.16) : RGBA(0.94, 0.94, 0.95)
        switch background {
        case .glass(let tint, _):
            let a = tint.a
            return .solid(RGBA(tint.r * a + base.r * (1 - a), tint.g * a + base.g * (1 - a), tint.b * a + base.b * (1 - a)))
        case .wallpaper: return .solid(base)
        default: return background
        }
    }
}
