import AppKit
import SwiftUI
import Testing
@testable import PocketwerkKit

/// Rendering checks for backgrounds, textures and effects.
@Suite struct ThemeRenderTests {
    /// Fraction of sampled pixels that differ clearly from the first one: 0 = flat image.
    static func variety(_ image: CGImage) -> Double {
        let rep = NSBitmapImageRep(cgImage: image)
        guard let first = rep.colorAt(x: 0, y: 0)?.usingColorSpace(.sRGB) else { return 0 }
        var differ = 0, total = 0
        for y in stride(from: 0, to: rep.pixelsHigh, by: max(1, rep.pixelsHigh / 24)) {
            for x in stride(from: 0, to: rep.pixelsWide, by: max(1, rep.pixelsWide / 24)) {
                guard let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                total += 1
                let d = abs(c.redComponent - first.redComponent) + abs(c.greenComponent - first.greenComponent)
                    + abs(c.blueComponent - first.blueComponent)
                if d > 0.03 { differ += 1 }
            }
        }
        return total == 0 ? 0 : Double(differ) / Double(total)
    }

    @Test func texturesForEveryKind() {
        for kind in TextureKind.allCases {
            let tile = TextureFactory.tile(kind, tint: kind.suggestedTint)
            #expect(tile != nil, "\(kind)")
            if let tile {
                #expect(tile.width == Int(TextureFactory.tilePoints * 2))
                #expect(Self.variety(tile) > 0.05, "\(kind) looks flat")
            }
        }
        // Unknown names fall back instead of failing.
        #expect(TextureKind(name: "does-not-exist") == .noise)
    }

    @Test func effectViewsRenderForEveryKind() {
        for kind in FXKind.allCases {
            let params = FXParams(kind: kind, palette: [RGBA(hex: "#1B2A4A"), RGBA(hex: "#FF7A3D"), RGBA(hex: "#7CE0FF")])
            let view = FXView(params: params, pointer: nil, isActive: false).frame(width: 220, height: 150)
            let renderer = ImageRenderer(content: view)
            let image = renderer.cgImage
            #expect(image != nil, "\(kind)")
            if let image { #expect(Self.variety(image) > 0.05, "\(kind) looks flat") }
        }
    }

    @Test func backgroundViewBuildsForEveryCase() {
        let cases: [Background] = [
            .solid(RGBA(0.2, 0.3, 0.4)),
            .gradient(colors: [.black, .white], angle: 45),
            .mesh(colors: [RGBA(1, 0, 0), RGBA(0, 1, 0), RGBA(0, 0, 1)]),
            .image(path: "/nonexistent.png", dim: 0.2, blur: 10),
            .glass(tint: RGBA(0, 0, 0, 0.3), intensity: 1),
            .fx(FXParams(kind: .snow, palette: [.white])),
            .wallpaper(blur: 20, dim: 0.1),
            .texture(name: "knit", tint: RGBA(0.7, 0.2, 0.3)),
        ]
        for bg in cases {
            let view = StyleBackgroundView(background: bg, isActive: false, glassAmount: 0.4, matte: 0.3, opacity: 0.9)
                .frame(width: 120, height: 80)
            #expect(ImageRenderer(content: view).cgImage != nil, "\(bg.kindName)")
            for rt in [false, true] {
                let v = StyleBackgroundView(background: bg, isActive: false)
                    .environment(\.forceOpaqueBackgrounds, rt)
                    .frame(width: 60, height: 40)
                #expect(ImageRenderer(content: v).cgImage != nil)
            }
        }
    }

    @Test func pointerModels() {
        let state = FXState()
        var t = 0.0
        // Ripple: influence rises while the pointer is inside, lingers, then springs back.
        for _ in 0..<20 { t += 1 / 30; _ = state.advance(real: t, pointer: CGPoint(x: 50, y: 50), model: .ripple) }
        #expect(state.influence > 0.9)
        #expect(!state.rings.isEmpty)
        for _ in 0..<10 { t += 1 / 30; _ = state.advance(real: t, pointer: nil, model: .ripple) }
        #expect(state.influence > 0.9) // lingers
        for _ in 0..<60 { t += 1 / 30; _ = state.advance(real: t, pointer: nil, model: .ripple) }
        #expect(state.influence < 0.01)

        // Shove: a pushed particle keeps most of its offset for seconds.
        let shove = FXState()
        var frame = FXFrame(w: 200, h: 200, t: 0, age: 0, dt: 1 / 30, still: false,
                            p: FXParams(kind: .snow, palette: [.white], pointer: .shove), state: shove)
        var s = 0.0
        for _ in 0..<15 {
            s += 1 / 30
            frame.dt = shove.advance(real: s, pointer: CGPoint(x: 100, y: 100), model: .shove)
            _ = shove.shove(0, 110, 100, frame: frame)
        }
        let pushed = shove.shove(0, 110, 100, frame: frame)
        #expect(pushed.x > 112)
        for _ in 0..<30 { s += 1 / 30; frame.dt = shove.advance(real: s, pointer: nil, model: .shove) }
        let later = shove.shove(0, 110, 100, frame: frame)
        #expect(later.x > 110 + (pushed.x - 110) * 0.8)

        // Still: never reacts.
        let still = FXState()
        _ = still.advance(real: 1, pointer: CGPoint(x: 5, y: 5), model: .still)
        #expect(still.influence == 0 && still.pointerPoint == nil)
    }

    @Test func representativeColors() {
        #expect(Background.solid(RGBA(0.1, 0.2, 0.3)).representativeColor == RGBA(0.1, 0.2, 0.3))
        #expect(Background.glass(tint: RGBA(0, 0, 0, 0.5), intensity: 1).representativeColor.isDark)
        #expect(Background.fx(FXParams(kind: .snow, palette: [.white])).isAnimated)
        #expect(Background.wallpaper(blur: 1, dim: 0).isSeeThrough)
    }
}
