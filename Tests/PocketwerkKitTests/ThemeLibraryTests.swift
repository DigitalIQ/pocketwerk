import Foundation
import Testing
@testable import PocketwerkKit

@Suite struct ThemeLibraryTests {
    func tempStore() -> LibraryStore {
        LibraryStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("pw-theme-\(UUID().uuidString).json"))
    }

    @Test func catalogSize() {
        #expect(ThemeLibrary.themes.count >= 24)
        let animated = ThemeLibrary.themes.filter { $0.style.background.isAnimated }
        #expect(animated.count >= 10)
        #expect(ThemeLibrary.presets.count == 64)
        #expect(Set(ThemeLibrary.presets.map(\.category)).count >= 6)
        // Every effect kind appears in at least one built-in look.
        let kinds = Set(ThemeLibrary.builtIn.compactMap { t -> FXKind? in
            if case .fx(let p) = t.style.background { return p.kind } else { return nil }
        })
        #expect(kinds == Set(FXKind.allCases))
    }

    @Test func idsAndNamesUnique() {
        let all = ThemeLibrary.builtIn
        #expect(Set(all.map(\.id)).count == all.count)
        #expect(Set(all.map(\.name)).count == all.count)
        #expect(all.allSatisfy { $0.isBuiltIn && $0.icon != nil && !$0.name.isEmpty })
    }

    @Test func sectionsCoverEverything() {
        let sections = ThemeLibrary.sections()
        #expect(sections.flatMap(\.themes).count == ThemeLibrary.builtIn.count)
        #expect(sections.allSatisfy { !$0.themes.isEmpty })
    }

    @Test func builtInsEncodeAndDecode() throws {
        for theme in ThemeLibrary.builtIn {
            let data = try LibraryStore.encoder.encode(theme)
            let back = try LibraryStore.decoder.decode(Theme.self, from: data)
            #expect(back == theme, "\(theme.id)")
        }
    }

    @Test func applyKeepsLayoutFields() {
        var style = GroupStyle()
        style.layout = .tiles
        style.columns = 7
        style.maxRows = 3
        style.paged = false
        style.iconSize = 88
        style.spacing = 22
        style.padding = 30
        style.header = .center
        style.labels.mode = .onHover
        style.runningIndicator = false
        style.showPageIndicator = false
        style.popupScale = 1.3
        style.mirrorIcon = true
        for theme in ThemeLibrary.builtIn {
            let s = ThemeLibrary.apply(theme, to: style)
            #expect(s.layout == .tiles && s.columns == 7 && s.maxRows == 3 && s.paged == false)
            #expect(s.iconSize == 88 && s.spacing == 22 && s.padding == 30 && s.header == .center)
            #expect(s.labels.mode == .onHover && s.runningIndicator == false && s.showPageIndicator == false)
            #expect(s.popupScale == 1.3 && s.mirrorIcon)
            #expect(s.background == theme.style.background)
            #expect(s.border == theme.style.border)
            #expect(s.labels.design == theme.style.labels.design)
        }
    }

    @Test func applyIconKeepsContentAndOwnColors() {
        var icon = IconSpec()
        icon.content = .emoji("🎧")
        icon.background = .solid(RGBA(1, 0, 0))
        icon.foreground = RGBA(0, 1, 0)
        icon.shape = .folder
        let theme = ThemeLibrary.builtIn.first { $0.id == "theme.spectrum" }!
        let out = ThemeLibrary.apply(theme.icon!, to: icon)
        #expect(out.content == .emoji("🎧"))
        #expect(out.background == .solid(RGBA(1, 0, 0)))
        #expect(out.foreground == RGBA(0, 1, 0))
        #expect(out.shape == .folder)
        #expect(out.glossy == theme.icon!.glossy)
    }

    @Test func storeAppliesThemeAndKeepsLayout() {
        let store = tempStore()
        let g = store.addGroup(name: "Look")
        store.updateGroup(g.id) { $0.style.columns = 5; $0.style.iconSize = 72 }
        let theme = ThemeLibrary.builtIn.first { $0.id == "theme.quietsnow" }!
        store.applyTheme(theme, to: g.id)
        let after = store.group(g.id)!
        #expect(after.style.columns == 5 && after.style.iconSize == 72)
        #expect(after.style.background == theme.style.background)
        #expect(after.themeID == theme.id)
    }

    @Test func ownThemesSaveRenameDelete() {
        let store = tempStore()
        let g = store.addGroup(name: "Mine")
        store.updateGroup(g.id) { $0.style.background = .solid(RGBA(0.2, 0.4, 0.6)) }
        let saved = store.saveTheme(from: g.id, name: "  Blue Hour  ")
        #expect(saved?.name == "Blue Hour")
        #expect(store.library.customThemes.count == 1)
        #expect(store.group(g.id)?.themeID == saved?.id)
        #expect(store.library.customThemes[0].style.background == .solid(RGBA(0.2, 0.4, 0.6)))
        #expect(store.allThemes.contains { $0.id == saved?.id })

        store.renameTheme(saved!.id, to: "Night Shift")
        #expect(store.library.customThemes[0].name == "Night Shift")
        store.renameTheme(saved!.id, to: "   ")
        #expect(store.library.customThemes[0].name == "Night Shift")

        store.deleteTheme(saved!.id)
        #expect(store.library.customThemes.isEmpty)
        #expect(store.group(g.id)?.themeID == nil)
        #expect(store.group(g.id)?.style.background == .solid(RGBA(0.2, 0.4, 0.6)))
        store.undo()
        #expect(store.library.customThemes.count == 1)
    }

    @Test func resetAndRandomizeKeepLayout() {
        let store = tempStore()
        let g = store.addGroup(name: "R")
        store.updateGroup(g.id) { $0.style.layout = .list; $0.style.columns = 4; $0.icon.content = .text("Hi") }
        for seed in 0..<40 {
            store.randomizeLook(of: g.id, seed: UInt64(seed))
            let s = store.group(g.id)!
            #expect(s.style.layout == .list && s.style.columns == 4)
            #expect(s.icon.content == .text("Hi"))
        }
        store.resetLook(of: g.id)
        let s = store.group(g.id)!
        #expect(s.style.background == GroupStyle().background)
        #expect(s.style.layout == .list && s.style.columns == 4)
    }

    @Test func randomizerIsDeterministic() {
        let a = StyleRandomizer.randomLook(base: GroupStyle(), icon: IconSpec(), seed: 42)
        let b = StyleRandomizer.randomLook(base: GroupStyle(), icon: IconSpec(), seed: 42)
        #expect(a.0 == b.0 && a.1 == b.1)
    }

    @Test func colorMath() {
        #expect(RGBA.white.readableLabel.isDark)
        #expect(RGBA.black.readableLabel == .white)
        #expect(RGBA(hex: "#FF0000").luminance > 0.2)
        let red = RGBA(hue: 0, saturation: 1, brightness: 1)
        #expect(abs(red.r - 1) < 0.001 && red.g < 0.001 && red.b < 0.001)
        let laid = MeshFill.layout([.black, .white])
        #expect(laid.count == 9 && laid[0] == .black && laid[8] == .white)
        #expect(hash01(3, 1) == hash01(3, 1) && hash01(3, 1) != hash01(4, 1))
    }

    @Test func labelColorResolution() {
        var label = LabelStyle()
        label.colorMode = .auto
        #expect(label.resolvedColor(on: .solid(RGBA(0.95, 0.95, 0.95)), dark: true).isDark)
        #expect(label.resolvedColor(on: .solid(RGBA(0.05, 0.05, 0.1)), dark: false) == .white)
        #expect(label.resolvedColor(on: .glass(tint: .clear, intensity: 1), dark: true) == .white)
        label.colorMode = .custom
        label.color = RGBA(0.2, 0.3, 0.4)
        #expect(label.resolvedColor(on: .solid(.black), dark: true) == RGBA(0.2, 0.3, 0.4))
    }
}
