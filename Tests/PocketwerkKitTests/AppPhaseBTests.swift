import Carbon.HIToolbox
import Foundation
import Testing
@testable import PocketwerkKit

private let opt = HotkeyFormat.option, shift = HotkeyFormat.shift, ctrl = HotkeyFormat.control

private func step(_ code: Int, _ mods: UInt32 = 0) -> HotkeyStep { HotkeyStep(keyCode: UInt32(code), modifiers: mods) }

// MARK: - Multi-press, sequences, leader

@Suite struct AppHotkeyResolverTests {
    let a = UUID(), b = UUID(), c = UUID()

    func bindings() -> [HotkeyBinding] {
        let base = Hotkey(keyCode: UInt32(kVK_ANSI_G), modifiers: ctrl | opt)
        var double = base; double.tapCount = 2
        var seq = base; seq.sequence = [Hotkey(keyCode: UInt32(kVK_ANSI_W), modifiers: 0)]
        return [.init(target: .group(a), hotkey: base), .init(target: .group(b), hotkey: double),
                .init(target: .group(c), hotkey: seq),
                .init(target: .main, hotkey: Hotkey(keyCode: UInt32(kVK_ANSI_M), modifiers: ctrl | opt))]
    }

    @Test func plainHotkeyFiresAtOnce() {
        var r = HotkeyResolver(bindings: bindings())
        #expect(r.press(step(kVK_ANSI_M, ctrl | opt), at: Date()) == .fire(.main))
        #expect(!r.isWaiting)
    }

    @Test func singlePressWaitsThenFires() {
        var r = HotkeyResolver(bindings: bindings())
        let t = Date()
        guard case .wait(_, let next) = r.press(step(kVK_ANSI_G, ctrl | opt), at: t) else { Issue.record("expected wait"); return }
        #expect(next == [step(kVK_ANSI_W)])
        #expect(r.timeout() == .group(a))
    }

    @Test func doublePress() {
        var r = HotkeyResolver(bindings: bindings())
        let t = Date()
        _ = r.press(step(kVK_ANSI_G, ctrl | opt), at: t)
        #expect(r.press(step(kVK_ANSI_G, ctrl | opt), at: t.addingTimeInterval(0.2)) == .fire(.group(b)))
    }

    @Test func slowSecondPressStartsOver() {
        var r = HotkeyResolver(bindings: bindings())
        let t = Date()
        _ = r.press(step(kVK_ANSI_G, ctrl | opt), at: t)
        let out = r.press(step(kVK_ANSI_G, ctrl | opt), at: t.addingTimeInterval(1))
        guard case .wait = out else { Issue.record("expected a new wait"); return }
        #expect(r.taps == 1)
    }

    @Test func sequenceCompletes() {
        var r = HotkeyResolver(bindings: bindings())
        let t = Date()
        _ = r.press(step(kVK_ANSI_G, ctrl | opt), at: t)
        #expect(r.press(step(kVK_ANSI_W), at: t.addingTimeInterval(0.5)) == .fire(.group(c)))
    }

    @Test func wrongFollowUpDoesNothing() {
        var r = HotkeyResolver(bindings: bindings())
        _ = r.press(step(kVK_ANSI_G, ctrl | opt), at: Date())
        #expect(r.press(step(kVK_ANSI_Q), at: Date()) == .nothing)
        #expect(r.timeout() == nil)
    }

    @Test func leaderLettersBecomeSequences() {
        var lib = Library()
        var g = ItemGroup(name: "Work"); g.leaderKey = "W"
        var p = DockProfile(name: "Coding", plistData: Data()); p.leaderKey = "c"
        lib.groups = [g]
        lib.profiles = [p]
        #expect(HotkeyPlan.leaderBindings(lib).isEmpty) // no leader set
        lib.settings.leaderHotkey = Hotkey(keyCode: UInt32(kVK_Space), modifiers: ctrl | opt)
        let leader = HotkeyPlan.leaderBindings(lib)
        #expect(leader.count == 2)
        #expect(leader[0].target == .group(g.id) && leader[0].viaLeader)
        #expect(leader[0].hotkey.steps == [step(kVK_Space, ctrl | opt), step(kVK_ANSI_W)])
        #expect(leader[1].hotkey.steps.last == step(kVK_ANSI_C))
        // Leader bindings never count as the group's own shortcut badge.
        #expect(HotkeyPlan.effectiveHotkey(forGroup: g.id, in: lib)?.viaLeader != true)
        // One registration for the leader key.
        #expect(HotkeyPlan.rootSteps(HotkeyPlan.bindings(lib)).filter { $0 == step(kVK_Space, ctrl | opt) }.count == 1)

        var r = HotkeyResolver(bindings: HotkeyPlan.bindings(lib))
        guard case .wait(_, let next) = r.press(step(kVK_Space, ctrl | opt), at: Date()) else { Issue.record("expected wait"); return }
        #expect(Set(next) == [step(kVK_ANSI_W), step(kVK_ANSI_C)])
        #expect(r.press(step(kVK_ANSI_C), at: Date()) == .fire(.profile(p.id)))
    }

    @Test func sameLetterTwiceIsAConflict() {
        var lib = Library()
        var g1 = ItemGroup(name: "A"); g1.leaderKey = "A"
        var g2 = ItemGroup(name: "B"); g2.leaderKey = "a"
        lib.groups = [g1, g2]
        lib.settings.leaderHotkey = Hotkey(keyCode: UInt32(kVK_Space), modifiers: ctrl | opt)
        #expect(HotkeyPlan.conflicts(lib).count == 1)
    }

    @Test func doublePressDoesNotConflictWithSinglePress() {
        var lib = Library()
        var g1 = ItemGroup(name: "A"); g1.hotkey = Hotkey(keyCode: UInt32(kVK_ANSI_K), modifiers: opt)
        var g2 = ItemGroup(name: "B"); g2.hotkey = Hotkey(keyCode: UInt32(kVK_ANSI_K), modifiers: opt, tapCount: 2)
        lib.groups = [g1, g2]
        #expect(HotkeyPlan.conflicts(lib).isEmpty)
        #expect(HotkeyPlan.bindings(lib).count >= 2)
        #expect(HotkeyCenter.describe(g2.hotkey!).hasSuffix("×2"))
    }
}

// MARK: - Hot corner

@Suite struct AppHotCornerTests {
    let frame = CGRect(x: 0, y: 0, width: 1440, height: 900)

    @Test func corners() {
        #expect(HotCornerGeometry.isInCorner(CGPoint(x: 0, y: 899), corner: 0, frame: frame))
        #expect(HotCornerGeometry.isInCorner(CGPoint(x: 1439, y: 899), corner: 1, frame: frame))
        #expect(HotCornerGeometry.isInCorner(CGPoint(x: 1, y: 1), corner: 2, frame: frame))
        #expect(HotCornerGeometry.isInCorner(CGPoint(x: 1439, y: 0), corner: 3, frame: frame))
        #expect(!HotCornerGeometry.isInCorner(CGPoint(x: 20, y: 899), corner: 0, frame: frame))
        #expect(!HotCornerGeometry.isInCorner(CGPoint(x: 0, y: 899), corner: 3, frame: frame))
        // Second screen to the right.
        let right = CGRect(x: 1440, y: 0, width: 1920, height: 1080)
        #expect(HotCornerGeometry.isInCorner(CGPoint(x: 3359, y: 1079), corner: 1, frame: right))
    }
}

// MARK: - Assistant edits

@Suite struct AppAssistantTests {
    let apps = [
        AppInfo(url: URL(fileURLWithPath: "/Applications/Pages.app"), name: "Pages", bundleID: "com.apple.iWork.Pages", category: "Productivity"),
        AppInfo(url: URL(fileURLWithPath: "/Applications/Numbers.app"), name: "Numbers", bundleID: "com.apple.iWork.Numbers", category: "Productivity"),
        AppInfo(url: URL(fileURLWithPath: "/System/Applications/Music.app"), name: "Music", bundleID: "com.apple.Music", category: "Music"),
    ]

    func group() -> ItemGroup {
        var g = ItemGroup(name: "Office")
        var item = DockItem(kind: .app, url: URL(fileURLWithPath: "/Applications/Pages.app"))
        item.bundleID = "com.apple.iWork.Pages"
        g.items = [item, DockItem(kind: .link, url: URL(string: "https://example.com")!)]
        g.usesDefaultStyle = true
        return g
    }

    func run(_ edits: [(String, String)], themes: [Theme] = [], on base: ItemGroup? = nil) -> AssistantOutcome {
        AssistantInterpreter.apply(edits.map { AssistantEditInput(kind: $0.0, value: $0.1) }, to: base ?? group(),
                                   themes: themes, apps: apps)
    }

    @Test func lookEdits() {
        let out = run([("color", "dark blue"), ("layout", "list"), ("labels", "on hover"), ("columns", "4"),
                       ("iconSize", "large"), ("corners", "square"), ("border", "none"), ("shadow", "off")])
        let s = out.group.style
        #expect(!out.group.usesDefaultStyle) // look edits give the group its own look
        if case .solid(let c) = s.background { #expect(c.b > c.r && c.b < 0.6) } else { Issue.record("expected solid fill") }
        #expect(s.layout == .list && s.labels.mode == .onHover && s.columns == 4 && s.iconSize == 72)
        #expect(s.cornerRadius == 6 && s.border == nil && !s.shadow)
        #expect(out.skipped.isEmpty)
        #expect(out.changes.count >= 8)
    }

    @Test func gradientNameEmojiIcon() {
        let out = run([("gradient", "orange and #CC3366"), ("rename", "Studio"), ("emoji", "🎛️"), ("dockIcon", "symbol:star.fill"),
                       ("sort", "most used")])
        if case .gradient(let colors, _) = out.group.style.background { #expect(colors.count == 2) } else { Issue.record("expected gradient") }
        #expect(out.group.name == "Studio")
        #expect(out.group.emoji == "🎛️")
        #expect(out.group.icon.content == .symbol(name: "star.fill"))
        #expect(out.group.sortOrder == .mostOpened)
    }

    @Test func itemsAddAndRemoveNeedsConfirmation() {
        let out = run([("addApp", "numbers"), ("addApp", "Pages"), ("addApp", "Photoshop"), ("removeItem", "example.com")])
        #expect(out.group.items.count == 3) // Numbers added, Pages already there, removal not applied yet
        #expect(out.removals.map(\.displayName) == ["example.com"])
        #expect(out.skipped.count == 1) // Photoshop not installed
    }

    @Test func badValuesAreSkipped() {
        let base = group()
        let out = run([("color", "sparkly"), ("emoji", "x"), ("columns", "40"), ("teleport", "now"),
                       ("dockIcon", "symbol:not.a.real.symbol.name")], on: base)
        #expect(out.changes.isEmpty)
        #expect(out.skipped.count == 5)
        #expect(out.group == base)
    }

    @Test func themesByName() {
        let theme = Theme(id: "night-sky", name: "Night Sky", style: GroupStyle(cornerRadius: 30))
        let out = run([("theme", "night")], themes: [theme])
        #expect(out.group.themeID == "night-sky")
    }

    @Test func colorParsing() {
        #expect(AssistantInterpreter.color("#336699")?.hex == "#336699")
        #expect(AssistantInterpreter.color("336699")?.hex == "#336699")
        #expect(AssistantInterpreter.color("red") != nil)
        #expect(AssistantInterpreter.color("light green")!.g > AssistantInterpreter.color("green")!.g)
        #expect(AssistantInterpreter.color("plaid") == nil)
        #expect(AssistantInterpreter.splitList("red to blue") == ["red", "blue"])
    }

    @Test func contextStaysSmall() {
        var lib = Library()
        var g = ItemGroup(name: "Big")
        g.items = (0..<200).map { DockItem(kind: .file, url: URL(fileURLWithPath: "/tmp/file-\($0).txt")) }
        lib.groups = [g] + (0..<40).map { ItemGroup(name: "Other \($0)") }
        let text = AssistantContext.summary(of: g, in: lib, apps: apps, themeName: "Night Sky")
        // About four characters per token: stay far below the 8192 token context.
        #expect(text.count < 4000)
        #expect(text.contains("Items (200)"))
    }

    @Test func findAppsTool() {
        #expect(FindAppsTool.search("num", in: apps).map(\.name) == ["Numbers"])
        #expect(FindAppsTool.search("Productivity", in: apps).count == 2)
        #expect(FindAppsTool.search("", in: apps).isEmpty)
    }
}

// MARK: - Suggestions

@Suite struct AppSuggestionTests {
    let apps = [
        AppInfo(url: URL(fileURLWithPath: "/A/Xcode.app"), name: "Xcode", bundleID: "x", category: "Developer Tools"),
        AppInfo(url: URL(fileURLWithPath: "/A/Terminal.app"), name: "Terminal", bundleID: "t", category: "Developer Tools"),
        AppInfo(url: URL(fileURLWithPath: "/A/Tower.app"), name: "Tower", bundleID: "tw", category: "Developer Tools"),
        AppInfo(url: URL(fileURLWithPath: "/A/Music.app"), name: "Music", bundleID: "m", category: "Music"),
        AppInfo(url: URL(fileURLWithPath: "/A/Notes.app"), name: "Notes", bundleID: "n", category: "Productivity"),
    ]

    @Test func categoriesOfGroupAndName() {
        var g = ItemGroup(name: "Coding")
        var x = DockItem(kind: .app, url: URL(fileURLWithPath: "/A/Xcode.app")); x.bundleID = "x"
        g.items = [x]
        let picks = SuggestionRanker.rank(group: g, apps: apps, usage: UsageStats())
        #expect(Set(picks.map(\.name)) == ["Terminal", "Tower"])
        #expect(!picks.contains { $0.name == "Xcode" })
    }

    @Test func usedTogetherCounts() {
        var g = ItemGroup(name: "Stuff")
        var x = DockItem(kind: .app, url: URL(fileURLWithPath: "/A/Xcode.app")); x.bundleID = "x"
        g.items = [x]
        var usage = UsageStats()
        usage.coOccurrence = ["n": ["x": 9], "x": ["n": 9]]
        let picks = SuggestionRanker.rank(group: g, apps: apps, usage: usage)
        #expect(picks.first?.name == "Notes")
    }

    @Test func nameKeywords() {
        #expect(SuggestionRanker.wantedCategories(name: "Music Production", category: nil).contains("Music"))
        #expect(SuggestionRanker.wantedCategories(name: "Stuff", category: "Games").contains("Games"))
    }

    @Test func coUsageClusters() {
        var usage = UsageStats()
        for (a, b) in [("x", "t"), ("t", "tw"), ("x", "tw")] {
            usage.coOccurrence[a, default: [:]][b] = 5
            usage.coOccurrence[b, default: [:]][a] = 5
        }
        usage.coOccurrence["m", default: [:]]["n"] = 1
        let cats = Dictionary(uniqueKeysWithValues: apps.map { ($0.bundleID!, $0.category!) })
        let found = CoUsage.suggestions(usage: usage, groups: []) { cats[$0] }
        #expect(found.count == 1)
        #expect(Set(found[0].bundleIDs) == ["x", "t", "tw"])
        #expect(found[0].name == "Developer Tools")
        // A group that already has these apps hides the suggestion.
        var g = ItemGroup(name: "Dev")
        g.items = ["x", "t"].map { id in var i = DockItem(kind: .app, url: URL(fileURLWithPath: "/A/\(id).app")); i.bundleID = id; return i }
        #expect(CoUsage.suggestions(usage: usage, groups: [g]) { cats[$0] }.isEmpty)
    }
}

// MARK: - Misc

@Suite struct AppPhaseBMiscTests {
    @Test func smartGroupsLoseOwnDockIcons() {
        var lib = Library()
        var smart = ItemGroup(name: "Most"); smart.smart = .mostUsed
        let normal = ItemGroup(name: "N")
        lib.groups = [smart, normal]
        let stale = DockSlot(name: "Most", groupIDs: [smart.id])
        let mixed = DockSlot(name: "Mixed", groupIDs: [smart.id, normal.id])
        lib.slots = [stale, mixed]
        #expect(GroupOrdering.smartOnlySlots(lib) == [stale.id])
    }

    @Test func diagnosticsSummaryHasNoNames() {
        var lib = Library()
        var g = ItemGroup(name: "Secret Clients")
        g.items = [DockItem(kind: .file, url: URL(fileURLWithPath: "/Users/x/clients.pdf"))]
        lib.groups = [g]
        let text = Diagnostics.summary(lib, version: "1.1", system: "26.0")
        #expect(text.contains("Groups: 1"))
        #expect(!text.contains("Secret") && !text.contains("clients.pdf"))
    }

    @Test func season() {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        #expect(SeasonalSnow.isSeason(Date(timeIntervalSince1970: 1_765_000_000), calendar: c)) // 6 Dec 2025
        #expect(!SeasonalSnow.isSeason(Date(timeIntervalSince1970: 1_750_000_000), calendar: c)) // June 2025
    }

    @Test func emojiDetection() {
        #expect(Character("🎨").isEmoji)
        #expect(Character("⭐️").isEmoji)
        #expect(!Character("x").isEmoji)
        #expect(!Character("3").isEmoji)
    }
}
