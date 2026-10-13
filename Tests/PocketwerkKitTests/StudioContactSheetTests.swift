import AppKit
import SwiftUI
import Testing
@testable import PocketwerkKit

/// Renders contact sheets of all looks and icon modes to `<worktree>/.tmp/shots` for a visual check.
@Suite struct StudioContactSheetTests {
    static var shotsDir: URL {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let dir = root.appendingPathComponent(".tmp/shots", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    init() { FaviconStore.fetchingEnabled = false }

    @discardableResult
    static func write<V: View>(_ view: V, _ name: String, scale: CGFloat = 1) throws -> CGImage {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        let image = try #require(renderer.cgImage)
        let data = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
        try data.write(to: shotsDir.appendingPathComponent(name))
        return image
    }

    struct Card: View {
        var theme: Theme
        var body: some View {
            let style = theme.style
            let label = style.labels.resolvedColor(on: style.background, dark: true)
            let icon = IconRenderer.render(spec: theme.icon ?? IconSpec(), style: style, name: theme.name,
                                           items: IconsRendererTests.items, size: 56)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    ForEach(IconsRendererTests.items.prefix(4)) { item in
                        VStack(spacing: 3) {
                            Image(nsImage: IconRenderer.icon(for: item, size: 34)).resizable().frame(width: 34, height: 34)
                            Text(item.displayName)
                                .font(.system(size: 8.5, weight: .medium, design: style.labels.fontDesign))
                                .foregroundStyle(label.color)
                                .lineLimit(1)
                                .frame(width: 42)
                        }
                    }
                    Spacer(minLength: 0)
                    Image(nsImage: icon)
                }
                Text(theme.name).font(.system(size: 11, weight: .semibold)).foregroundStyle(label.color)
                Text(theme.category).font(.system(size: 9)).foregroundStyle(label.color.opacity(0.7))
            }
            .padding(12)
            .frame(width: 300, height: 110, alignment: .topLeading)
            .styleSurface(style, isActive: false)
        }
    }

    /// A busy backdrop so glass and opacity show something.
    static var backdrop: some View {
        MeshFill(colors: [RGBA(hex: "#3A6EA5"), RGBA(hex: "#F2A65A"), RGBA(hex: "#7B4FA0"), RGBA(hex: "#2E8B57"), RGBA(hex: "#EED6C4")])
    }

    @Test func themesSheet() throws {
        let themes = ThemeLibrary.builtIn
        let half = (themes.count + 1) / 2
        for (part, slice) in [(1, themes.prefix(half)), (2, themes.suffix(from: half))] {
            let sheet = LazyVGrid(columns: Array(repeating: GridItem(.fixed(300), spacing: 12), count: 4), spacing: 12) {
                ForEach(Array(slice)) { Card(theme: $0) }
            }
            .padding(16)
            .background(Self.backdrop)
            .environment(\.colorScheme, .dark)
            try Self.write(sheet, "themes-\(part).png")
        }
    }

    @Test func iconsSheet() throws {
        let style = ThemeLibrary.builtIn.first { $0.id == "theme.harbor" }!.style
        let rows: [(String, IconSpec)] = IconsRendererTests.contents.map { content in
            var s = IconSpec(); s.content = content
            return ("\(content)".components(separatedBy: "(").first ?? "", s)
        } + [
            ("folder", { var s = IconSpec(); s.shape = .folder; return s }()),
            ("round", { var s = IconSpec(); s.roundItems = true; s.content = .itemGrid(count: 9); return s }()),
            ("stack↓ blur", { var s = IconSpec(); s.content = .itemStack; s.stack.direction = .down; s.stack.blur = true; s.stack.depth = 4; return s }()),
            ("stack↙", { var s = IconSpec(); s.content = .itemStack; s.stack.direction = .downLeft; return s }()),
            ("matte", { var s = IconSpec(); s.matte = 1; s.glossy = false; return s }()),
            ("texture", { var s = IconSpec(); s.background = .texture(name: "knit", tint: RGBA(hex: "#B5404E")); return s }()),
            ("symbol emboss", { var s = IconSpec(); s.content = .symbol(name: "trophy.fill"); s.foreground = RGBA(hex: "#FFD25A"); return s }()),
            ("symbol duo", { var s = IconSpec(); s.content = .symbol(name: "leaf.fill"); s.pack = "nature"; return s }()),
            ("symbol multi", { var s = IconSpec(); s.content = .symbol(name: "party.popper.fill"); s.pack = "play"; return s }()),
            ("emoji folder", { var s = IconSpec(); s.content = .emoji("🍕"); s.shape = .folder; return s }()),
            ("text folder", { var s = IconSpec(); s.content = .text("Dev"); s.shape = .folder; s.background = .solid(RGBA(hex: "#2B2D33")); return s }()),
            ("gradient border", { var s = IconSpec(); s.border = BorderStyle(color: .white, width: 2, gradient: [RGBA(hex: "#FF41A8"), RGBA(hex: "#41C8FF")]); return s }()),
        ]
        let sheet = VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 10) {
                    Text(row.0).font(.system(size: 11, design: .monospaced)).foregroundStyle(.white).frame(width: 110, alignment: .leading)
                    ForEach(IconShape.allCases, id: \.self) { shape in
                        let spec: IconSpec = { var s = row.1; if row.0 != "folder" && !row.0.contains("folder") { s.shape = shape }; return s }()
                        Image(nsImage: IconRenderer.render(spec: spec, style: style, name: "Work Tools", items: IconsRendererTests.items, size: 72))
                    }
                }
            }
        }
        .padding(16)
        .background(Self.backdrop)
        try Self.write(sheet, "icons.png", scale: 1)
    }

    @Test func effectsAndTexturesSheet() throws {
        let fx = ThemeLibrary.builtIn.filter { $0.style.background.isAnimated }
        let textures = TextureKind.allCases
        let sheet = VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(220), spacing: 10), count: 5), spacing: 10) {
                ForEach(fx) { t in
                    StyleBackgroundView(style: t.style, isActive: false)
                        .frame(width: 220, height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(alignment: .bottomLeading) {
                            Text(t.name).font(.caption.bold()).foregroundStyle(.white).shadow(radius: 2).padding(8)
                        }
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(220), spacing: 10), count: 6), spacing: 10) {
                ForEach(textures, id: \.self) { k in
                    TextureFill(kind: k, tint: k.suggestedTint)
                        .frame(width: 220, height: 110)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(alignment: .bottomLeading) {
                            Text(k.title).font(.caption.bold()).foregroundStyle(.white).shadow(radius: 2).padding(8)
                        }
                }
            }
        }
        .padding(16)
        .background(Color.black)
        try Self.write(sheet, "effects-textures.png", scale: 1)
    }
}

/// The whole Design Studio in an offscreen window, captured per inspector tab.
@Suite struct StudioWindowShotTests {
    @Test func studioTabs() throws {
        FaviconStore.fetchingEnabled = false
        let store = LibraryStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("pw-studio-\(UUID().uuidString).json"))
        let group = store.addGroup(name: "Studio")
        store.updateGroup(group.id) { $0.items = IconsRendererTests.items }
        store.applyTheme(ThemeLibrary.builtIn.first { $0.id == "theme.northernveil" }!, to: group.id)
        _ = store.saveTheme(from: group.id, name: "Veil Copy")
        let tabs: [(StudioTab, String)] = [(.icon, "studio-icon.png"), (.popup, "studio-popup.png"), (.grid, "studio-grid.png")]
        for (tab, file) in tabs {
            let view = DesignStudioView(groupID: group.id, store: store)
            let host = NSHostingView(rootView: view)
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1360, height: 860), styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.appearance = NSAppearance(named: .darkAqua)
            window.contentView = host
            host.layoutSubtreeIfNeeded()
            // Switch the tab through the editor inside the view.
            if let editor = Mirror(reflecting: view).descendant("_editor", "_value") as? StudioEditor { editor.tab = tab }
            RunLoop.main.run(until: Date().addingTimeInterval(0.4))
            host.layoutSubtreeIfNeeded()
            let rep = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: rep)
            let data = try #require(rep.representation(using: .png, properties: [:]))
            try data.write(to: StudioContactSheetTests.shotsDir.appendingPathComponent(file))
            window.close()
        }
    }
}
