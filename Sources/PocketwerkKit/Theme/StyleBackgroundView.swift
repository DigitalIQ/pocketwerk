import SwiftUI

/// Renders a `Background` as a SwiftUI view, clipped by the caller.
/// `pointer` is the pointer location in the view's coordinate space (nil = read the real pointer).
/// `isActive` false means the popup is hidden: animations pause.
///
/// Glass amount, matte and opacity come from `GroupStyle`; use `init(style:)` to pass them all.
/// Under Reduce Transparency every see-through fill turns into an opaque color.
struct StyleBackgroundView: View {
    var background: Background
    var pointer: CGPoint? = nil
    var isActive: Bool = true
    /// Extra Liquid Glass over any fill, 0...1.
    var glassAmount: Double = 0
    /// 0 = clear, 1 = fully frosted.
    var matte: Double = 0
    /// Opacity of the fill, 0...1. Below 1 the fill becomes tinted glass.
    var opacity: Double = 1
    /// Used for the glass shape and its rim light.
    var cornerRadius: Double = 24
    /// Soft light along the edges, 0...1.
    var glow: Double = 0
    /// Bevel: light from the top, shade at the bottom, 0...1.
    var depth: Double = 0

    @Environment(\.accessibilityReduceTransparency) private var systemReduceTransparency
    @Environment(\.forceOpaqueBackgrounds) private var forceOpaque
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.colorScheme) private var scheme

    init(background: Background, pointer: CGPoint? = nil, isActive: Bool = true,
         glassAmount: Double = 0, matte: Double = 0, opacity: Double = 1, cornerRadius: Double = 24,
         glow: Double = 0, depth: Double = 0) {
        self.background = background
        self.glow = glow
        self.depth = depth
        self.pointer = pointer
        self.isActive = isActive
        self.glassAmount = glassAmount
        self.matte = matte
        self.opacity = opacity
        self.cornerRadius = cornerRadius
    }

    init(style: GroupStyle, pointer: CGPoint? = nil, isActive: Bool = true) {
        self.init(background: style.background, pointer: pointer, isActive: isActive, glassAmount: style.glassAmount,
                  matte: style.matte, opacity: style.opacity, cornerRadius: style.cornerRadius,
                  glow: style.glow, depth: style.depth)
    }

    private var reduceTransparency: Bool { systemReduceTransparency || forceOpaque }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: cornerRadius, style: .continuous) }
    private var isGlass: Bool { if case .glass = background { true } else { false } }
    private var clampedOpacity: Double { min(1, max(0, opacity)) }
    private var clampedGlass: Double { min(1, max(0, glassAmount)) }

    var body: some View {
        if reduceTransparency {
            opaqueFill
        } else {
            ZStack {
                if !isGlass && (clampedGlass > 0 || clampedOpacity < 1) {
                    GlassPane(shape: shape, matte: matte)
                }
                fill
                    .opacity(isGlass ? 1 : clampedOpacity * (1 - 0.5 * clampedGlass))
                if matte > 0.01 && !isGlass {
                    MatteFrost(amount: matte)
                }
                let rim = (isGlass ? 1 : clampedGlass) * (contrast == .increased ? 1.6 : 1)
                if rim > 0.01 {
                    GlassRim(shape: shape, strength: rim)
                }
                if glow > 0.01 || depth > 0.01 {
                    SurfaceTuning(shape: shape, glow: glow, depth: depth, color: background.glowColor)
                }
            }
        }
    }

    @ViewBuilder private var fill: some View {
        switch background {
        case .solid(let c):
            c.color
        case .gradient(let colors, let angle):
            LinearGradient(colors: colors.map(\.color), startPoint: UnitPoint.from(angle: angle, end: false),
                           endPoint: UnitPoint.from(angle: angle, end: true))
        case .mesh(let colors):
            MeshFill(colors: colors)
        case .image(let path, let dim, let blur):
            PhotoFill(path: path, dim: dim, blur: blur)
        case .glass(let tint, let intensity):
            GlassFill(shape: shape, tint: tint, intensity: intensity * clampedOpacity, matte: matte,
                      boost: contrast == .increased ? 1.5 : 1)
        case .fx(let params):
            FXView(params: params, pointer: pointer, isActive: isActive)
        case .wallpaper(let blur, let dim):
            WallpaperFill(blur: blur, dim: dim)
        case .texture(let name, let tint):
            ZStack {
                TextureFill(kind: TextureKind(name: name), tint: tint)
                if TextureKind.hasSnow(name) {
                    FXView(params: TextureKind.snowOverlay, pointer: pointer, isActive: isActive)
                }
            }
        }
    }

    /// Reduce Transparency: glass and wallpaper become a solid color that follows light/dark mode.
    @ViewBuilder private var opaqueFill: some View {
        switch background {
        case .glass(let tint, let intensity):
            let base = scheme == .dark ? RGBA(0.15, 0.15, 0.17) : RGBA(0.94, 0.94, 0.95)
            base.mixed(with: tint.opaque, min(1, tint.a * intensity)).opaque.color
        case .wallpaper:
            (scheme == .dark ? RGBA(0.16, 0.16, 0.18) : RGBA(0.9, 0.9, 0.92)).color
        case .solid(let c):
            c.opaque.color
        default:
            fill
        }
    }
}

extension EnvironmentValues {
    /// Renders backgrounds as if Reduce Transparency were on (previews and tests).
    @Entry var forceOpaqueBackgrounds = false
}

extension UnitPoint {
    /// 0 degrees = left to right, 90 = top to bottom.
    static func from(angle: Double, end: Bool) -> UnitPoint {
        let rad = angle * .pi / 180
        let dx = cos(rad) / 2, dy = sin(rad) / 2
        return end ? UnitPoint(x: 0.5 + dx, y: 0.5 + dy) : UnitPoint(x: 0.5 - dx, y: 0.5 - dy)
    }
}

// MARK: - Glass

/// Liquid Glass in a shape. Matte above one half uses the frosted variant plus a material veil.
struct GlassPane: View {
    var shape: RoundedRectangle
    var matte: Double

    var body: some View {
        ZStack {
            Color.clear
                .glassEffect(matte >= 0.5 ? .regular : .clear, in: shape)
            if matte > 0.01 {
                shape.fill(.ultraThinMaterial).opacity(min(1, matte * 0.85))
            }
        }
    }
}

/// `Background.glass`: glass with a tint laid over it.
struct GlassFill: View {
    var shape: RoundedRectangle
    var tint: RGBA
    var intensity: Double
    var matte: Double
    var boost: Double = 1

    var body: some View {
        ZStack {
            GlassPane(shape: shape, matte: matte)
            shape.fill(tint.alpha(min(1, tint.a * intensity * boost)).color)
            // Soft vertical sheen, like light falling on glass from above.
            shape.fill(LinearGradient(colors: [.white.opacity(0.07), .clear, .black.opacity(0.05)],
                                      startPoint: .top, endPoint: .bottom))
        }
    }
}

/// Rim light: a 1 pt inner highlight, bright at the top left and fading around the edge.
struct GlassRim: View {
    var shape: RoundedRectangle
    var strength: Double

    var body: some View {
        let s = min(1.6, strength)
        shape.strokeBorder(
            LinearGradient(stops: [
                .init(color: .white.opacity(0.55 * s), location: 0),
                .init(color: .white.opacity(0.08 * s), location: 0.45),
                .init(color: .white.opacity(0.04 * s), location: 0.7),
                .init(color: .white.opacity(0.22 * s), location: 1),
            ], startPoint: UnitPoint.from(angle: 70, end: false), endPoint: UnitPoint.from(angle: 70, end: true)),
            lineWidth: 1
        )
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
    }
}

/// Glow and depth tuning on top of any fill.
struct SurfaceTuning: View {
    var shape: RoundedRectangle
    var glow: Double
    var depth: Double
    var color: RGBA

    var body: some View {
        ZStack {
            if depth > 0.01 {
                // Bevel: a lit top edge and a shaded bottom, like a pressed card.
                shape.fill(LinearGradient(stops: [
                    .init(color: .white.opacity(0.16 * depth), location: 0),
                    .init(color: .clear, location: 0.3),
                    .init(color: .clear, location: 0.65),
                    .init(color: .black.opacity(0.34 * depth), location: 1),
                ], startPoint: .top, endPoint: .bottom))
                shape.strokeBorder(.black.opacity(0.45 * depth), lineWidth: 6)
                    .blur(radius: 5)
                    .clipShape(shape)
            }
            if glow > 0.01 {
                shape.strokeBorder(color.color.opacity(min(1, 0.9 * glow)), lineWidth: 4 + 10 * glow)
                    .blur(radius: 6 + 10 * glow)
                    .clipShape(shape)
                    .blendMode(.plusLighter)
            }
        }
        .allowsHitTesting(false)
    }
}

/// Matte over an opaque fill: a light veil and fine grain.
struct MatteFrost: View {
    var amount: Double

    var body: some View {
        ZStack {
            Color.white.opacity(0.07 * amount)
            TextureFill(kind: .noise, tint: RGBA(0.5, 0.5, 0.5))
                .blendMode(.overlay)
                .opacity(min(1, amount * 0.6))
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Mesh

/// `Background.mesh`: a soft 3x3 mesh gradient from 2-9 colors.
struct MeshFill: View {
    var colors: [RGBA]

    var body: some View {
        if colors.count < 2 {
            (colors.first ?? .black).color
        } else {
            MeshGradient(width: 3, height: 3, points: Self.points, colors: Self.layout(colors).map(\.color))
        }
    }

    static let points: [SIMD2<Float>] = [
        [0, 0], [0.5, 0], [1, 0],
        [0, 0.5], [0.62, 0.42], [1, 0.5],
        [0, 1], [0.5, 1], [1, 1],
    ]

    /// Spreads the colors over the nine mesh points: first color top left, last bottom right.
    static func layout(_ colors: [RGBA]) -> [RGBA] {
        if colors.count >= 9 { return Array(colors.prefix(9)) }
        let order = [0, 1, 3, 4, 2, 6, 5, 7, 8] // diagonal order
        var out = Array(repeating: colors[0], count: 9)
        for (rank, idx) in order.enumerated() {
            let t = Double(rank) / 8 * Double(colors.count - 1)
            let lo = Int(t), hi = min(colors.count - 1, lo + 1)
            out[idx] = colors[lo].mixed(with: colors[hi], t - Double(lo))
        }
        return out
    }
}

// MARK: - Border and surface

/// The border of a group style: one color or a 135 degree gradient.
struct StyleBorderView: View {
    var border: BorderStyle?
    var cornerRadius: Double

    var body: some View {
        if let border, border.width > 0 {
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            if let colors = border.gradient, colors.count >= 2 {
                shape.strokeBorder(LinearGradient(colors: colors.map(\.color), startPoint: UnitPoint.from(angle: 45, end: false),
                                                  endPoint: UnitPoint.from(angle: 45, end: true)), lineWidth: border.width)
            } else {
                shape.strokeBorder(border.color.color, lineWidth: border.width)
            }
        }
    }
}

extension View {
    /// Background, clip, border and (optionally) the two-layer drop shadow of a group style.
    /// The popup and the studio preview use this so they look the same.
    func styleSurface(_ style: GroupStyle, pointer: CGPoint? = nil, isActive: Bool = true, shadow: Bool = false) -> some View {
        modifier(StyleSurface(style: style, pointer: pointer, isActive: isActive, shadow: shadow))
    }
}

struct StyleSurface: ViewModifier {
    var style: GroupStyle
    var pointer: CGPoint?
    var isActive: Bool
    var shadow: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
        content
            .clipShape(shape)
            .background {
                if shadow && style.shadow {
                    StyleBackgroundView(style: style, pointer: pointer, isActive: isActive)
                        .clipShape(shape)
                        .shadow(color: .black.opacity(0.16), radius: 1.5, y: 1)
                        .shadow(color: .black.opacity(0.3), radius: 22, y: 12)
                } else {
                    StyleBackgroundView(style: style, pointer: pointer, isActive: isActive)
                        .clipShape(shape)
                }
            }
            .overlay(StyleBorderView(border: style.border, cornerRadius: style.cornerRadius).allowsHitTesting(false))
    }
}
