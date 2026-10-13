import SwiftUI

/// The built-in themes and presets. Names and colors are original.
enum ThemeCatalog {
    // MARK: Building blocks

    private static func c(_ hex: String) -> RGBA { RGBA(hex: hex) }
    private static func line(_ hex: String, _ alpha: Double = 1, _ width: Double = 1) -> BorderStyle {
        BorderStyle(color: c(hex).alpha(alpha), width: width)
    }
    private static func grad(_ hexes: [String], _ width: Double = 1.5) -> BorderStyle {
        BorderStyle(color: c(hexes[0]), width: width, gradient: hexes.map(c))
    }
    private static func fx(_ kind: FXKind, _ hexes: [String], speed: Double = 1, intensity: Double = 1,
                           pointer: FXPointer = .ripple, p3: Double = 0.5, p4: Double = 0.5, p5: Double = 0.5,
                           base: String? = nil, style: Int = 0, drift: Double = 0) -> Background {
        var p = FXParams(kind: kind, palette: hexes.map(c), speed: speed, intensity: intensity, pointer: pointer)
        p.p3 = p3; p.p4 = p4; p.p5 = p5; p.style = style; p.drift = drift
        p.base = base.map(c)
        return .fx(p)
    }

    /// A complete look: popup fill, border, labels, corners and the matching Dock icon.
    private struct Look {
        var bg: Background
        var border: BorderStyle? = nil
        /// nil = automatic label color.
        var label: RGBA? = nil
        var design: FontDesignChoice = .system
        var weight: Double = 0.23
        var radius: Double = 24
        var glass: Double = 0
        var matte: Double = 0
        var hover: HoverHighlight = .subtle
        var labelShadow = true
        var backdrop = false
        var appearance: AppearanceChoice = .system
        var plate: RGBA? = nil
        var shape: IconShape = .squircle
        var glossy = true
        var lift = true
        var iconMatte: Double? = nil
        var roundItems = false

        func make(_ id: String, _ name: String, _ category: String) -> Theme {
            var s = GroupStyle()
            s.background = bg
            s.border = border
            s.cornerRadius = radius
            s.glassAmount = glass
            s.matte = matte
            s.hover = hover
            s.appearance = appearance
            s.iconPlate = plate
            s.labels.design = design
            s.labels.weight = weight
            s.labels.shadow = labelShadow
            s.labels.backdrop = backdrop
            if let label {
                s.labels.colorMode = .custom
                s.labels.color = label
                s.highlightColor = label.alpha(0.16)
            } else {
                s.labels.colorMode = .auto
            }
            var icon = IconSpec()
            icon.background = nil // match the popup
            icon.shape = shape
            icon.glossy = glossy
            icon.lift = lift
            icon.matte = iconMatte ?? matte
            icon.roundItems = roundItems
            icon.border = border.map { b in var b = b; b.width = min(b.width, 2); return b }
            icon.foreground = label ?? bg.representativeColor.readableLabel
            return Theme(id: id, name: name, style: s, icon: icon, isBuiltIn: true, category: category)
        }
    }

    // MARK: Themes

    static let themes: [Theme] = [
        // Classic
        Look(bg: .glass(tint: c("#FFFFFF").alpha(0.14), intensity: 1), radius: 26, matte: 0.2)
            .make("theme.daylight", "Daylight Glass", "Classic"),
        Look(bg: .glass(tint: c("#0B0D14").alpha(0.42), intensity: 1), label: .white, radius: 26, matte: 0.4, appearance: .dark)
            .make("theme.nightglass", "Night Glass", "Classic"),
        Look(bg: .solid(c("#24262C")), border: line("#3B3E47"), label: c("#ECEDF1"), radius: 20, glossy: false)
            .make("theme.graphite", "Graphite", "Classic"),
        Look(bg: .solid(c("#F7F5F0")), border: line("#DCD5C8"), label: c("#2F2B27"), radius: 22, labelShadow: false, appearance: .light)
            .make("theme.porcelain", "Porcelain", "Classic"),

        // Crafted
        Look(bg: .gradient(colors: [c("#132A20"), c("#2D4B37")], angle: 45), border: grad(["#A0703F", "#5B3C22"]),
             label: c("#F2EBD8"), design: .serif)
            .make("theme.pinehollow", "Pine Hollow", "Crafted"),
        Look(bg: .gradient(colors: [c("#2B2011"), c("#0F0C07")], angle: 45), border: grad(["#ECC768", "#A97B1F"]),
             label: c("#EDCD7C"), design: .serif)
            .make("theme.ambervault", "Amber Vault", "Crafted"),
        Look(bg: .gradient(colors: [c("#0F3C46"), c("#1D5F96")], angle: 45), border: line("#60D8CB"), label: c("#E0F6FF"))
            .make("theme.harbor", "Harbor Teal", "Crafted"),
        Look(bg: .gradient(colors: [c("#F48C6C"), c("#FBC48C")], angle: 45), border: line("#FFF5EC"), label: c("#47243F"),
             design: .rounded, labelShadow: false)
            .make("theme.peachhorizon", "Peach Horizon", "Crafted"),
        Look(bg: .solid(c("#FCF0EB")), border: line("#E4AEA7"), label: c("#70358A"), design: .rounded, labelShadow: false, appearance: .light)
            .make("theme.rosewater", "Rosewater", "Crafted"),
        Look(bg: .texture(name: "paper", tint: c("#F3E9D2")), border: line("#B49557"), label: c("#5F3E23"), design: .serif,
             labelShadow: false, glossy: false)
            .make("theme.scriptorium", "Scriptorium", "Crafted"),
        Look(bg: .texture(name: "knit", tint: c("#B13C4A")), label: .white, design: .rounded, weight: 0.3, radius: 28, glossy: false)
            .make("theme.cozyknit", "Cozy Knit", "Crafted"),
        Look(bg: .texture(name: "linen", tint: c("#E7E0D2")), border: line("#CFC5B3"), label: c("#3E3931"), labelShadow: false, glossy: false)
            .make("theme.linenroom", "Linen Room", "Crafted"),

        // Statement
        Look(bg: .gradient(colors: ["#E63946", "#F77F00", "#FCBF49", "#2A9D8F", "#3A86FF", "#8338EC"].map(c), angle: 45),
             border: grad(["#E63946", "#F77F00", "#FCBF49", "#2A9D8F", "#3A86FF", "#8338EC"], 2), label: .white, weight: 0.3)
            .make("theme.spectrum", "Spectrum", "Statement"),
        Look(bg: .solid(c("#070C08")), border: line("#3BE861"), label: c("#3BE861"), design: .monospaced, radius: 14,
             labelShadow: false, shape: .roundedSquare, glossy: false)
            .make("theme.phosphor", "Phosphor", "Statement"),

        // Living (animated)
        Look(bg: fx(.arcs, ["#0C0522", "#FF41A8", "#41C8FF"]), border: grad(["#FF41A8", "#41C8FF"], 1), label: .white, radius: 26)
            .make("theme.neonribbon", "Neon Ribbon", "Living"),
        Look(bg: fx(.snow, ["#1C2B4B", "#FFFFFF", "#AAC7F6"], speed: 0.9, pointer: .shove), label: .white, design: .rounded, radius: 26)
            .make("theme.quietsnow", "Quiet Snowfall", "Living"),
        Look(bg: fx(.glyphRain, ["#2CFF8A", "#D8FFE8"], pointer: .still, p4: 0.45, base: "#020805"), border: line("#2CFF8A", 0.5),
             label: c("#9CFFC4"), design: .monospaced, radius: 16, shape: .roundedSquare, glossy: false)
            .make("theme.greencascade", "Green Cascade", "Living"),
        Look(bg: fx(.blobs, ["#FF7BB8", "#7C8DFF", "#5DF3D7"], speed: 0.8), label: .white, design: .rounded, radius: 30, roundItems: true)
            .make("theme.candyclouds", "Candy Clouds", "Living"),
        Look(bg: fx(.fur, ["#DA781F", "#F5E2C3", "#1B130C"], pointer: .comb), label: .white, weight: 0.3, radius: 28, glossy: false)
            .make("theme.wildstripes", "Wild Stripes", "Living"),
        Look(bg: fx(.aurora, ["#08132A", "#3EF6A8", "#9C5DFF"], speed: 0.9), label: .white)
            .make("theme.northernveil", "Northern Veil", "Living"),
        Look(bg: fx(.embers, ["#130705", "#FF6B1B", "#FFD46C"]), border: line("#FF6B1B", 0.45), label: c("#FFE3C2"))
            .make("theme.hearth", "Hearth", "Living"),
        Look(bg: fx(.curtains, ["#7B0F20", "#C9354B", "#E9C66C"], speed: 0.8), border: grad(["#E9C66C", "#8A6420"], 1.5),
             label: c("#F6E7C8"), design: .serif)
            .make("theme.velvetstage", "Velvet Stage", "Living"),
        Look(bg: fx(.waves, ["#0C2E50", "#2080B9", "#90E4F1"], speed: 0.8), label: .white)
            .make("theme.tidelines", "Tide Lines", "Living"),
        Look(bg: fx(.marble, ["#F4F2ED", "#DAD5CB", "#4C5059"], speed: 0.8), border: line("#C9C3B8"), label: c("#2B2D33"),
             design: .serif, labelShadow: false, appearance: .light)
            .make("theme.carrara", "Carrara Flow", "Living"),
        Look(bg: fx(.starfield, ["#05060F", "#80A8FF", "#FF9CD3"]), label: .white)
            .make("theme.deepfield", "Deep Field", "Living"),
        Look(bg: fx(.rain, ["#1E2834", "#C0D5E9", "#5F7997"], drift: 0.2), label: .white)
            .make("theme.windowrain", "Window Rain", "Living"),
        Look(bg: fx(.fog, ["#5A687B", "#BAC4D0", "#F3F6F9"], speed: 0.9), label: .white, matte: 0.2)
            .make("theme.morningmist", "Morning Mist", "Living"),
        Look(bg: fx(.plasma, ["#FF5082", "#5F2CFF", "#FFC246"], speed: 0.8), label: .white, weight: 0.3, radius: 30)
            .make("theme.plasmabloom", "Plasma Bloom", "Living"),
        Look(bg: fx(.bubbles, ["#2CC5DA", "#FFFFFF", "#0B6F8D"], pointer: .shove), label: .white, design: .rounded, radius: 30, shape: .circle)
            .make("theme.sodafizz", "Soda Fizz", "Living"),
        Look(bg: fx(.ripples, ["#0F4E5D", "#208B8B", "#D0F7F1"]), label: .white)
            .make("theme.koipond", "Koi Pond", "Living"),
        Look(bg: fx(.lava, ["#3B0C2F", "#FF5F3B", "#FFCA3D"], speed: 0.9), label: c("#FFF0D6"), design: .rounded, radius: 30)
            .make("theme.lavalamp", "Lava Lamp", "Living"),
        Look(bg: fx(.driftingLight, ["#3C2B1B", "#FFC87B", "#FFF2D1"]), label: c("#FFF6E6"), design: .serif)
            .make("theme.sunbeams", "Sunbeams", "Living"),
    ]

    // MARK: Presets

    static let presets: [Theme] = glassColors + gradients + textures + livingEffects + minimal + bold

    private static func slug(_ s: String) -> String {
        s.lowercased().replacingOccurrences(of: " ", with: "-")
    }

    private static let glassColors: [Theme] = [
        ("Frost", "#F4F7FB", 0.2), ("Smoke", "#1A1C22", 0.45), ("Cobalt", "#1F5BD8", 0.3), ("Lagoon", "#11A3A6", 0.3),
        ("Sage", "#6E9C6A", 0.3), ("Citrine", "#E8C33A", 0.3), ("Apricot", "#F29A55", 0.32), ("Coral", "#F06A64", 0.32),
        ("Peony", "#E86AA8", 0.3), ("Lilac", "#9B7BEA", 0.3), ("Ink", "#0A1630", 0.5), ("Pearl", "#EDE6F2", 0.25),
    ].map { name, hex, alpha in
        Look(bg: .glass(tint: c(hex).alpha(alpha), intensity: 1), radius: 26, matte: 0.25, iconMatte: 0.3)
            .make("preset.glass.\(slug(name))", "\(name) Glass", "Glass Colors")
    }

    private static let gradients: [Theme] = {
        let list: [(String, [String], Double, Bool)] = [
            ("Dawn Peach", ["#FFB49C", "#FF7194"], 45, false),
            ("Ultramarine", ["#1C2EC4", "#52A6FF"], 45, false),
            ("Mint Julep", ["#9DE8C6", "#2F9F90"], 90, false),
            ("Ember Sky", ["#2C1257", "#D63C70", "#FF9C5C"], 0, true),
            ("Grape Soda", ["#5D257C", "#1ECFE0"], 45, false),
            ("Seafoam", ["#45CFA4", "#1A5C9F"], 135, false),
            ("Dusk Rose", ["#3B1E73", "#D86F79", "#FFB17D"], 0, true),
            ("Arctic", ["#E2F3FF", "#9ECBF4"], 90, false),
            ("Citrus", ["#FAD625", "#FF5052"], 45, false),
            ("Orchid Night", ["#160D2B", "#6C3295"], 45, false),
            ("Copper", ["#40251A", "#BA6B41"], 45, false),
            ("Moonlit", ["#112229", "#2E5566"], 90, false),
        ]
        return list.map { name, hexes, angle, mesh in
            let colors = hexes.map(c)
            let bg: Background = mesh ? .mesh(colors: colors) : .gradient(colors: colors, angle: angle)
            return Look(bg: bg, border: line("#FFFFFF", 0.22), radius: 24)
                .make("preset.gradient.\(slug(name))", name, "Gradients")
        }
    }()

    private static let textures: [Theme] = {
        let list: [(String, TextureKind, String)] = [
            ("Chunky Knit", .knit, "#2F5D8A"), ("Rice Paper", .paper, "#F5EFE2"), ("Film Grain", .noise, "#2B2E35"),
            ("Glacier", .ice, "#BCE2F3"), ("Parcel", .cardboard, "#B88A5A"), ("Flax", .linen, "#E4DCCC"),
            ("Savanna Spots", .leopard, "#DBA955"), ("Alpine Spots", .snowLeopard, "#DADAD6"), ("Striped Coat", .tiger, "#E17B24"),
            ("Terrazzo Floor", .terrazzo, "#EEE8E0"), ("Raw Denim", .denim, "#2E4877"), ("Billiard Felt", .felt, "#1E6A49"),
        ]
        return list.map { name, kind, hex in
            let tint = c(hex)
            let label = tint.readableLabel
            return Look(bg: .texture(name: kind.rawValue, tint: tint), label: label,
                        design: kind == .knit || kind == .felt ? .rounded : .system, weight: 0.3, radius: 22,
                        labelShadow: !label.isDark, backdrop: kind == .leopard || kind == .tiger || kind == .terrazzo,
                        glossy: false)
                .make("preset.texture.\(slug(name))", name, "Textures")
        }
    }()

    private static let livingEffects: [Theme] = [
        Look(bg: fx(.snow, ["#3B4A63", "#FFFFFF", "#DDE8F7"], speed: 1.2, pointer: .shove, p3: 1, drift: 0.6), label: .white)
            .make("preset.fx.blizzard", "Blizzard", "Living Effects"),
        Look(bg: fx(.embers, ["#060B16", "#3E8BFF", "#B5E3FF"]), label: c("#DCEEFF"))
            .make("preset.fx.blue-cinders", "Blue Cinders", "Living Effects"),
        Look(bg: fx(.glyphRain, ["#FFB13D", "#FFF1D6"], pointer: .still, p4: 0.35, p5: 0.7, base: "#0D0702"), label: c("#FFD08A"),
             design: .monospaced, radius: 16, glossy: false)
            .make("preset.fx.amber-code", "Amber Code", "Living Effects"),
        Look(bg: fx(.blobs, ["#FFB3D9", "#A8EBCF", "#FFE08A"], speed: 0.7, base: "#F6EEF0"), label: c("#3A2A35"), design: .rounded,
             radius: 30, labelShadow: false)
            .make("preset.fx.gelato", "Gelato", "Living Effects"),
        Look(bg: fx(.aurora, ["#030712", "#4CC9F0", "#F72585"]), label: .white)
            .make("preset.fx.midnight-aurora", "Midnight Aurora", "Living Effects"),
        Look(bg: fx(.plasma, ["#FBC2EB", "#A6C1EE", "#FDE2C4"], speed: 0.6), label: c("#2E2440"), radius: 30, labelShadow: false)
            .make("preset.fx.pastel-plasma", "Pastel Plasma", "Living Effects"),
        Look(bg: fx(.rain, ["#2A3340", "#D7E3F0", "#7D8EA3"], speed: 1.1, p3: 1, drift: 0.5), label: .white)
            .make("preset.fx.stormfront", "Stormfront", "Living Effects"),
        Look(bg: fx(.ripples, ["#0A6C74", "#3FB8AF", "#E8FFF9"], p3: 0.7), label: .white)
            .make("preset.fx.lagoon-ripples", "Lagoon Ripples", "Living Effects"),
        Look(bg: fx(.driftingLight, ["#5A2E14", "#FFB45E", "#FFE7B8"], speed: 0.8), label: c("#FFF3E0"))
            .make("preset.fx.golden-hour", "Golden Hour", "Living Effects"),
        Look(bg: fx(.waves, ["#06223D", "#0F6FA8", "#7FDBE9"], speed: 1.1, p3: 0.8), label: .white)
            .make("preset.fx.ocean-swell", "Ocean Swell", "Living Effects"),
    ]

    private static let minimal: [Theme] = {
        func plain(_ bg: Background, _ border: BorderStyle?, _ label: RGBA?, _ appearance: AppearanceChoice = .system,
                   matte: Double = 0, design: FontDesignChoice = .system, radius: Double = 14) -> Look {
            Look(bg: bg, border: border, label: label, design: design, radius: radius, matte: matte, hover: .subtle,
                 labelShadow: false, appearance: appearance, shape: .roundedSquare, glossy: false, lift: false)
        }
        return [
            plain(.solid(c("#FAFAF8")), line("#E4E4E0"), c("#1D1D1F"), .light).make("preset.min.paper-white", "Paper White", "Minimal"),
            plain(.solid(c("#D9D6D0")), nil, c("#2A2826"), .light).make("preset.min.stone", "Stone", "Minimal"),
            plain(.solid(c("#8E9196")), nil, .white).make("preset.min.ash", "Ash", "Minimal"),
            plain(.solid(c("#1C1D21")), line("#2C2E33"), c("#F2F2F4"), .dark).make("preset.min.charcoal", "Charcoal", "Minimal"),
            plain(.solid(c("#EFE6D6")), line("#DDD0B8"), c("#4A3F31"), .light).make("preset.min.oat", "Oat", "Minimal"),
            plain(.glass(tint: c("#FFFFFF").alpha(0.55), intensity: 1), nil, c("#111114"), .light, matte: 1)
                .make("preset.min.mono-light", "Mono Light", "Minimal"),
            plain(.glass(tint: c("#000000").alpha(0.6), intensity: 1), nil, .white, .dark, matte: 1)
                .make("preset.min.mono-dark", "Mono Dark", "Minimal"),
            plain(.glass(tint: .clear, intensity: 1), nil, nil, radius: 22).make("preset.min.clear", "Clear", "Minimal"),
            plain(.solid(c("#FFFFFF")), line("#000000", 0.9), c("#000000"), .light, design: .monospaced, radius: 8)
                .make("preset.min.hairline", "Hairline", "Minimal"),
        ]
    }()

    private static let bold: [Theme] = {
        func loud(_ bg: Background, _ border: [String]?, _ label: RGBA, shape: IconShape = .squircle, width: Double = 2) -> Look {
            Look(bg: bg, border: border.map { grad($0, width) }, label: label, weight: 0.4, radius: 30, hover: .heavy, shape: shape)
        }
        return [
            loud(.solid(c("#E5262E")), ["#FF8A8A", "#9E0F16"], .white).make("preset.bold.signal-red", "Signal Red", "Bold"),
            loud(.solid(c("#1D4DFF")), ["#7FD1FF", "#0A1FA8"], .white).make("preset.bold.electric-blue", "Electric Blue", "Bold"),
            loud(.solid(c("#B6F23A")), ["#F2FF8A", "#4E8F10"], c("#14210A"), shape: .circle).make("preset.bold.lime-pop", "Lime Pop", "Bold"),
            loud(.solid(c("#F0179B")), ["#FF8BD1", "#8A0A55"], .white).make("preset.bold.hot-magenta", "Hot Magenta", "Bold"),
            loud(.solid(c("#FFC51A")), ["#FFF0A0", "#C78A00"], c("#2B1D00"), shape: .circle).make("preset.bold.sunflower", "Sunflower", "Bold"),
            loud(.gradient(colors: [c("#5A12E8"), c("#2A0A7A")], angle: 45), ["#C49BFF", "#5A12E8"], .white)
                .make("preset.bold.ultraviolet", "Ultraviolet", "Bold"),
            loud(.solid(c("#FF7A1A")), nil, .white).make("preset.bold.tangerine", "Tangerine", "Bold"),
            loud(.solid(c("#0FA36B")), nil, .white).make("preset.bold.jade", "Jade", "Bold"),
            loud(.solid(c("#101014")), ["#FF2E88", "#FFD60A", "#2EF2FF"], .white, width: 3).make("preset.bold.neon-mix", "Neon Mix", "Bold"),
        ]
    }()
}
