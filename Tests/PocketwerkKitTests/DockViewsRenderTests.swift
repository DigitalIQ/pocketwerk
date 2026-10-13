import AppKit
import SwiftUI
import Testing
@testable import PocketwerkKit

/// Writes PNGs of the Dock views to `<worktree>/.tmp/shots`. Opt-in: needs POCKETWERK_SHOTS and a
/// development data folder (POCKETWERK_DATA_DIR, POCKETWERK_DOCK_PLIST), so it never reads real data.
@Suite struct DockViewsRenderTests {
    static var enabled: Bool {
        let env = ProcessInfo.processInfo.environment
        return env["POCKETWERK_SHOTS"] != nil && env["POCKETWERK_DATA_DIR"] != nil && env["POCKETWERK_DOCK_PLIST"] != nil
    }

    @Test(.enabled(if: enabled)) func renderDockViews() throws {
        let folder = URL(fileURLWithPath: ProcessInfo.processInfo.environment["POCKETWERK_SHOTS"]!, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let store = LibraryStore.shared
        if store.library.spacers.isEmpty { store.addSpacer(text: "Work") }
        if store.library.profiles.isEmpty { DockProfiles.shared.captureCurrent(name: "Work Dock") }
        for appearance in [NSAppearance.Name.aqua, .darkAqua] {
            let suffix = appearance == .aqua ? "light" : "dark"
            try render(DockSlotsView(onEditIcon: { _ in }), size: NSSize(width: 760, height: 520), appearance: appearance,
                       to: folder.appendingPathComponent("dock-slots-\(suffix).png"))
            try render(DockProfilesView(selection: store.library.profiles.first?.id), size: NSSize(width: 980, height: 760),
                       appearance: appearance, to: folder.appendingPathComponent("dock-profiles-\(suffix).png"))
        }
    }

    private func render<V: View>(_ view: V, size: NSSize, appearance: NSAppearance.Name, to url: URL) throws {
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: appearance)
        let host = NSHostingView(rootView: view.frame(width: size.width, height: size.height))
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        let rep = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: rep)
        try #require(rep.representation(using: .png, properties: [:])).write(to: url)
    }
}
