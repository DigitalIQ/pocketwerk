import AppKit
import SwiftUI

// Small color and randomness helpers shared by the Theme, Icons and Studio modules.

nonisolated extension RGBA {
    /// Relative luminance (WCAG), 0 = black, 1 = white.
    var luminance: Double {
        func lin(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }

    var isDark: Bool { luminance < 0.33 }

    func mixed(with o: RGBA, _ t: Double) -> RGBA {
        RGBA(r + (o.r - r) * t, g + (o.g - g) * t, b + (o.b - b) * t, a + (o.a - a) * t)
    }

    func lighter(_ t: Double) -> RGBA { var c = mixed(with: .white, t); c.a = a; return c }
    func darker(_ t: Double) -> RGBA { var c = mixed(with: .black, t); c.a = a; return c }
    func alpha(_ v: Double) -> RGBA { RGBA(r, g, b, v) }
    var opaque: RGBA { alpha(1) }

    /// A label color that reads well on this color.
    var readableLabel: RGBA { luminance > 0.42 ? RGBA(0.09, 0.09, 0.11) : RGBA(1, 1, 1) }

    /// Hue, saturation, brightness, all 0...1.
    init(hue: Double, saturation s: Double, brightness v: Double, alpha: Double = 1) {
        let h = (hue - floor(hue)) * 6
        let i = Int(h) % 6, f = h - floor(h)
        let p = v * (1 - s), q = v * (1 - s * f), t = v * (1 - s * (1 - f))
        let rgb: (Double, Double, Double) = switch i {
        case 0: (v, t, p)
        case 1: (q, v, p)
        case 2: (p, v, t)
        case 3: (p, q, v)
        case 4: (t, p, v)
        default: (v, p, q)
        }
        self.init(rgb.0, rgb.1, rgb.2, alpha)
    }

    static func average(_ colors: [RGBA]) -> RGBA {
        guard !colors.isEmpty else { return RGBA(0.5, 0.5, 0.5) }
        let n = Double(colors.count)
        return RGBA(colors.map(\.r).reduce(0, +) / n, colors.map(\.g).reduce(0, +) / n,
                    colors.map(\.b).reduce(0, +) / n, colors.map(\.a).reduce(0, +) / n)
    }
}

nonisolated extension Background {
    /// One opaque color that stands for this fill. Used for Reduce Transparency,
    /// the automatic label color and icons that match the theme.
    var representativeColor: RGBA {
        switch self {
        case .solid(let c): return c.opaque
        case .gradient(let colors, _), .mesh(let colors): return RGBA.average(colors).opaque
        case .image(_, let dim, _): return RGBA(0.32, 0.32, 0.34).darker(dim)
        case .glass(let tint, let intensity):
            let base = tint.isDark ? RGBA(0.14, 0.14, 0.16) : RGBA(0.93, 0.93, 0.95)
            return base.mixed(with: tint.opaque, min(1, tint.a * intensity))
        case .fx(let p): return (p.base ?? RGBA.average(p.palette)).opaque
        case .wallpaper(_, let dim): return RGBA(0.22, 0.23, 0.26).darker(dim)
        case .texture(_, let tint): return tint.opaque
        }
    }

    /// The colors a fill is made of, for previews and matching icons.
    var paletteColors: [RGBA] {
        switch self {
        case .solid(let c): return [c]
        case .gradient(let colors, _), .mesh(let colors): return colors
        case .fx(let p): return (p.base.map { [$0] } ?? []) + p.palette
        case .texture(_, let tint): return [tint]
        case .glass(let tint, _): return [tint]
        default: return [representativeColor]
        }
    }

    /// Glass and wallpaper show what is behind the popup.
    var isSeeThrough: Bool {
        switch self {
        case .glass, .wallpaper: return true
        default: return false
        }
    }

    var isAnimated: Bool {
        switch self {
        case .fx: return true
        case .texture(let name, _): return TextureKind.hasSnow(name)
        default: return false
        }
    }

    /// The brightest color of the fill, lifted a little. Used for the glow tuning.
    var glowColor: RGBA {
        let best = paletteColors.max { $0.luminance < $1.luminance } ?? .white
        return best.opaque.lighter(0.35)
    }

    /// Short name of the fill type, for the inspector and VoiceOver.
    var kindName: String {
        switch self {
        case .solid: return String(localized: "Color")
        case .gradient: return String(localized: "Gradient")
        case .mesh: return String(localized: "Mesh")
        case .image: return String(localized: "Photo")
        case .glass: return String(localized: "Glass")
        case .fx: return String(localized: "Effect")
        case .wallpaper: return String(localized: "Wallpaper")
        case .texture: return String(localized: "Texture")
        }
    }
}

extension LabelStyle {
    /// The label color a popup should use on a given fill.
    func resolvedColor(on background: Background, dark: Bool) -> RGBA {
        switch colorMode {
        case .white: return .white
        case .black: return RGBA(0.08, 0.08, 0.1)
        case .custom: return color
        case .auto:
            if background.isSeeThrough { return dark ? .white : RGBA(0.08, 0.08, 0.1) }
            return background.representativeColor.readableLabel
        }
    }

    var fontDesign: Font.Design {
        switch design {
        case .system: return .default
        case .rounded: return .rounded
        case .serif: return .serif
        case .monospaced: return .monospaced
        }
    }
}

/// Deterministic random numbers (SplitMix64), so textures and randomized looks are reproducible.
nonisolated struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    init(string: String) {
        var h: UInt64 = 0xCBF2_9CE4_8422_2325
        for b in string.utf8 { h = (h ^ UInt64(b)) &* 0x100_0000_01B3 }
        state = h
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// 0..<1
    mutating func unit() -> Double { Double(next() >> 11) / Double(UInt64(1) << 53) }
    mutating func range(_ a: Double, _ b: Double) -> Double { a + (b - a) * unit() }
}

/// Stable pseudo random value 0..<1 for an index, used for per-particle constants without storing them.
nonisolated func hash01(_ i: Int, _ salt: Int = 0) -> Double {
    var x = UInt64(bitPattern: Int64(i &* 374_761_393 &+ salt &* 668_265_263))
    x = (x ^ (x >> 33)) &* 0xFF51_AFD7_ED55_8CCD
    x = (x ^ (x >> 33)) &* 0xC4CE_B9FE_1A85_EC53
    x ^= x >> 33
    return Double(x >> 11) / Double(UInt64(1) << 53)
}
