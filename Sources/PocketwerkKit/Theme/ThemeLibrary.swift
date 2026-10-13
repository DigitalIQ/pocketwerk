import SwiftUI

/// Built-in looks. Themes are complete signature looks; presets are curated variations
/// grouped like a swatch book. Both are plain `Theme` values and apply the same way.
enum ThemeLibrary {
    static let themes: [Theme] = ThemeCatalog.themes
    static let presets: [Theme] = ThemeCatalog.presets
    /// All built-in looks: themes first, then presets.
    static let builtIn: [Theme] = themes + presets

    static let customCategory = "My Themes"

    /// Categories in gallery order.
    static let themeCategories = ["Classic", "Crafted", "Statement", "Living"]
    static let presetCategories = ["Glass Colors", "Gradients", "Textures", "Living Effects", "Minimal", "Bold"]

    struct Section: Identifiable {
        var id: String { title }
        var title: String
        var themes: [Theme]
    }

    /// Gallery sections in display order: theme categories, preset groups, then own themes.
    static func sections(custom: [Theme] = []) -> [Section] {
        var out = (themeCategories + presetCategories).map { cat in
            Section(title: cat, themes: builtIn.filter { $0.category == cat })
        }
        if !custom.isEmpty { out.append(Section(title: customCategory, themes: custom)) }
        return out
    }

    static func theme(id: String, custom: [Theme] = []) -> Theme? {
        builtIn.first { $0.id == id } ?? custom.first { $0.id == id }
    }

    /// Applies the visual parts of a theme. Layout and behavior stay with the group:
    /// view, columns, rows, paging, icon size, spacing, padding, header, label mode, indicators, scale.
    static func apply(_ theme: Theme, to style: GroupStyle) -> GroupStyle {
        var s = theme.style
        s.layout = style.layout
        s.columns = style.columns
        s.iconSize = style.iconSize
        s.spacing = style.spacing
        s.padding = style.padding
        s.maxRows = style.maxRows
        s.paged = style.paged
        s.header = style.header
        s.labels.mode = style.labels.mode
        s.runningIndicator = style.runningIndicator
        s.showPageIndicator = style.showPageIndicator
        s.popupScale = style.popupScale
        s.mirrorIcon = style.mirrorIcon
        return s
    }

    /// Applies the look of a theme icon. Keeps the content (grid, stack, symbol, emoji, text, image),
    /// the folder shape and the user's own Dock icon colors.
    static func apply(_ themeIcon: IconSpec, to icon: IconSpec) -> IconSpec {
        var i = themeIcon
        i.content = icon.content
        i.pack = icon.pack
        i.stack = icon.stack
        i.dense = icon.dense
        if icon.shape == .folder { i.shape = .folder }
        if icon.background != nil {
            i.background = icon.background
            i.foreground = icon.foreground
            i.opacity = icon.opacity
        }
        return i
    }

    /// A theme capturing the current look of a group.
    static func makeCustom(from group: ItemGroup, name: String) -> Theme {
        Theme(id: "custom.\(UUID().uuidString)", name: name, style: group.style, icon: group.icon,
              isBuiltIn: false, category: customCategory)
    }
}

// MARK: - Randomizer

enum StyleRandomizer {
    /// A random but harmonious look. Layout fields are taken from `base`.
    static func randomLook(base: GroupStyle, icon: IconSpec, seed: UInt64) -> (GroupStyle, IconSpec) {
        var rng = SeededRandom(seed: seed)
        let hue = rng.unit()
        let spread = [0.06, 0.12, 0.5, 0.33][Int(rng.unit() * 4)]
        let sat = rng.range(0.35, 0.9), bri = rng.range(0.25, 0.95)
        let palette = (0..<3).map { k in
            RGBA(hue: hue + spread * Double(k), saturation: min(1, sat + rng.range(-0.15, 0.15)),
                 brightness: min(1, max(0.08, bri + rng.range(-0.25, 0.2))))
        }
        var s = base
        let roll = rng.unit()
        switch roll {
        case ..<0.18: s.background = .glass(tint: palette[0].alpha(rng.range(0.15, 0.45)), intensity: 1)
        case ..<0.32: s.background = .solid(palette[0])
        case ..<0.56: s.background = .gradient(colors: Array(palette.prefix(2)), angle: [45, 90, 135, 0][Int(rng.unit() * 4)])
        case ..<0.7: s.background = .mesh(colors: palette)
        case ..<0.82:
            let kind = TextureKind.allCases[Int(rng.unit() * Double(TextureKind.allCases.count))]
            s.background = .texture(name: kind.rawValue, tint: rng.unit() > 0.5 ? kind.suggestedTint : palette[0])
        default:
            let kind = FXKind.allCases[Int(rng.unit() * Double(FXKind.allCases.count))]
            var p = FXParams(kind: kind, palette: palette, speed: rng.range(0.6, 1.3), intensity: rng.range(0.7, 1.2))
            p.p3 = rng.range(0.3, 0.8)
            p.pointer = kind == .snow || kind == .bubbles ? .shove : (kind == .fur ? .comb : (kind == .glyphRain ? .still : .ripple))
            s.background = .fx(p)
        }
        s.glassAmount = rng.unit() > 0.75 ? rng.range(0.2, 0.7) : 0
        s.matte = rng.unit() > 0.6 ? rng.range(0.1, 0.6) : 0
        s.opacity = 1
        s.cornerRadius = [14, 20, 24, 28, 32][Int(rng.unit() * 5)]
        switch rng.unit() {
        case ..<0.35: s.border = nil
        case ..<0.7: s.border = BorderStyle(color: palette[2].lighter(0.3).alpha(0.7), width: 1)
        default: s.border = BorderStyle(color: palette[1], width: 1.5, gradient: [palette[1].lighter(0.35), palette[2]])
        }
        s.labels.design = FontDesignChoice.allCases[Int(rng.unit() * 4)]
        s.labels.colorMode = .auto
        s.labels.shadow = rng.unit() > 0.4
        s.hover = rng.unit() > 0.5 ? .subtle : .heavy

        var i = icon
        i.background = nil
        i.shape = icon.shape == .folder ? .folder : [IconShape.squircle, .squircle, .roundedSquare, .circle][Int(rng.unit() * 4)]
        i.glossy = rng.unit() > 0.4
        i.lift = true
        i.matte = s.matte
        i.roundItems = rng.unit() > 0.75
        i.border = s.border
        return (s, i)
    }
}
