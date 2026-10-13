import AppKit
import SwiftUI
import Testing
@testable import PocketwerkKit

/// Snow over textures, glow and depth, effect clock and power helpers, app icon variants.
@Suite struct ThemePhaseBTests {
    @Test func textureSnowOverlayNames() {
        #expect(TextureKind(name: "knit+snow") == .knit)
        #expect(TextureKind.hasSnow("knit+snow"))
        #expect(!TextureKind.hasSnow("knit"))
        #expect(!TextureKind.hasSnow("snow"))
        #expect(TextureKind.name(.ice, snow: true) == "ice+snow")
        #expect(TextureKind.name(.ice, snow: false) == "ice")
        #expect(Background.texture(name: "felt+snow", tint: .white).isAnimated)
        #expect(!Background.texture(name: "felt", tint: .white).isAnimated)
        #expect(ThemeLibrary.builtIn.contains { $0.id == "theme.winterknit" })
        // The overlay leaves the texture visible: its base is clear.
        #expect(TextureKind.snowOverlay.base?.a == 0)
    }

    static func render(_ style: GroupStyle) throws -> NSBitmapImageRep {
        let image = try #require(ImageRenderer(content: StyleBackgroundView(style: style, isActive: false).frame(width: 160, height: 100)).cgImage)
        return NSBitmapImageRep(cgImage: image)
    }

    @Test func glowAndDepthRender() throws {
        var style = ThemeLibrary.builtIn.first { $0.id == "theme.harbor" }!.style
        style.cornerRadius = 0
        let plain = try Self.render(style)
        let bottom = (plain.pixelsWide / 2, plain.pixelsHigh - 3), side = (2, plain.pixelsHigh / 2)
        var deep = style
        deep.depth = 1
        let d = try Self.render(deep)
        #expect(d.colorAt(x: bottom.0, y: bottom.1)!.brightnessComponent < plain.colorAt(x: bottom.0, y: bottom.1)!.brightnessComponent)
        var glowing = style
        glowing.glow = 1
        let g = try Self.render(glowing)
        #expect(g.colorAt(x: side.0, y: side.1)!.brightnessComponent > plain.colorAt(x: side.0, y: side.1)!.brightnessComponent)
        #expect(Background.solid(RGBA(0.1, 0.2, 0.3)).glowColor.luminance > RGBA(0.1, 0.2, 0.3).luminance)
    }

    @Test func snowOverTextureRenders() throws {
        let view = StyleBackgroundView(background: .texture(name: "knit+snow", tint: RGBA(hex: "#A8323F")), isActive: false)
            .frame(width: 200, height: 120)
        let image = try #require(ImageRenderer(content: view).cgImage)
        #expect(ThemeRenderTests.variety(image) > 0.05)
    }

    @Test func effectClockContinues() {
        let p = FXParams(kind: .snow, palette: [RGBA(0.123, 0.456, 0.789)])
        let first = FXClock.age(of: p)
        let second = FXClock.age(of: p)
        #expect(first >= 0 && second >= first)
    }

    @Test func effectsDrawWithBatteryDensity() {
        for kind in FXKind.allCases where kind != .plasma {
            var frame = FXFrame(w: 160, h: 100, t: 30, age: 40, dt: 0, still: true,
                                p: kind.defaultParams, state: FXState())
            frame.density = 0.6
            let view = Canvas { gc, _ in FXRenderer.draw(frame, into: &gc) }.frame(width: 160, height: 100)
            #expect(ImageRenderer(content: view).cgImage != nil, "\(kind)")
            #expect(FXRenderer.idleFramesPerSecond(kind) <= FXRenderer.framesPerSecond(kind))
        }
        _ = PowerState.onBattery // must not crash on desktops without a battery
    }

    @Test func pointerModelTimings() {
        let state = FXState()
        var t = 0.0
        for _ in 0..<10 { t += 0.05; _ = state.advance(real: t, pointer: CGPoint(x: 10, y: 10), model: .comb) }
        #expect(state.influence > 0.9)
        for _ in 0..<Int(PointerModel.combSpringBack / 0.05) + 2 { t += 0.05; _ = state.advance(real: t, pointer: nil, model: .comb) }
        #expect(state.influence < 0.01)
    }

    @Test func appIconVariants() {
        for v in AppIconVariant.allCases {
            let img = AppIconVariants.image(v)
            #expect(img.isValid && img.size.width > 0, "\(v)")
        }
        #expect(AppIconVariant(id: "nope") == .standard)
        #expect(AppSettings().appIconVariant == "standard")
    }

    @Test func gradientSwatches() {
        let pair = StudioPalette.gradientPair(RGBA(hex: "#2F6FED"))
        #expect(pair.count == 2 && pair[0].luminance > pair[1].luminance)
        let white = StudioPalette.gradientPair(.white)
        #expect(white[0] == .white && white[1].luminance < 1)
    }
}
