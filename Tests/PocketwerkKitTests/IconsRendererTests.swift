import AppKit
import Testing
@testable import PocketwerkKit

@Suite struct IconsRendererTests {
    init() {
        FaviconStore.fetchingEnabled = false
        FaviconStore.shared.directoryOverride = FileManager.default.temporaryDirectory.appendingPathComponent("pw-favicons-\(UUID().uuidString)")
    }

    static let apps = ["/System/Applications/Mail.app", "/System/Applications/Calendar.app", "/System/Applications/Notes.app",
                       "/System/Applications/Music.app", "/System/Applications/Maps.app", "/System/Applications/Photos.app",
                       "/System/Applications/Reminders.app", "/System/Applications/TextEdit.app", "/System/Applications/Podcasts.app"]

    static var items: [DockItem] {
        apps.filter { FileManager.default.fileExists(atPath: $0) }.map { DockItem(kind: .app, url: URL(fileURLWithPath: $0)) }
    }

    static let contents: [IconContent] = [
        .itemGrid(count: 0), .itemGrid(count: 4), .itemGrid(count: 9), .itemGrid(count: 16), .itemStack,
        .symbol(name: "star.fill"), .emoji("🎧"), .text("Bits"), .monogram, .image(path: "/System/Library/CoreServices/Finder.app/Contents/Resources/Finder.icns"),
    ]

    /// Share of pixels with some alpha.
    static func coverage(_ image: CGImage) -> Double {
        let rep = NSBitmapImageRep(cgImage: image)
        var hit = 0, total = 0
        for y in stride(from: 0, to: rep.pixelsHigh, by: 4) {
            for x in stride(from: 0, to: rep.pixelsWide, by: 4) {
                total += 1
                if (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.05 { hit += 1 }
            }
        }
        return Double(hit) / Double(max(1, total))
    }

    @Test func everyContentModeAndShapeDraws() throws {
        let style = ThemeLibrary.builtIn.first { $0.id == "preset.glass.cobalt" }!.style
        for content in Self.contents {
            for shape in IconShape.allCases {
                var spec = IconSpec()
                spec.content = content
                spec.shape = shape
                let image = try #require(IconRenderer.cgImage(spec: spec, style: style, name: "Work Tools", items: Self.items, pixels: 128))
                #expect(Self.coverage(image) > 0.02, "\(content) \(shape)")
            }
        }
    }

    @Test func togglesAndStackOptionsDraw() throws {
        var spec = IconSpec()
        spec.content = .itemStack
        for direction in StackDirection.allCases {
            for depth in 2...4 {
                spec.stack = StackOptions(direction: direction, depth: depth, fade: depth != 3, blur: depth == 4, scale: 0.7,
                                          spacing: 0.15, shuffle: depth == 2)
                spec.matte = 0.5
                spec.glossy.toggle()
                spec.lift.toggle()
                spec.roundItems.toggle()
                spec.dense.toggle()
                spec.border = BorderStyle(color: .white, width: 2, gradient: depth == 2 ? [.white, .black] : nil)
                spec.opacity = 0.6
                spec.background = depth == 3 ? .texture(name: "denim", tint: RGBA(0.2, 0.3, 0.5)) : nil
                let image = try #require(IconRenderer.cgImage(spec: spec, style: GroupStyle(), name: "S", items: Self.items, pixels: 96))
                #expect(Self.coverage(image) > 0.1)
            }
        }
    }

    @Test func emptyGroupStillDraws() throws {
        let image = try #require(IconRenderer.cgImage(spec: IconSpec(), style: GroupStyle(), name: "Empty", items: [], pixels: 64))
        #expect(Self.coverage(image) > 0.3)
    }

    @Test func launcherGeometry() throws {
        var spec = IconSpec()
        spec.lift = false
        spec.background = .solid(RGBA(0.2, 0.5, 0.9))
        let image = try #require(IconRenderer.cgImage(spec: spec, style: GroupStyle(), name: "G", items: [], pixels: 1024))
        let rep = NSBitmapImageRep(cgImage: image)
        // Outside the 0.832 artwork square is transparent; the center and the edge midpoints are covered.
        let margin = Int((1024 - (1024 * IconRenderer.artScale).rounded()) / 2)
        #expect((rep.colorAt(x: margin - 4, y: 512)?.alphaComponent ?? 1) < 0.01)
        #expect((rep.colorAt(x: margin + 4, y: 512)?.alphaComponent ?? 0) > 0.99)
        #expect((rep.colorAt(x: 512, y: 512)?.alphaComponent ?? 0) > 0.99)
        // The corner is rounded with radius 0.2237 x artwork edge.
        #expect((rep.colorAt(x: margin + 6, y: margin + 6)?.alphaComponent ?? 1) < 0.01)
    }

    @Test func pngHelpers() throws {
        var group = ItemGroup(name: "Office")
        group.items = Self.items
        for size in [256, 1024] {
            let data = try #require(IconRenderer.pngData(for: group, size: size))
            let rep = try #require(NSBitmapImageRep(data: data))
            #expect(rep.pixelsWide == size && rep.pixelsHigh == size)
        }
        var lib = Library()
        lib.groups = [group]
        let slot = DockSlot(name: "Office", groupIDs: [group.id])
        let slotPNG = try #require(IconRenderer.pngData(for: slot, library: lib, size: 256))
        #expect(NSBitmapImageRep(data: slotPNG)?.pixelsWide == 256)
        #expect(IconRenderer.groupIcon(group, size: 64).size == NSSize(width: 64, height: 64))
        #expect(IconRenderer.slotIcon(slot, library: lib, size: 32).size == NSSize(width: 32, height: 32))
    }

    @Test func smartGroupsShowASymbol() throws {
        var group = ItemGroup(name: "Recent")
        group.smart = .recentlyOpened
        let data = try #require(IconRenderer.pngData(for: group, size: 128))
        #expect(!data.isEmpty)
    }

    @Test func itemIcons() {
        let link = DockItem(kind: .link, url: URL(string: "https://example.invalid/page")!)
        let missing = DockItem(kind: .file, url: URL(fileURLWithPath: "/nope/missing.txt"))
        let folder = DockItem(kind: .folder, url: URL(fileURLWithPath: "/System"))
        for item in [link, missing, folder] + Self.items.prefix(1) {
            let img = IconRenderer.icon(for: item, size: 48)
            #expect(img.size == NSSize(width: 48, height: 48))
            #expect(img.isValid)
        }
        // The cached base icon is never resized by callers.
        _ = IconRenderer.icon(for: folder, size: 12)
        #expect(ItemIconCache.shared.baseIcon(for: folder).size.width > 12)
    }

    @Test func iconPacksResolve() {
        #expect(IconPacks.all.count == 4)
        for pack in IconPacks.all {
            #expect(pack.symbols.count >= 24)
            for s in pack.symbols {
                #expect(NSImage(systemSymbolName: s, accessibilityDescription: nil) != nil, "\(pack.id): \(s)")
            }
        }
        #expect(IconPacks.pack(id: "nope").id == IconPacks.all[0].id)
    }

    @Test func pureHelpers() {
        #expect(IconPainter.monogram("Work Tools") == "WT")
        #expect(IconPainter.monogram("design") == "D")
        #expect(IconPainter.monogram("  ") == "•")
        #expect(IconPainter.gridDimension(count: 0, items: 3) == 2)
        #expect(IconPainter.gridDimension(count: 0, items: 7) == 3)
        #expect(IconPainter.gridDimension(count: 0, items: 30) == 4)
        #expect(IconPainter.gridDimension(count: 9, items: 1) == 3)
        #expect(IconPainter.gridDimension(count: 16, items: 1) == 4)
    }
}
