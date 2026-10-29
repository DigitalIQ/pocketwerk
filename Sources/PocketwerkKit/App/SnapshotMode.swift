// Adapted from BAMA by Dave Ebbelaar (MIT): https://github.com/daveebbelaar/bama
import AppKit
import SwiftUI

/// Screenshot mode for agents and contributors. Started with the launch flag `--snapshot`:
///
///     POCKETWERK_DATA_DIR=... POCKETWERK_DOCK_PLIST=... POCKETWERK_LAUNCHER_DIR=... \
///     POCKETWERK_SNAPSHOT_DIR=... build/Pocketwerk.app/Contents/MacOS/Pocketwerk --snapshot
///
/// It fills an empty test library with demo groups, opens the real windows, saves one PNG per page and
/// appearance (`<page>-light.png`, `<page>-dark.png`) and exits (0 = all saved, 1 = any failure).
/// `POCKETWERK_SNAPSHOT_PAGES=studio,popup` limits the pages (a name or a prefix before a dash).
///
/// The windows are captured with `screencapture -l`, so Liquid Glass, sidebars and materials look as on
/// screen. That needs Screen Recording permission for the app that started the run (Terminal or Claude).
/// In this mode no menu bar item, hotkey, Dock manager, service or update check starts, and nothing is
/// written to the Dock. `scripts/snap.sh` sets the folders and wipes the old test data.
enum SnapshotMode {
    static var requested: Bool { CommandLine.arguments.contains("--snapshot") }

    /// True when the app is in snapshot mode; the caller then skips its normal launch.
    static func runIfRequested() -> Bool {
        guard requested else { return false }
        let env = ProcessInfo.processInfo.environment
        let required = ["POCKETWERK_DATA_DIR", "POCKETWERK_DOCK_PLIST", "POCKETWERK_LAUNCHER_DIR", "POCKETWERK_SNAPSHOT_DIR"]
        let missing = required.filter { (env[$0] ?? "").isEmpty }
        // The snapshot run writes a demo library: never against the real data folder or Dock.
        guard missing.isEmpty else {
            report("SNAPSHOT refused: set \(missing.joined(separator: ", "))")
            exit(1)
        }
        NSApp.setActivationPolicy(.regular)
        let wanted = (env["POCKETWERK_SNAPSHOT_PAGES"] ?? "").split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let only = wanted.isEmpty ? nil : wanted
        let folder = URL(fileURLWithPath: env["POCKETWERK_SNAPSHOT_DIR"]!, isDirectory: true)
        Task { @MainActor in
            let ok = await SnapshotRun(folder: folder, only: only).run()
            exit(ok ? 0 : 1)
        }
        return true
    }

    static func report(_ line: String) {
        print(line)
        fflush(stdout)
    }
}

// MARK: - Run

@MainActor
private final class SnapshotRun {
    let folder: URL
    let only: [String]?
    let store = LibraryStore.shared
    let model = MainWindowController.shared.model
    var failures = 0
    var written = 0
    /// Where the main window keeps its frame in the user defaults. Restored at the end, because the
    /// snapshot app shares the bundle ID (and so the defaults) with the installed app.
    let frameKey = "NSWindow Frame PocketwerkMainWindow2"
    let savedFrame = UserDefaults.standard.object(forKey: "NSWindow Frame PocketwerkMainWindow2")

    init(folder: URL, only: [String]?) {
        self.folder = folder
        self.only = only
    }

    struct Page {
        let name: String
        let size: CGSize
        let prepare: @MainActor (SnapshotRun) -> NSWindow?
        /// Seconds to wait after the page is set up, for async content (icons, thumbnails).
        var settle: Double = 0.9
    }

    func run() async -> Bool {
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            SnapshotMode.report("SNAPSHOT failed: cannot create \(folder.path)")
            return false
        }
        FaviconStore.fetchingEnabled = false
        let groups = SnapshotSeed.fillIfEmpty(store)
        PopupIconCache.shared.start()
        await AppCatalog.shared.reload()
        try? await Task.sleep(for: .seconds(1.2))

        let pages = makePages(groups)
        let selected = pages.filter { page in
            guard let only else { return true }
            return only.contains { page.name == $0 || page.name.hasPrefix($0 + "-") }
        }
        if selected.isEmpty {
            SnapshotMode.report("SNAPSHOT failed: no page matches \(only?.joined(separator: ",") ?? "")")
            return false
        }
        for mode in ["light", "dark"] {
            NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
            for page in selected {
                guard let window = page.prepare(self) else {
                    fail("SNAPSHOT failed: no window for \(page.name)-\(mode)")
                    continue
                }
                position(window, size: page.size)
                window.makeKeyAndOrderFront(nil)
                NSApp.activate()
                try? await Task.sleep(for: .seconds(page.settle))
                capture(window, to: folder.appendingPathComponent("\(page.name)-\(mode).png"))
            }
        }
        for window in NSApp.windows { window.orderOut(nil) }
        restoreFrameDefault()
        store.saveNow()
        if failures > 0 {
            SnapshotMode.report("SNAPSHOT failed: \(failures) problem(s), \(written) file(s) in \(folder.path)")
            return false
        }
        SnapshotMode.report("SNAPSHOT done \(folder.path)")
        return true
    }

    func fail(_ message: String) {
        failures += 1
        SnapshotMode.report(message)
    }

    // MARK: Pages

    private func makePages(_ g: SnapshotSeed.Groups) -> [Page] {
        let main = CGSize(width: 1260, height: 800)
        func mainPage(_ name: String, _ selection: SidebarItem, tab: GroupTab = .items, settle: Double = 0.9) -> Page {
            Page(name: name, size: main, prepare: { run in
                run.showMain(selection, tab: tab)
            }, settle: settle)
        }
        var pages = [
            mainPage("group-items", .group(g.everyday.id)),
            mainPage("group-smart", .group(g.mostUsed.id)),
            mainPage("group-options", .group(g.everyday.id), tab: .options),
            mainPage("studio", .group(g.create.id), tab: .appearance, settle: 2.0),
            mainPage("dock-icons", .dockIcons),
            mainPage("profiles", .profiles),
        ]
        for page in SettingsPage.allCases {
            pages.append(mainPage("settings-\(page.rawValue)", .settings(page)))
        }
        for group in [g.everyday, g.create, g.focus, g.study] {
            let slug = group.name.lowercased().replacingOccurrences(of: " ", with: "-")
            pages.append(Page(name: "popup-\(slug)", size: .zero, prepare: { run in
                run.popupWindow(for: group.id)
            }))
        }
        return pages
    }

    private func mainWindow() -> NSWindow? {
        NSApp.windows.first { $0.contentViewController is NSHostingController<MainWindowView> }
    }

    private func showMain(_ selection: SidebarItem, tab: GroupTab) -> NSWindow? {
        popupWindows.forEach { $0.orderOut(nil) }
        MainWindowController.shared.show()
        // Stop the window from saving frames into the shared defaults.
        mainWindow()?.setFrameAutosaveName("")
        model.selection = selection
        model.groupTab = tab
        return mainWindow()
    }

    private var popupWindows: [NSWindow] = []

    /// A popup as people see it, on a wallpaper-like backdrop so the glass and blur have something to show.
    private func popupWindow(for groupID: UUID) -> NSWindow? {
        guard let group = store.group(groupID) else { return nil }
        mainWindow()?.orderOut(nil)
        popupWindows.forEach { $0.orderOut(nil) }
        popupWindows.removeAll()
        let content = PopupGroupView(group: group, preview: true)
            .padding(48)
            .background { SnapshotBackdrop() }
        let host = NSHostingView(rootView: content)
        let size = host.fittingSize
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.hasShadow = false
        window.contentView = host
        host.frame = NSRect(origin: .zero, size: size)
        popupWindows.append(window)
        return window
    }

    private func position(_ window: NSWindow, size: CGSize) {
        guard let screen = NSScreen.main else { return }
        let area = screen.visibleFrame
        let target = size == .zero ? window.frame.size
            : CGSize(width: min(size.width, area.width), height: min(size.height, area.height))
        window.setContentSize(target)
        let frame = window.frame
        window.setFrameOrigin(NSPoint(x: area.minX + 40, y: area.maxY - frame.height - 30))
    }

    // MARK: Capture

    private func capture(_ window: NSWindow, to url: URL) {
        let name = url.lastPathComponent
        // Another app can hide this one while the run goes on; hidden windows cannot be captured.
        if NSApp.isHidden { NSApp.unhideWithoutActivation() }
        try? FileManager.default.removeItem(at: url)
        var saved = false
        // The first capture of a run sometimes misses the window: try three times.
        for _ in 1...3 {
            let shot = Process()
            shot.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            shot.arguments = ["-x", "-o", "-l", String(window.windowNumber), url.path]
            do { try shot.run() } catch { break }
            shot.waitUntilExit()
            if FileManager.default.fileExists(atPath: url.path) { saved = true; break }
            Thread.sleep(forTimeInterval: 0.5)
        }
        guard saved else {
            fail("SNAPSHOT failed: \(name) (screencapture produced no file; allow Screen Recording for the app that runs this)")
            return
        }
        if let problem = Self.blankProblem(at: url) {
            fail("SNAPSHOT failed: \(name) (\(problem))")
            return
        }
        written += 1
        SnapshotMode.report("SNAPSHOT \(url.path)")
    }

    /// nil when the image has real content; otherwise why it looks empty.
    static func blankProblem(at url: URL) -> String? {
        guard let rep = NSBitmapImageRep(data: (try? Data(contentsOf: url)) ?? Data()) else { return "unreadable image" }
        guard rep.pixelsWide > 100, rep.pixelsHigh > 100 else { return "image too small" }
        var seen = Set<UInt32>()
        var transparent = 0
        let step = 24
        var samples = 0
        for y in stride(from: 0, to: rep.pixelsHigh, by: step) {
            for x in stride(from: 0, to: rep.pixelsWide, by: step) {
                guard let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                samples += 1
                if c.alphaComponent < 0.1 { transparent += 1 }
                let r = UInt32(c.redComponent * 15), g = UInt32(c.greenComponent * 15), b = UInt32(c.blueComponent * 15)
                seen.insert(r << 8 | g << 4 | b)
            }
        }
        if samples > 0, transparent * 2 > samples { return "mostly transparent" }
        if seen.count < 4 { return "blank, only \(seen.count) distinct colors" }
        return nil
    }

    private func restoreFrameDefault() {
        if let savedFrame {
            UserDefaults.standard.set(savedFrame, forKey: frameKey)
        } else {
            UserDefaults.standard.removeObject(forKey: frameKey)
        }
    }
}

// MARK: - Backdrop

/// Soft colored shapes, a stand-in for a desktop picture behind the popup. It follows the appearance.
private struct SnapshotBackdrop: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let dark = scheme == .dark
        ZStack {
            LinearGradient(colors: dark ? [Color(red: 0.08, green: 0.09, blue: 0.2), Color(red: 0.03, green: 0.2, blue: 0.24)]
                                        : [Color(red: 0.55, green: 0.7, blue: 0.95), Color(red: 0.95, green: 0.72, blue: 0.8)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(dark ? Color.purple.opacity(0.35) : Color.orange.opacity(0.4))
                .frame(width: 260).blur(radius: 40).offset(x: -120, y: 90)
            Circle().fill(dark ? Color.teal.opacity(0.35) : Color.white.opacity(0.5))
                .frame(width: 220).blur(radius: 40).offset(x: 150, y: -80)
        }
    }
}

// MARK: - Demo library

/// Demo content for an empty test library: apps every Mac has, different themes, a folder and a link.
@MainActor
enum SnapshotSeed {
    struct Groups {
        let everyday: ItemGroup
        let create: ItemGroup
        let focus: ItemGroup
        let study: ItemGroup
        let mostUsed: ItemGroup
    }

    /// Fills the library when it has no groups. A library with groups is left as it is.
    static func fillIfEmpty(_ store: LibraryStore) -> Groups {
        if store.library.groups.isEmpty { fill(store) }
        func find(_ name: String) -> ItemGroup {
            store.library.groups.first { $0.name == name } ?? store.library.groups[0]
        }
        return Groups(everyday: find("Everyday"), create: find("Create"), focus: find("Focus"),
                      study: find("Study"), mostUsed: find("Most Used"))
    }

    private static func fill(_ store: LibraryStore) {
        store.settings.onboardingDone = true
        let sets: [(name: String, emoji: String, theme: String, apps: [String])] = [
            ("Everyday", "☀️", "theme.daylight",
             ["com.apple.Safari", "com.apple.mail", "com.apple.iCal", "com.apple.Notes", "com.apple.reminders",
              "com.apple.Maps", "com.apple.Photos", "com.apple.MobileSMS"]),
            ("Create", "🎨", "theme.nightglass",
             ["com.apple.Music", "com.apple.Photos", "com.apple.freeform", "com.apple.Preview", "com.apple.TextEdit",
              "com.apple.PhotoBooth"]),
            ("Focus", "🎯", "theme.pinehollow",
             ["com.apple.systempreferences", "com.apple.clock", "com.apple.calculator", "com.apple.Stocks",
              "com.apple.weather", "com.apple.Terminal", "com.apple.ActivityMonitor"]),
            ("Study", "📚", "theme.rosewater",
             ["com.apple.iBooksX", "com.apple.dictionary", "com.apple.podcasts", "com.apple.news", "com.apple.Notes"]),
        ]
        for set in sets {
            let group = store.addGroup(name: set.name, emoji: set.emoji)
            if let theme = ThemeLibrary.theme(id: set.theme) { store.applyTheme(theme, to: group.id) }
            let urls = set.apps.compactMap { AppLocator.url(forBundleID: $0) }
            store.insertURLs(urls, into: group.id)
        }
        // One folder and one link, the other two item kinds.
        if let everyday = store.library.groups.first(where: { $0.name == "Everyday" }) {
            store.insertURLs([URL(fileURLWithPath: "/Applications/Utilities", isDirectory: true)], into: everyday.id)
            store.addLink(URL(string: "https://www.apple.com")!, name: "Apple", to: everyday.id)
            store.updateGroup(everyday.id) { $0.pinned = true }
        }
        if let study = store.library.groups.first(where: { $0.name == "Study" }) {
            store.addLink(URL(string: "https://en.wikipedia.org")!, name: "Wikipedia", to: study.id)
        }
        // Open counts give the smart group something to show.
        for group in store.library.groups {
            for (index, item) in group.items.prefix(4).enumerated() {
                for _ in 0..<(4 - index) { store.recordOpen(item.id, in: group.id) }
            }
        }
        _ = store.addGroup(name: "Most Used", emoji: nil, smart: .mostUsed)
        // A saved Dock profile, so the Profiles page has a row.
        var profile = DockProfile(name: "Work", plistData: Data())
        profile.tiles = ["com.apple.Safari", "com.apple.mail", "com.apple.iCal", "com.apple.Notes"].map {
            DockTile(kind: .app, url: AppLocator.url(forBundleID: $0), bundleID: $0)
        }
        profile.note = "Mail, calendar and notes within reach."
        store.mutate { $0.profiles.append(profile) }
        store.saveNow()
    }
}
