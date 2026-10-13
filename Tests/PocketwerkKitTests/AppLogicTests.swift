import Carbon.HIToolbox
import Foundation
import Testing
@testable import PocketwerkKit

private func tempStore() -> LibraryStore {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("pw-app-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return LibraryStore(fileURL: dir.appendingPathComponent("library.json"))
}

private func file(_ path: String, name: String? = nil, added: Double = 0, opened: Double? = nil, count: Int = 0) -> DockItem {
    var item = DockItem(kind: .file, url: URL(fileURLWithPath: path), customName: name)
    item.addedAt = Date(timeIntervalSince1970: added)
    item.lastOpenedAt = opened.map { Date(timeIntervalSince1970: $0) }
    item.openCount = count
    return item
}

private func app(_ bundleID: String, _ path: String, count: Int = 0) -> DockItem {
    var item = DockItem(kind: .app, url: URL(fileURLWithPath: path))
    item.bundleID = bundleID
    item.openCount = count
    return item
}

// MARK: - Sorting and ordering

@Suite struct AppSortingTests {
    func sample() -> ItemGroup {
        var g = ItemGroup(name: "S")
        g.items = [
            file("/x/banana.txt", added: 1, opened: 30, count: 2),
            file("/x/apple.txt", added: 3, opened: nil, count: 9),
            file("/x/cherry.txt", name: "Aardvark", added: 2, opened: 50, count: 0),
        ]
        var link = DockItem(kind: .link, url: URL(string: "https://zeta.example")!)
        link.addedAt = Date(timeIntervalSince1970: 0)
        g.items.append(link)
        return g
    }

    func names(_ g: ItemGroup) -> [String] { g.sortedItems.map(\.displayName) }

    @Test func manualKeepsOrder() {
        #expect(names(sample()) == ["banana.txt", "apple.txt", "Aardvark", "zeta.example"])
    }

    @Test func nameUsesCustomNames() {
        var g = sample(); g.sortOrder = .name
        #expect(names(g) == ["Aardvark", "apple.txt", "banana.txt", "zeta.example"])
    }

    @Test func otherOrders() {
        var g = sample()
        g.sortOrder = .dateAdded
        #expect(names(g).prefix(3) == ["apple.txt", "Aardvark", "banana.txt"])
        g.sortOrder = .lastOpened
        #expect(names(g).prefix(2) == ["Aardvark", "banana.txt"])
        g.sortOrder = .mostOpened
        #expect(names(g).first == "apple.txt")
        g.sortOrder = .kind
        #expect(names(g).last == "zeta.example")
    }

    @Test func pinnedFirstAndCarousel() {
        var lib = Library()
        var a = ItemGroup(name: "A"); let b = ItemGroup(name: "B"); var c = ItemGroup(name: "C")
        c.pinned = true
        a.hiddenFromAll = true
        var most = ItemGroup(name: "Most"); most.smart = .mostUsed
        lib.groups = [a, b, c, most]
        #expect(lib.orderedGroups.map(\.name) == ["C", "A", "B", "Most"])
        #expect(lib.carouselGroups.map(\.name) == ["C", "B", "Most"])
        lib.settings.showMostUsed = false
        #expect(lib.carouselGroups.map(\.name) == ["C", "B"])
        #expect(lib.regularGroups.map(\.name) == ["C", "A", "B"])
    }

    @Test func dragKeepsPinnedOnTop() {
        var lib = Library()
        var p = ItemGroup(name: "P"); p.pinned = true
        lib.groups = [ItemGroup(name: "A"), ItemGroup(name: "B"), p]
        // Shown: P, A, B. Drag B to the very top: it stays below the pinned group.
        let moved = GroupOrdering.move(lib, from: IndexSet(integer: 2), to: 0)
        #expect(moved.map(\.name) == ["P", "B", "A"])
    }

    @Test func reorderInSortedListBecomesManual() {
        let store = tempStore()
        let g = store.addGroup(name: "R")
        store.updateGroup(g.id) { $0.items = sample().items; $0.sortOrder = .name }
        let banana = store.group(g.id)!.items[0].id
        store.reorderItem(banana, in: g.id, to: 0)
        let after = store.group(g.id)!
        #expect(after.sortOrder == .manual)
        #expect(after.items.map(\.displayName) == ["banana.txt", "Aardvark", "apple.txt", "zeta.example"])
    }

    @Test func moveBetweenGroupsWithoutDuplicates() {
        let store = tempStore()
        let a = store.addGroup(name: "A"), b = store.addGroup(name: "B")
        let mail = app("com.apple.mail", "/System/Applications/Mail.app")
        store.updateGroup(a.id) { $0.items = [mail] }
        store.updateGroup(b.id) { $0.items = [app("com.apple.mail", "/Applications/Mail.app")] }
        store.moveItem(mail.id, from: a.id, to: b.id)
        #expect(store.group(a.id)!.items.isEmpty)
        #expect(store.group(b.id)!.items.count == 1)
    }

    @Test func renameAndClearItem() {
        let store = tempStore()
        let g = store.addGroup(name: "N")
        let item = file("/x/report.pdf")
        store.updateGroup(g.id) { $0.items = [item] }
        store.renameItem(item.id, in: g.id, to: "  Report  ")
        #expect(store.group(g.id)!.items[0].displayName == "Report")
        store.renameItem(item.id, in: g.id, to: "")
        #expect(store.group(g.id)!.items[0].customName == nil)
    }

    @Test func toggleAppAddsAndRemoves() {
        let store = tempStore()
        let g = store.addGroup(name: "T")
        let url = URL(fileURLWithPath: "/System/Applications/Calculator.app")
        store.toggleApp(url: url, bundleID: "com.apple.calculator", in: g.id)
        #expect(store.group(g.id)!.items.count == 1)
        store.toggleApp(url: url, bundleID: "com.apple.calculator", in: g.id)
        #expect(store.group(g.id)!.items.isEmpty)
    }

    @Test func linksAreNormalized() {
        #expect(GroupOrdering.normalizedLink("example.com")?.absoluteString == "https://example.com")
        #expect(GroupOrdering.normalizedLink("example.com:8080/x")?.absoluteString == "https://example.com:8080/x")
        #expect(GroupOrdering.normalizedLink("https://a.b/c")?.absoluteString == "https://a.b/c")
        #expect(GroupOrdering.normalizedLink("mailto:me@example.com") != nil)
        #expect(GroupOrdering.normalizedLink("hello world") == nil)
        #expect(GroupOrdering.normalizedLink("word") == nil)
        #expect(GroupOrdering.links(in: "see https://a.example and www.apple.com.").count == 2)
    }
}

// MARK: - Smart groups and usage

@Suite struct AppSmartGroupTests {
    let mailURL = URL(fileURLWithPath: "/Apps/Mail.app")
    let xcodeURL = URL(fileURLWithPath: "/Apps/Xcode.app")

    func library() -> Library {
        var lib = Library()
        var g = ItemGroup(name: "Work")
        var notes = file("/x/notes.txt", opened: 100, count: 3)
        notes.customName = "Notes"
        g.items = [app("com.apple.mail", mailURL.path, count: 1), notes]
        lib.groups = [g]
        lib.usage.launches = ["com.apple.mail": 5, "com.apple.dt.Xcode": 4, "gone.app": 50]
        lib.usage.lastLaunch = ["com.apple.dt.Xcode": Date(timeIntervalSince1970: 200)]
        return lib
    }

    func resolve(_ id: String) -> URL? {
        ["com.apple.mail": mailURL, "com.apple.dt.Xcode": xcodeURL][id]
    }

    @Test func mostUsedCombinesLaunchesAndOpens() {
        let items = SmartGroups.items(.mostUsed, library: library(), limit: 10, resolveApp: resolve, runningApps: [])
        // Mail 5 + 1, Xcode 4, Notes 3. Uninstalled apps are skipped.
        #expect(items.map(\.displayName) == ["Mail", "Xcode", "Notes"])
        let limited = SmartGroups.items(.mostUsed, library: library(), limit: 1, resolveApp: resolve, runningApps: [])
        #expect(limited.count == 1)
    }

    @Test func recentlyOpenedUsesBothSources() {
        let items = SmartGroups.items(.recentlyOpened, library: library(), limit: 10, resolveApp: resolve, runningApps: [])
        #expect(items.map(\.displayName) == ["Xcode", "Notes"])
    }

    @Test func runningAppsPreferGroupItems() {
        let lib = library()
        let items = SmartGroups.items(.runningApps, library: lib, limit: 10, resolveApp: resolve,
                                      runningApps: [mailURL, xcodeURL])
        #expect(items.count == 2)
        #expect(items[0].id == lib.groups[0].items[0].id)
    }

    @Test func stableIDs() {
        #expect(SmartGroups.stableID("com.a") == SmartGroups.stableID("com.a"))
        #expect(SmartGroups.stableID("com.a") != SmartGroups.stableID("com.b"))
    }

    @Test func usageRecording() {
        var usage = UsageStats()
        let t = Date(timeIntervalSince1970: 1000)
        UsageTracker.record(bundleID: "a", at: t, in: &usage)
        UsageTracker.record(bundleID: "b", at: t.addingTimeInterval(60), in: &usage)
        UsageTracker.record(bundleID: "a", at: t.addingTimeInterval(4000), in: &usage)
        #expect(usage.launches == ["a": 2, "b": 1])
        #expect(usage.coOccurrence["a"]?["b"] == 1)
        #expect(UsageTracker.counts("io.github.digitaliq.pocketwerk.slot.X") == false)
    }

    @Test func missingItemsByBundleIDThenPath() {
        var moved = app("com.moved", "/Old/Moved.app")
        moved.id = UUID()
        let gone = app("com.gone", "/Old/Gone.app")
        let present = file("/here.txt")
        let lost = file("/lost.txt")
        let link = DockItem(kind: .link, url: URL(string: "https://x.example")!)
        let result = MissingItems.check([moved, gone, present, lost, link],
                                        locate: { $0 == "com.moved" ? URL(fileURLWithPath: "/New/Moved.app") : nil },
                                        exists: { $0 == "/here.txt" || $0 == "/New/Moved.app" })
        #expect(result.relinked[moved.id]?.path == "/New/Moved.app")
        #expect(result.missing == [gone.id, lost.id])
    }
}

// MARK: - Updates

@Suite struct AppUpdateTests {
    @Test func semanticVersions() throws {
        func v(_ s: String) throws -> SemanticVersion { try #require(SemanticVersion(s)) }
        #expect(try v("1.0") < v("1.0.1"))
        #expect(try v("1.9") < v("1.10"))
        #expect(try v("v2.0.0") == v("2"))
        #expect(try v("1.2.0-beta.2") < v("1.2.0"))
        #expect(try v("1.2.0-beta.2") < v("1.2.0-beta.10"))
        #expect(try !(v("1.2.0") < v("1.2.0-rc.1")))
        #expect(SemanticVersion("abc") == nil)
        #expect(SemanticVersion("") == nil)
    }

    @Test func newerAndSkipped() {
        #expect(Release.isNewer("v1.1.0", than: "1.0", skipped: nil))
        #expect(!Release.isNewer("1.0.0", than: "1.0", skipped: nil))
        #expect(!Release.isNewer("1.1.0", than: "1.0", skipped: "v1.1"))
        #expect(Release.isNewer("1.2.0", than: "1.0", skipped: "1.1.0"))
    }

    @Test func parseRelease() throws {
        let json = #"{"tag_name":"v1.2.0","html_url":"https://github.com/DigitalIQ/pocketwerk/releases/tag/v1.2.0","name":"Pocketwerk 1.2","draft":false,"prerelease":false}"#
        let r = try #require(Release.parse(Data(json.utf8)))
        #expect(r.version == "v1.2.0")
        let pre = #"{"tag_name":"v2.0.0-beta","html_url":"https://x.example","prerelease":true}"#
        #expect(Release.parse(Data(pre.utf8)) == nil)
    }
}

// MARK: - Import

@Suite struct AppImportTests {
    func libs() -> (current: Library, imported: Library) {
        var current = Library()
        let work = ItemGroup(name: "Work")
        current.groups = [work]
        current.slots = [DockSlot(name: "Work", groupIDs: [work.id])]
        current.settings.launchAtLogin = true
        current.settings.syncFolderPath = "/Sync"
        current.usage.launches = ["a": 3]

        var imported = Library()
        var importedWork = ItemGroup(name: "work") // same name, other id
        importedWork.items = [file("/x/a.txt")]
        var games = ItemGroup(name: "Games")
        games.items = [app("com.not.installed", "/Apps/Nope.app")]
        imported.groups = [importedWork, games]
        var slot = DockSlot(name: "Games", groupIDs: [games.id, importedWork.id])
        slot.launcherPath = "/Users/other/Applications/Pocketwerk/Games.app"
        imported.slots = [slot]
        imported.profiles = [DockProfile(name: "Coding", plistData: Data())]
        imported.settings.launchAtLogin = false
        imported.settings.closeAfterOpen = false
        imported.usage.launches = ["a": 1, "b": 2]
        return (current, imported)
    }

    @Test func summaryListsConflicts() {
        let (cur, imp) = libs()
        let s = LibraryMerge.summary(current: cur, imported: imp) { $0.bundleID != "com.not.installed" }
        #expect(s.newGroups == ["Games"])
        #expect(s.existingGroups == ["work"])
        #expect(s.newProfiles == ["Coding"])
        #expect(s.missingApps.count == 1)
        #expect(s.totalItems == 2)
    }

    @Test func mergeOnlyAdds() {
        let (cur, imp) = libs()
        let (lib, rebuild) = LibraryMerge.merge(current: cur, imported: imp)
        #expect(lib.groups.map(\.name) == ["Work", "Games"])
        #expect(lib.groups[0].items.isEmpty) // existing group untouched
        #expect(lib.slots.count == 2)
        #expect(lib.slots[1].groupIDs == [imp.groups[1].id]) // skipped group dropped from the slot
        #expect(lib.slots[1].launcherPath == nil)
        #expect(rebuild == [imp.slots[0].id])
        #expect(lib.profiles.count == 1)
        #expect(lib.settings.launchAtLogin == true)
        #expect(lib.usage.launches == ["a": 3, "b": 2])
        // Merging twice adds nothing more.
        let again = LibraryMerge.merge(current: lib, imported: imp).library
        #expect(again.groups.count == 2 && again.slots.count == 2 && again.profiles.count == 1)
    }

    @Test func replaceKeepsMachineSettings() {
        let (cur, imp) = libs()
        let (lib, rebuild) = LibraryMerge.replace(current: cur, imported: imp)
        #expect(lib.groups.map(\.name) == ["work", "Games"])
        #expect(lib.settings.closeAfterOpen == false)
        #expect(lib.settings.launchAtLogin == true)
        #expect(lib.settings.syncFolderPath == "/Sync")
        #expect(lib.settings.onboardingDone)
        #expect(lib.slots.allSatisfy { $0.launcherPath == nil })
        #expect(rebuild.count == 1)
    }

    @Test func storeReplaceIsUndoable() {
        let store = tempStore()
        let before = store.library
        let (_, imp) = libs()
        store.replace(with: LibraryMerge.replace(current: before, imported: imp).library)
        #expect(store.library.groups.count == 2)
        store.undo()
        #expect(store.library == before)
    }
}

// MARK: - Hotkeys

@Suite struct AppHotkeyTests {
    let noLayout: (UInt32) -> String? = { _ in nil }

    @Test func describesSpecialKeys() {
        let cmd = HotkeyFormat.command, opt = HotkeyFormat.option, shift = HotkeyFormat.shift, ctrl = HotkeyFormat.control
        #expect(HotkeyFormat.describe(Hotkey(keyCode: UInt32(kVK_Return), modifiers: cmd), translate: noLayout) == "⌘↩")
        #expect(HotkeyFormat.describe(Hotkey(keyCode: UInt32(kVK_Space), modifiers: ctrl | opt), translate: noLayout) == "⌃⌥Space")
        #expect(HotkeyFormat.describe(Hotkey(keyCode: UInt32(kVK_F5), modifiers: 0), translate: noLayout) == "F5")
        #expect(HotkeyFormat.describe(Hotkey(keyCode: UInt32(kVK_LeftArrow), modifiers: shift | cmd), translate: noLayout) == "⇧⌘←")
        #expect(HotkeyFormat.describe(Hotkey(keyCode: UInt32(kVK_Escape), modifiers: opt), translate: noLayout) == "⌥⎋")
        // Modifier order is always ⌃⌥⇧⌘.
        #expect(HotkeyFormat.modifierSymbols(cmd | shift | opt | ctrl) == "⌃⌥⇧⌘")
    }

    @Test func describesLetters() {
        let p = Hotkey(keyCode: UInt32(kVK_ANSI_P), modifiers: HotkeyFormat.control | HotkeyFormat.option)
        #expect(HotkeyFormat.describe(p, translate: noLayout) == "⌃⌥P")
        // The layout wins over the US table (German: the Y key position types Z).
        #expect(HotkeyFormat.describe(Hotkey(keyCode: UInt32(kVK_ANSI_Y), modifiers: HotkeyFormat.command),
                                      translate: { _ in "z" }) == "⌘Z")
        #expect(HotkeyFormat.describe(Hotkey(keyCode: UInt32(kVK_ANSI_1), modifiers: HotkeyFormat.option | HotkeyFormat.shift),
                                      translate: noLayout) == "⌥⇧1")
        // Live layout: key A is A on QWERTY and QWERTZ.
        let live = HotkeyCenter.describe(Hotkey(keyCode: UInt32(kVK_ANSI_A), modifiers: HotkeyFormat.command))
        #expect(live.hasPrefix("⌘") && live.count == 2)
    }

    @Test func numberDefaultsAndConflicts() {
        var lib = Library()
        var a = ItemGroup(name: "A"); let b = ItemGroup(name: "B"); var c = ItemGroup(name: "C")
        a.hotkey = Hotkey(keyCode: UInt32(kVK_ANSI_W), modifiers: HotkeyFormat.option)
        // C takes ⌥⇧2, which would otherwise be B's default.
        c.hotkey = HotkeyFormat.numberHotkey(1)
        lib.groups = [a, b, c]
        let defaults = HotkeyPlan.defaultGroupBindings(lib)
        #expect(defaults.isEmpty) // A has its own, B's ⌥⇧2 is taken, C has its own
        #expect(HotkeyPlan.effectiveHotkey(forGroup: c.id, in: lib)?.hotkey == HotkeyFormat.numberHotkey(1))

        lib.groups[2].hotkey = nil
        #expect(HotkeyPlan.effectiveHotkey(forGroup: b.id, in: lib)?.hotkey == HotkeyFormat.numberHotkey(1))
        #expect(HotkeyPlan.effectiveHotkey(forGroup: c.id, in: lib)?.hotkey == HotkeyFormat.numberHotkey(2))

        lib.settings.mainHotkey = a.hotkey
        let conflicts = HotkeyPlan.conflicts(lib)
        #expect(conflicts.count == 1)
        #expect(conflicts[0].targets == [.main, .group(a.id)])
        #expect(HotkeyPlan.bindings(lib).filter { $0.hotkey == a.hotkey }.count == 1)
        #expect(HotkeyPlan.owner(of: a.hotkey!, in: lib, excluding: .main) == .group(a.id))
        // Automatic number keys never block a user hotkey.
        #expect(HotkeyPlan.owner(of: HotkeyFormat.numberHotkey(1)!, in: lib, excluding: .group(a.id)) == nil)

        lib.settings.numberHotkeys = false
        #expect(HotkeyPlan.defaultGroupBindings(lib).isEmpty)
    }

    @Test func validatorRejectsBareKeys() {
        let bare = Hotkey(keyCode: UInt32(kVK_ANSI_K), modifiers: HotkeyFormat.shift)
        #expect(HotkeyValidator.problem(for: bare, target: .main, in: Library()) != nil)
    }

    @Test func nextProfileCycles() {
        var lib = Library()
        let p1 = DockProfile(name: "1", plistData: Data())
        var p2 = DockProfile(name: "2", plistData: Data()); p2.excludedFromCycle = true
        let p3 = DockProfile(name: "3", plistData: Data())
        lib.profiles = [p1, p2, p3]
        #expect(HotkeyPlan.nextProfile(lib) == p1.id)
        lib.settings.lastAppliedProfileID = p1.id
        #expect(HotkeyPlan.nextProfile(lib) == p3.id)
        lib.settings.lastAppliedProfileID = p3.id
        #expect(HotkeyPlan.nextProfile(lib) == p1.id)
    }
}

// MARK: - App drawer

@Suite struct AppDrawerLogicTests {
    @Test func categoryNames() {
        #expect(AppScanner.categoryName("public.app-category.developer-tools") == "Developer Tools")
        #expect(AppScanner.categoryName("public.app-category.graphics-design") == "Graphics & Design")
        #expect(AppScanner.categoryName("public.app-category.puzzle-games") == "Games")
        #expect(AppScanner.categoryName("com.example.other") == nil)
        #expect(AppScanner.isAgent(["LSUIElement": true]))
        #expect(AppScanner.isAgent(["LSUIElement": "1"]))
        #expect(!AppScanner.isAgent([:]))
    }

    @Test func queryFiltersAndSorts() {
        let now = Date(timeIntervalSince1970: 100 * 86400)
        let apps = [
            AppInfo(url: URL(fileURLWithPath: "/A/Zed.app"), name: "Zed", bundleID: "z", category: "Developer Tools",
                    installedAt: now.addingTimeInterval(-86400)),
            AppInfo(url: URL(fileURLWithPath: "/A/Alpha.app"), name: "Alpha", bundleID: "a", category: "Games",
                    installedAt: now.addingTimeInterval(-90 * 86400)),
            AppInfo(url: URL(fileURLWithPath: "/A/Mid.app"), name: "Mid", bundleID: "m", category: nil, installedAt: nil),
        ]
        func q(_ search: String = "", _ cats: Set<String> = [], _ f: AppFilter = .all, _ s: AppSort = .name) -> [String] {
            AppQuery.apply(apps, search: search, categories: cats, filter: f, sort: s, now: now,
                           inGroup: { $0.bundleID == "m" }, inAnyGroup: { $0.bundleID != "z" }).map(\.name)
        }
        #expect(q() == ["Alpha", "Mid", "Zed"])
        #expect(q("ze") == ["Zed"])
        #expect(q("", ["Games", "Other"]) == ["Alpha", "Mid"])
        #expect(q("", [], .notInAnyGroup) == ["Zed"])
        #expect(q("", [], .inThisGroup) == ["Mid"])
        #expect(q("", [], .recentlyInstalled) == ["Zed"])
        #expect(q("", [], .all, .recentlyInstalled) == ["Zed", "Alpha", "Mid"])
        #expect(AppQuery.categories(apps) == ["Developer Tools", "Games", "Other"])
    }

    @Test func scanFindsSystemApps() {
        let apps = AppScanner.scan(paths: ["/System/Applications"], skipAgents: true)
        #expect(apps.contains { $0.bundleID == "com.apple.calculator" })
        // One subfolder level: Utilities.
        #expect(apps.contains { $0.url.path.contains("/Utilities/") })
    }

    @Test func starterGroupsUseInstalledAppsOnly() {
        let starters = StarterGroups.build { $0 == "com.apple.Terminal" ? URL(fileURLWithPath: "/T.app") : nil }
        #expect(starters.map(\.name) == ["Utilities"])
        #expect(starters[0].apps.count == 1)
    }
}
