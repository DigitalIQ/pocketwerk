// Adapted from BAMA by Dave Ebbelaar (MIT): https://github.com/daveebbelaar/bama
import AppKit
import PocketwerkShared

/// In-app self-test: `Pocketwerk --selftest` runs the functions the UI calls on a test store,
/// with real windows, menus and the real bundle, prints `PASS <step>` or `FAIL <step>: <reason>`
/// per step and exits 0 (all passed), 1 (a step failed) or 2 (refused). `scripts/selftest.sh` runs it.
///
/// It refuses to run unless the data folder, the Dock plist and the launcher folder point to test
/// locations, and it starts no hotkeys, no update check, no menu bar item and no launcher listener,
/// so a running Pocketwerk keeps its hotkeys and Dock clicks.
enum SelfTest {
    static var requested: Bool { CommandLine.arguments.contains("--selftest") }

    private static var passed = 0
    private static var failed: [String] = []
    private static var exitCode: Int32 = 0
    /// Steps may take this long in total before the run is stopped.
    nonisolated private static let timeout: Double = 120

    private struct Failure: Error, CustomStringConvertible {
        let description: String
    }

    /// First line of `applicationDidFinishLaunching`. True when the self-test takes over the launch.
    static func runIfRequested() -> Bool {
        guard requested else { return false }
        // Line-buffered, so a crash keeps the lines before it.
        setvbuf(stdout, nil, _IOLBF, 0)
        if let problem = unsafeEnvironment() {
            print("SELFTEST refused: \(problem)")
            // exit, not terminate: terminate would save the library that was loaded at launch.
            exit(2)
        }
        // No Dock icon: a running regular app could land in the real Dock's recent apps.
        NSApp.setActivationPolicy(.accessory)
        MainMenu.install()
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { exit(exitCode) }
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
            print("FAIL watchdog: the self-test did not finish within \(Int(timeout)) s")
            exit(1)
        }
        Task { await run() }
        return true
    }

    /// nil when all three overrides point to test folders, else the reason to refuse.
    static func unsafeEnvironment(_ env: [String: String] = ProcessInfo.processInfo.environment) -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.resolvingSymlinksInPath().path
        let forbidden = [home + "/Applications", home + "/Library"]
        for key in ["POCKETWERK_DATA_DIR", "POCKETWERK_DOCK_PLIST", "POCKETWERK_LAUNCHER_DIR"] {
            guard let raw = env[key], !raw.isEmpty else {
                return "\(key) is not set. Run scripts/selftest.sh, or point all three test variables to a .tmp folder."
            }
            guard raw.hasPrefix("/") else { return "\(key) must be an absolute path: \(raw)" }
            let path = URL(fileURLWithPath: raw).standardizedFileURL.resolvingSymlinksInPath().path
            if let root = forbidden.first(where: { path == $0 || path.hasPrefix($0 + "/") }) {
                return "\(key) points into \(root): \(path)"
            }
            let parts = path.split(separator: "/")
            guard parts.contains(where: { $0 == ".tmp" || $0.lowercased().contains("selftest") }) else {
                return "\(key) must lie in a .tmp or selftest folder: \(path)"
            }
        }
        return nil
    }

    // MARK: Steps

    private static func run() async {
        // Let the launch settle before the first window.
        await pause(0.3)
        let started = Date()
        let store = LibraryStore.shared
        let dock = DockManager.shared
        let profiles = DockProfiles.shared
        let fm = FileManager.default
        let dataDir = LibraryStore.directory
        let launcherDir = dock.launcherFolder.resolvingSymlinksInPath().path
        let calculator = URL(fileURLWithPath: "/System/Applications/Calculator.app")
        let folder = dataDir.appendingPathComponent("Selftest Folder", isDirectory: true)
        let link = URL(string: "https://example.org/")!
        let realDockBefore = realDockAppCount()

        store.mutate(undoable: false) { lib in
            lib.settings.onboardingDone = true
            lib.settings.checkForUpdates = false
            lib.settings.soundEffects = false
        }

        var apps = UUID()
        var files = UUID()
        var slotID = UUID()
        var profileID = UUID()

        await step("create a group") {
            let before = store.library.groups.count
            let g = store.addGroup(name: store.uniqueGroupName("Selftest Apps"), emoji: nil)
            apps = g.id
            try expect(store.library.groups.count == before + 1, "group count \(store.library.groups.count), wanted \(before + 1)")
            try expect(store.library.slots.contains { $0.groupIDs == [g.id] }, "the new group has no Dock slot")
        }

        await step("add app, folder and link items") {
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            store.insertURLs([calculator, folder], into: apps)
            store.addLink(link, name: nil, to: apps)
            store.insertURLs([calculator], into: apps)
            let items = try group(apps).items
            try expect(items.map(\.kind) == [.app, .folder, .link], "kinds \(items.map(\.kind.rawValue))")
            try expect(items[0].bundleID == "com.apple.calculator", "app bundle ID \(items[0].bundleID ?? "nil")")
        }

        await step("rename group and item") {
            store.renameGroup(apps, to: "  Selftest Tools ")
            let g = try group(apps)
            try expect(g.name == "Selftest Tools", "group name “\(g.name)”")
            try expect(store.library.slots.contains { $0.groupIDs == [apps] && $0.name == "Selftest Tools" },
                       "the group's slot kept its old name")
            let linkItem = try item(apps, link)
            store.renameItem(linkItem.id, in: apps, to: "Example")
            try expect(try item(apps, link).displayName == "Example", "item name “\(try item(apps, link).displayName)”")
        }

        await step("reorder items") {
            let linkItem = try item(apps, link)
            store.reorderItem(linkItem.id, in: apps, to: 0)
            let g = try group(apps)
            try expect(g.items.first?.id == linkItem.id, "first item is \(g.items.first?.displayName ?? "none")")
            try expect(g.sortOrder == .manual, "sort order \(g.sortOrder)")
        }

        await step("move items between groups without duplicates") {
            files = store.addGroup(name: store.uniqueGroupName("Selftest Files"), emoji: nil).id
            store.insertURLs([folder], into: files)
            let folderItem = try item(apps, folder)
            store.moveItem(folderItem.id, from: apps, to: files)
            try expect(try group(apps).items.allSatisfy { $0.url != folder }, "the folder is still in the source group")
            try expect(try group(files).items.filter { $0.url == folder }.count == 1, "the target group has the folder twice")
            let app = try item(apps, calculator)
            store.moveItem(app.id, from: apps, to: files)
            try expect(try group(files).items.filter { $0.kind == .app }.count == 1, "the app did not move once")
            try expect(try group(apps).items.map(\.url) == [link], "source group holds \(try group(apps).items.map(\.displayName))")
        }

        await step("undo and redo") {
            let name = try group(files).name
            store.renameGroup(files, to: "Selftest Renamed")
            store.undo()
            try expect(try group(files).name == name, "undo left “\(try group(files).name)”")
            store.redo()
            try expect(try group(files).name == "Selftest Renamed", "redo left “\(try group(files).name)”")
        }

        await step("undo and redo through ⌘Z and ⇧⌘Z") {
            try expect(pressMenuKey("z", [.command]), "no menu item took ⌘Z")
            try expect(try group(files).name != "Selftest Renamed", "⌘Z did not undo the rename")
            try expect(pressMenuKey("z", [.command, .shift]), "no menu item took ⇧⌘Z")
            try expect(try group(files).name == "Selftest Renamed", "⇧⌘Z did not redo the rename, the name is “\(try group(files).name)”")
        }

        await step("apply a theme") {
            let old = try group(apps)
            guard let theme = ThemeLibrary.builtIn.first(where: { ThemeLibrary.apply($0, to: old.style) != old.style }) else {
                throw Failure(description: "no built-in theme changes the style")
            }
            store.applyTheme(theme, to: apps)
            let g = try group(apps)
            try expect(g.themeID == theme.id, "theme ID \(g.themeID ?? "nil"), wanted \(theme.id)")
            try expect(g.style == ThemeLibrary.apply(theme, to: old.style), "the style is not the theme's style")
        }

        await step("save and reload the store from disk") {
            store.saveNow()
            try expect(fm.fileExists(atPath: store.fileURL.path), "no file at \(store.fileURL.path)")
            let reloaded = LibraryStore(fileURL: store.fileURL)
            let a = try LibraryStore.encoder.encode(store.library)
            let b = try LibraryStore.encoder.encode(reloaded.library)
            try expect(a == b, "the reloaded library differs from the saved one")
            try expect(reloaded.group(apps)?.name == "Selftest Tools", "the reloaded store lost the renamed group")
        }

        await step("build a launcher for a slot with two groups") {
            let slot = store.addSlot(name: "Selftest Slot", groupIDs: [apps, files])
            slotID = slot.id
            let bundle = try dock.installLauncher(for: slot.id)
            try expect(bundle.resolvingSymlinksInPath().path.hasPrefix(launcherDir + "/"), "built outside the test folder: \(bundle.path)")
            let info = try unwrap(LauncherBuilder.readInfo(bundle), "no Info.plist in \(bundle.path)")
            let id = PWShared.launcherBundleIDPrefix + slot.id.uuidString
            try expect(info["CFBundleIdentifier"] as? String == id, "bundle ID \(info["CFBundleIdentifier"] ?? "nil")")
            try expect(info["CFBundleName"] as? String == "Selftest Slot", "bundle name \(info["CFBundleName"] ?? "nil")")
            try expect(info[PWShared.dataDirInfoKey] as? String == dataDir.path, "the launcher reads \(info[PWShared.dataDirInfoKey] ?? "the real data folder")")
            let icns = bundle.appendingPathComponent("Contents/Resources/AppIcon.icns")
            let size = (try? fm.attributesOfItem(atPath: icns.path)[.size] as? Int) ?? 0
            try expect(size > 0, "no AppIcon.icns")
            let png = PWShared.iconURL(id: slot.id.uuidString)
            try expect(fm.fileExists(atPath: png.path) && png.path.hasPrefix(dataDir.path), "no icon PNG in the test data folder")
            // Not --strict: the custom Finder icon is added after signing on purpose.
            do {
                try LauncherBuilder.run("/usr/bin/codesign", ["--verify", bundle.path])
                let details = try LauncherBuilder.run("/usr/bin/codesign", ["--display", "--verbose=2", bundle.path])
                try expect(details.contains("Identifier=\(id)\n"), "signed with another identifier")
            } catch let error as Failure {
                throw error
            } catch {
                throw Failure(description: "code signature: \(error)")
            }
            try expect(store.slot(slot.id)?.launcherPath == bundle.path, "the slot does not know its launcher")
            try expect(store.groups(for: slot.id).map(\.id) == [apps, files], "the slot shows other groups")
        }

        await step("add and remove the slot in the fake Dock") {
            let before = fakeDockApps().count
            dock.addToDock(slotID: slotID)
            try expect(dock.isInDock(slotID: slotID), "not in the Dock after adding")
            try expect(fakeDockApps().count == before + 1, "the Dock plist file has \(fakeDockApps().count) apps, wanted \(before + 1)")
            try expect(store.slot(slotID)?.pinnedInDock == true, "the slot is not marked pinned")
            dock.removeFromDock(slotID: slotID)
            try expect(!dock.isInDock(slotID: slotID), "still in the Dock after removing")
            try expect(fakeDockApps().count == before, "the Dock plist file has \(fakeDockApps().count) apps, wanted \(before)")
        }

        await step("capture and apply a Dock profile") {
            dock.modifyDock { _ in
                [DockPlist.appTile(path: calculator.path, label: "Calculator", bundleID: "com.apple.calculator")]
            }
            let p = try unwrap(profiles.captureCurrent(name: "Selftest Profile"), "capture found an empty Dock")
            profileID = p.id
            try expect(p.tiles.count == 1, "the profile has \(p.tiles.count) tiles, wanted 1")
            dock.addToDock(slotID: slotID)
            try expect(fakeDockApps().count == 2, "the Dock plist file has \(fakeDockApps().count) apps after adding the slot")
            let result = profiles.apply(p.id, skipIfActive: false, interactive: false)
            try expect(result.status == .applied, "apply returned \(result.status)")
            try expect(result.quit.isEmpty && result.launched.isEmpty, "apply quit \(result.quit) and launched \(result.launched)")
            let after = fakeDockApps()
            try expect(after.count == 1 && DockPlist.bundleID(of: after[0]) == "com.apple.calculator",
                       "the Dock plist file holds \(after.compactMap(DockPlist.label(of:)))")
            try expect(profiles.isActive(p.id), "the profile is not active after applying")
            try expect(!dock.isInDock(slotID: slotID), "the Dock manager still sees the slot that the profile removed")
        }

        await step("route pocketwerk:// URLs") {
            let anchor = CGPoint(x: 400, y: 300)
            let open = PWShared.openURL(slotID: slotID.uuidString, at: anchor)
            try expect(PocketwerkRoute.parse(open) == .open(slot: slotID, group: nil, anchor: anchor), "\(open) does not round-trip")

            URLRouter.handle(open)
            await pause(0.1)
            try expect(PopupController.shared.isVisible && PopupController.shared.currentSlotID == slotID, "open?slot showed no popup for the slot")
            URLRouter.handle(open)
            try expect(!PopupController.shared.isVisible, "a second open?slot did not close the popup")

            let byName = try url("pocketwerk://open?group=\(try group(files).name)")
            URLRouter.handle(byName)
            await pause(0.1)
            try expect(PopupController.shared.isVisible && PopupController.shared.currentSlotID == nil, "open?group showed no popup")
            PopupController.shared.hide()

            URLRouter.handle(try url("pocketwerk://add?group=\(files.uuidString)&url=https://example.com/added"))
            try expect(try group(files).items.contains { $0.url.absoluteString == "https://example.com/added" }, "add did not add the link")

            dock.addToDock(slotID: slotID)
            URLRouter.handle(try url("pocketwerk://profile?name=Selftest%20Profile&skip=0"))
            try expect(profiles.lastResult?.status == .applied, "profile?name returned \(profiles.lastResult?.status.rawValue ?? "nothing")")
            try expect(fakeDockApps().count == 1, "profile?name left \(fakeDockApps().count) apps in the Dock plist")

            URLRouter.handle(try url("pocketwerk://settings"))
            await pause(0.2)
            try expect(MainWindowController.shared.isVisible, "settings opened no window")
            closeMainWindow()

            let before = store.library
            try expect(!DockRoutes.handle(try url("pocketwerk://nonsense?id=1")), "an unknown route was handled")
            URLRouter.handle(try url("pocketwerk://nonsense?id=1"))
            try expect(store.library == before, "an unknown route changed the library")
        }

        await step("open and close the popup for a group") {
            PopupController.shared.toggle(groupIDs: [apps], slotID: nil, source: .hotkey)
            try expect(PopupController.shared.isVisible && popupWindowVisible(), "no visible popup window after opening")
            await pause(0.4)
            try expect(PopupController.shared.isVisible && popupWindowVisible(), "the popup closed by itself")
            PopupController.shared.toggle(groupIDs: [apps], slotID: nil, source: .hotkey)
            try expect(!PopupController.shared.isVisible && !popupWindowVisible(), "the popup window is still visible after closing")
        }

        await step("open and close the main window") {
            try expect(pressMenuKey("0", [.command]), "no menu item took ⌘0")
            await pause(0.3)
            try expect(MainWindowController.shared.isVisible, "⌘0 opened no main window")
            closeMainWindow()
            await pause(0.1)
            try expect(!MainWindowController.shared.isVisible, "the main window is still visible after closing")
            MainWindowController.shared.show(selecting: files)
            await pause(0.3)
            try expect(MainWindowController.shared.isVisible, "show(selecting:) opened no main window")
            try expect(MainWindowController.shared.model.selectedGroupID == files, "the window selected another group")
            closeMainWindow()
        }

        await step("assistant phrases in English and German") {
            func ask(_ request: String, _ edits: [(String, String)]) throws -> ItemGroup {
                // The edits stand in for the on-device model; the rest is what AssistantConversation.send does.
                let g = try group(files)
                let outcome = AssistantInterpreter.apply(edits.map { AssistantEditInput(kind: $0.0, value: $0.1) }, to: g,
                                                         themes: store.allThemes, apps: [], defaultStyle: store.settings.defaultStyle,
                                                         request: request)
                if outcome.group != g { store.updateGroup(files) { $0 = outcome.group } }
                return try group(files)
            }
            let blue = try unwrap(AssistantVocabulary.color("blue"), "no color “blue”")
            try expect(try ask("Make it blue", [("color", "blue")]).style.background == .solid(blue), "“Make it blue” gave no blue fill")
            try expect(try ask("Mach die Ecken rund", [("corners", "rund")]).style.cornerRadius == 30, "“Mach die Ecken rund” gave no round corners")
            try expect(try ask("Benenne die Gruppe in Werkzeuge um", [("rename", "Werkzeuge")]).name == "Werkzeuge", "the German rename did nothing")
            if case .gradient(let colors, _) = try ask("Mach einen warmen Farbverlauf", [("gradient", "warm")]).style.background {
                try expect(colors.count >= 2, "the gradient has \(colors.count) colors")
            } else {
                throw Failure(description: "“Mach einen warmen Farbverlauf” gave no gradient")
            }
            let before = try group(files)
            try expect(try ask("What is the weather tomorrow?", [("color", "red")]) == before, "a weather question changed the group")
            try expect(try ask("Wie spät ist es?", [("rename", "Uhr")]) == before, "a German time question changed the group")
        }

        await step("menus: every enabled item has a working action") {
            var problems: [String] = []
            let menuBar = NSMenu()
            for item in MenuBarController.buildItems() { menuBar.addItem(item) }
            let trees: [(String, NSMenu?)] = [("main menu", NSApp.mainMenu), ("menu bar menu", menuBar), ("Dock menu", DockMenus.mainMenu())]
            for (name, menu) in trees {
                guard let menu, menu.numberOfItems > 0 else { problems.append("\(name) is empty"); continue }
                problems += auditActions(menu, path: name)
            }
            try expect(problems.isEmpty, problems.joined(separator: "; "))
        }

        await step("menus: no duplicate key equivalents") {
            var problems: [String] = []
            let menuBar = NSMenu()
            for item in MenuBarController.buildItems() { menuBar.addItem(item) }
            for (name, menu) in [("main menu", NSApp.mainMenu), ("menu bar menu", menuBar), ("Dock menu", DockMenus.mainMenu())] {
                guard let menu else { continue }
                var seen: [String: String] = [:]
                for (item, path) in allItems(menu, path: name) where !item.keyEquivalent.isEmpty {
                    let combo = shortcut(item)
                    if let other = seen[combo] { problems.append("\(combo) on “\(other)” and “\(path)”") }
                    seen[combo] = path
                }
            }
            try expect(problems.isEmpty, problems.joined(separator: "; "))
        }

        await step("default hotkeys have no collisions") {
            var lib = Library()
            for i in 0..<12 { lib.groups.append(ItemGroup(name: "Group \(i)")) }
            func check(_ lib: Library, _ label: String) throws {
                let all = HotkeyPlan.explicitBindings(lib) + HotkeyPlan.defaultGroupBindings(lib)
                let combos = all.map { HotkeyPlan.Combo($0.hotkey) }
                try expect(Set(combos).count == combos.count, "\(label): two targets share a hotkey")
                try expect(HotkeyPlan.conflicts(lib).isEmpty, "\(label): conflicts \(HotkeyPlan.conflicts(lib).count)")
            }
            try check(lib, "twelve groups")
            try expect(HotkeyPlan.defaultGroupBindings(lib).count == 9, "\(HotkeyPlan.defaultGroupBindings(lib).count) number keys, wanted 9")
            lib.settings.mainHotkey = HotkeyFormat.numberHotkey(0)
            try check(lib, "main hotkey on ⌥⇧1")
            try expect(HotkeyPlan.defaultGroupBindings(lib).count == 8, "the ⌥⇧1 default was not given up for the main hotkey")
            try check(store.library, "test library")
            // The automatic ⌥⇧ number keys are global; a menu item on the same keys would never fire.
            let clashes = allItems(try unwrap(NSApp.mainMenu, "no main menu"), path: "main menu").filter { item, _ in
                item.keyEquivalentModifierMask.intersection([.command, .option, .shift, .control]) == [.option, .shift]
                    && item.keyEquivalent.count == 1 && item.keyEquivalent.first!.isNumber
            }
            try expect(clashes.isEmpty, "menu items on ⌥⇧ digits: \(clashes.map(\.1))")
        }

        await step("remove the launcher") {
            let path = try unwrap(store.slot(slotID)?.launcherPath, "the slot has no launcher")
            dock.removeLauncher(for: slotID)
            try expect(!fm.fileExists(atPath: path), "the launcher bundle is still at \(path)")
            try expect(store.slot(slotID)?.launcherPath == nil, "the slot still points to its launcher")
            try expect(!fm.fileExists(atPath: PWShared.iconURL(id: slotID.uuidString).path), "the icon PNG is still there")
        }

        await step("real Dock and install untouched") {
            dock.flushDockChanges()
            try expect(realDockAppCount() == realDockBefore, "the real Dock has \(realDockAppCount()) apps, had \(realDockBefore)")
            let real = fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications/Pocketwerk/Selftest Slot.app")
            try expect(!fm.fileExists(atPath: real.path), "a launcher exists at \(real.path)")
            let realIcon = fm.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/Pocketwerk/Icons/\(slotID.uuidString).png")
            try expect(!fm.fileExists(atPath: realIcon.path), "an icon exists at \(realIcon.path)")
            try expect(profiles.profile(profileID) != nil, "the test profile is gone")
        }

        let seconds = String(format: "%.1f", Date().timeIntervalSince(started))
        let total = passed + failed.count
        print(failed.isEmpty ? "SELFTEST PASS \(total) steps in \(seconds) s"
                             : "SELFTEST FAIL \(failed.count) of \(total) steps in \(seconds) s: \(failed.joined(separator: ", "))")
        finish(code: failed.isEmpty ? 0 : 1)
    }

    // MARK: Helpers

    private static func step(_ name: String, _ body: () async throws -> Void) async {
        do {
            try await body()
            passed += 1
            print("PASS \(name)")
        } catch {
            failed.append(name)
            print("FAIL \(name): \(error)")
        }
        // Close what a failed step left open, so the next step starts clean.
        if PopupController.shared.isVisible { PopupController.shared.hide() }
    }

    private static func expect(_ ok: Bool, _ reason: @autoclosure () throws -> String) throws {
        if !ok { throw Failure(description: try reason()) }
    }

    private static func unwrap<T>(_ value: T?, _ reason: @autoclosure () -> String) throws -> T {
        guard let value else { throw Failure(description: reason()) }
        return value
    }

    private static func group(_ id: UUID) throws -> ItemGroup {
        try unwrap(LibraryStore.shared.group(id), "group \(id) is gone")
    }

    private static func item(_ groupID: UUID, _ url: URL) throws -> DockItem {
        try unwrap(group(groupID).items.first { $0.url == url }, "no item \(url.lastPathComponent) in the group")
    }

    private static func url(_ string: String) throws -> URL {
        let encoded = string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed.union(["%"])) ?? string
        return try unwrap(URL(string: encoded), "bad URL \(string)")
    }

    /// Lets the run loop draw windows and run timers.
    private static func pause(_ seconds: Double) async {
        try? await Task.sleep(for: .seconds(seconds))
    }

    /// Sends a key equivalent to the main menu, as a key press would. The event is built from the
    /// key code of the current keyboard layout (on German keyboards Z and Y swap), never posted.
    private static func pressMenuKey(_ key: String, _ modifiers: NSEvent.ModifierFlags) -> Bool {
        guard let code = KeyboardLayout.keyCode(for: key),
              let cg = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(code), keyDown: true) else { return false }
        var flags: CGEventFlags = []
        if modifiers.contains(.command) { flags.insert(.maskCommand) }
        if modifiers.contains(.shift) { flags.insert(.maskShift) }
        if modifiers.contains(.option) { flags.insert(.maskAlternate) }
        if modifiers.contains(.control) { flags.insert(.maskControl) }
        cg.flags = flags
        guard let event = NSEvent(cgEvent: cg) else { return false }
        return NSApp.mainMenu?.performKeyEquivalent(with: event) ?? false
    }

    private static func popupWindowVisible() -> Bool {
        NSApp.windows.contains { $0 is PopupPanel && $0.isVisible }
    }

    private static func closeMainWindow() {
        for w in NSApp.windows where w.isVisible && w.delegate === MainWindowController.shared { w.performClose(nil) }
    }

    /// Every item with its menu path, depth first.
    private static func allItems(_ menu: NSMenu, path: String) -> [(NSMenuItem, String)] {
        menu.items.flatMap { item -> [(NSMenuItem, String)] in
            // Hidden items and section headers (macOS adds some to Edit and Window) are never chosen.
            guard !item.isSeparatorItem, !item.isHidden, !item.isSectionHeader else { return [] }
            let title = item.submenu.flatMap { $0.title.isEmpty ? nil : $0.title } ?? item.title
            let here = "\(path) > \(title)"
            return [(item, here)] + (item.submenu.map { allItems($0, path: here) } ?? [])
        }
    }

    /// Enabled leaf items need an action and something that answers it.
    private static func auditActions(_ menu: NSMenu, path: String) -> [String] {
        allItems(menu, path: path).compactMap { item, here in
            guard item.isEnabled, item.submenu == nil else { return nil }
            guard let action = item.action else { return "\(here) has no action" }
            if let target = item.target {
                return target.responds(to: action) ? nil : "\(here): target does not answer \(action)"
            }
            // Responder-chain items: the app, a window or a text view answers them.
            let answered = NSApp.target(forAction: action, to: nil, from: item) != nil
                || NSWindow.instancesRespond(to: action) || NSTextView.instancesRespond(to: action)
            return answered ? nil : "\(here): nothing answers \(action)"
        }
    }

    /// "⇧⌘Z" style key of a menu item, for duplicate checks.
    private static func shortcut(_ item: NSMenuItem) -> String {
        var mods = item.keyEquivalentModifierMask.intersection([.command, .option, .shift, .control])
        let key = item.keyEquivalent
        if key.count == 1, key.lowercased() != key { mods.insert(.shift) }
        var s = ""
        if mods.contains(.control) { s += "⌃" }
        if mods.contains(.option) { s += "⌥" }
        if mods.contains(.shift) { s += "⇧" }
        if mods.contains(.command) { s += "⌘" }
        return s + key.uppercased()
    }

    private static func fakeDockApps() -> [DockPlist.Entry] {
        guard let path = ProcessInfo.processInfo.environment["POCKETWERK_DOCK_PLIST"],
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return [] }
        return dict[DockPlist.appsKey] as? [DockPlist.Entry] ?? []
    }

    /// Read only: number of apps in the real Dock, to prove the run never wrote to it.
    private static func realDockAppCount() -> Int {
        (CFPreferencesCopyAppValue(DockPlist.appsKey as CFString, "com.apple.dock" as CFString) as? [Any])?.count ?? -1
    }

    /// Quits through NSApp.terminate, never exit(), and closes sheets first:
    /// an open sheet refuses terminate, and the run would wait forever.
    private static func finish(code: Int32) {
        exitCode = code
        LibraryStore.shared.saveNow()
        DockManager.shared.flushDockChanges()
        for window in NSApp.windows { if let sheet = window.attachedSheet { window.endSheet(sheet) } }
        NSApp.terminate(nil)
    }
}
