import AppKit
import SwiftUI
import Testing
@testable import PocketwerkKit

/// Renders popup previews to PNG for a visual check. Runs only with POCKETWERK_SHOTS=1,
/// writes to `.tmp/shots/` in the package folder.
@Suite struct PopupRenderTests {
    init() { FaviconStore.fetchingEnabled = false }

    nonisolated static var enabled: Bool { ProcessInfo.processInfo.environment["POCKETWERK_SHOTS"] == "1" }

    static func folder() -> URL {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let dir = root.appendingPathComponent(".tmp/shots", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func sampleGroup(count: Int) -> ItemGroup {
        let apps = ["Safari", "Mail", "Calendar", "Notes", "Reminders", "Maps", "Photos", "Messages", "FaceTime",
                    "Music", "Podcasts", "TV", "News", "Stocks", "Weather", "Clock", "Calculator", "Preview",
                    "TextEdit", "Chess", "Dictionary", "Freeform", "Home", "Shortcuts", "System Settings"]
        var g = ItemGroup(name: "Everyday Tools")
        g.items = apps.prefix(count).map { DockItem(kind: .app, url: URL(fileURLWithPath: "/System/Applications/\($0).app")) }
        g.items.append(DockItem(kind: .link, url: URL(string: "https://www.example.com/a/very/long/path")!, customName: "A link with a rather long name"))
        return g
    }

    func render(_ group: ItemGroup, name: String, scheme: ColorScheme = .dark) {
        let view = PopupGroupView(group: group, preview: true)
            .environment(\.colorScheme, scheme)
            .padding(30)
            .background(LinearGradient(colors: [.indigo, .teal], startPoint: .topLeading, endPoint: .bottomTrailing))
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else {
            Issue.record("render failed for \(name)")
            return
        }
        try? png.write(to: Self.folder().appendingPathComponent("\(name).png"))
    }

    @Test(.enabled(if: PopupRenderTests.enabled)) func renderLayouts() {
        var grid = Self.sampleGroup(count: 7)
        grid.style.background = .gradient(colors: [RGBA(0.12, 0.16, 0.3), RGBA(0.05, 0.06, 0.12)], angle: 135)
        render(grid, name: "grid")

        var paged = Self.sampleGroup(count: 24)
        paged.style.maxRows = 2
        paged.style.columns = 5
        paged.style.labels.mode = .always
        paged.style.header = .center
        paged.style.border = BorderStyle(color: .white, width: 1.5, gradient: [RGBA(1, 0.6, 0.2), RGBA(0.6, 0.2, 1)])
        render(paged, name: "grid-paged")

        var list = Self.sampleGroup(count: 10)
        list.style.layout = .list
        list.style.background = .solid(RGBA(0.97, 0.95, 0.9))
        list.style.labels.design = .serif
        render(list, name: "list", scheme: .light)

        var tiles = Self.sampleGroup(count: 7)
        tiles.style.layout = .tiles
        tiles.style.iconSize = 40
        tiles.style.spacing = 8
        tiles.style.background = .solid(RGBA(0.1, 0.1, 0.12))
        tiles.style.labels.size = 12
        tiles.style.labels.weight = 0.3
        render(tiles, name: "tiles")

        var bare = Self.sampleGroup(count: 4)
        bare.style.header = .hidden
        bare.style.labels.mode = .off
        bare.style.iconPlate = RGBA(1, 1, 1, 0.15)
        render(bare, name: "icons-only")

        render(ItemGroup(name: "Empty"), name: "empty")

        // Long names get a second line.
        var long = Self.sampleGroup(count: 3)
        long.items.append(DockItem(kind: .app, url: URL(fileURLWithPath: "/System/Applications/Utilities/Screenshot.app"), customName: "Microsoft Remote Desktop"))
        long.items.append(DockItem(kind: .app, url: URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"), customName: "Activity Monitor Helper"))
        render(long, name: "grid-two-lines")
    }

    func renderModel(_ model: PopupModel, group: ItemGroup, name: String) {
        let size = model.usesSidebar ? model.desiredSize() : nil
        let view = PopupGroupView(group: group, model: model, size: size, preview: true)
            .environment(\.colorScheme, .dark)
            .padding(30)
            .background(LinearGradient(colors: [.indigo, .teal], startPoint: .topLeading, endPoint: .bottomTrailing))
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else {
            Issue.record("render failed for \(name)")
            return
        }
        try? png.write(to: Self.folder().appendingPathComponent("\(name).png"))
    }

    @Test(.enabled(if: PopupRenderTests.enabled)) func renderStates() {
        let group = Self.sampleGroup(count: 7)
        let focus = PopupModel(groupIDs: [group.id])
        focus.selection = 1
        focus.focusVisible = true
        focus.picked = [group.items[4].url, group.items[5].url]
        focus.modifiers = .control
        renderModel(focus, group: group, name: "states-focus-picked-digits")

        var groups = (0..<4).map { i -> ItemGroup in
            var g = Self.sampleGroup(count: 5 + i)
            g.name = ["Work", "Design", "Writing", "Games"][i]
            return g
        }
        groups[1].emoji = "🎨"
        let store = LibraryStore(fileURL: Self.folder().appendingPathComponent("render-library.json"))
        store.mutate { $0.groups = groups }
        let side = PopupModel(groupIDs: groups.map(\.id))
        side.store = store
        side.sidebarOverride = true
        side.position.group = 0
        // The model reads groups from the store, so the sidebar needs stored groups; draw names only when present.
        renderModel(side, group: groups[0], name: "sidebar")
        store.settings.sidebarCollapsed = true
        renderModel(side, group: groups[0], name: "sidebar-compact")
    }
}
