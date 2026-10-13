import Foundation
import Testing
@testable import PocketwerkKit

@Suite struct DockPhaseBTests {
    let store: LibraryStore
    let domain = FakeDockDomain()
    let system = FakeSystem()
    let profiles: DockProfiles

    init() {
        store = LibraryStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("pb-\(UUID().uuidString).json"))
        profiles = DockProfiles(store: store, domain: domain, system: system)
        domain.values = DockProfilesTests.sampleDock()
        system.existing = ["/Applications/Mail.app", "/Applications/Notes.app", "/Users/me/Downloads", "/Users/me/Code/app.xcodeproj",
                           "/Applications/Google Chrome.app"]
    }

    @Test func tileActionsRunOnApply() throws {
        let p = try #require(profiles.captureCurrent(name: "Work"))
        var tiles = p.tiles
        tiles[0].actions = [.openApp, .openProject(URL(fileURLWithPath: "/Users/me/Code/app.xcodeproj")),
                            .openProject(URL(fileURLWithPath: "/gone/x.xcworkspace"))]
        var chrome = DockTile(kind: .app, url: URL(fileURLWithPath: "/Applications/Google Chrome.app"), bundleID: "com.google.Chrome", label: "Chrome")
        chrome.actions = [.browserProfile(bundleID: "com.google.Chrome", profile: "Profile 1")]
        tiles.append(chrome)
        profiles.setTiles(tiles, of: p.id)
        let r = profiles.apply(p.id, skipIfActive: false)
        #expect(system.launches.map(\.path) == ["/Applications/Mail.app"])
        #expect(system.openedWith.first?.urls.first?.lastPathComponent == "app.xcodeproj")
        #expect(system.openedWith.first?.app.path == "/Applications/Mail.app")
        #expect(r.missing.contains("x.xcworkspace"))
        #expect(system.launchedWithArgs.first?.args == ["--profile-directory=Profile 1"])
    }

    @Test func appsOfStayOpenProfilesSurvive() throws {
        let work = try #require(profiles.captureCurrent(name: "Work"))
        let music = profiles.createEmpty(name: "Music")
        profiles.setTiles([DockTile(kind: .app, url: URL(fileURLWithPath: "/Applications/Spotify.app"), bundleID: "com.spotify.client")], of: music.id)
        profiles.updateProfile(music.id) { $0.appsStayOpen = true }
        profiles.updateProfile(work.id) { $0.quitOthers = true }
        system.running = [("com.spotify.client", nil), ("com.other.app", nil)]
        profiles.apply(work.id, skipIfActive: false)
        #expect(system.quits == ["com.other.app"])
    }

    @Test func nextProfileCyclesAndSkipsExcluded() throws {
        let a = try #require(profiles.captureCurrent(name: "A"))
        let b = try #require(profiles.captureCurrent(name: "B"))
        let c = try #require(profiles.captureCurrent(name: "C"))
        profiles.updateProfile(b.id) { $0.excludedFromCycle = true }
        profiles.apply(a.id, skipIfActive: false)
        #expect(profiles.applyNext().profileName == "C")
        #expect(store.settings.lastAppliedProfileID == c.id)
        #expect(profiles.applyNext().profileName == "A")
    }

    @Test func spaceLinkedProfilesApplyOnce() throws {
        let a = try #require(profiles.captureCurrent(name: "A"))
        let b = try #require(profiles.captureCurrent(name: "B"))
        profiles.updateProfile(a.id) { $0.spaces = ["display:D1"] }
        profiles.updateProfile(b.id) { $0.spaces = ["space:S2"] }
        #expect(profiles.applyForSpace(["space:S2", "display:D1"]) == nil) // feature off
        store.settings.profilePerSpace = true
        #expect(profiles.applyForSpace(["space:S2", "display:D1"])?.profileName == "B")
        #expect(profiles.applyForSpace(["space:S2", "display:D1"]) == nil) // already active: no restart
        #expect(profiles.applyForSpace(["space:S9", "display:D1"])?.profileName == "A")
        #expect(profiles.applyForSpace(["space:S9", "display:D7"]) == nil)
        #expect(domain.restarts == 2)
    }

    @Test func spaceRulesReadDisplayList() {
        let displays: [[String: Any]] = [
            ["Display Identifier": "Main",
             "Current Space": ["ManagedSpaceID": 1, "uuid": ""],
             "Spaces": [["ManagedSpaceID": 1, "uuid": "", "type": 0], ["ManagedSpaceID": 5, "uuid": "AAA", "type": 0]]],
            ["Display Identifier": "EXT-UUID",
             "Current Space": ["ManagedSpaceID": 9, "uuid": "BBB"],
             "Spaces": [["ManagedSpaceID": 8, "uuid": "CCC", "type": 0], ["ManagedSpaceID": 9, "uuid": "BBB", "type": 0]]],
        ]
        let ext = SpaceRules.places(displays: displays, activeSpace: 9, mainDisplayUUID: "MAIN-UUID")
        #expect(ext.map(\.id) == ["space:BBB", "display:EXT-UUID"])
        #expect(ext.first?.label == "Desktop 2")
        let main = SpaceRules.places(displays: displays, activeSpace: 1, mainDisplayUUID: "MAIN-UUID")
        #expect(main.map(\.id) == ["space:MAIN-UUID#0", "display:MAIN-UUID"])
        var p1 = DockProfile(name: "D", plistData: Data()); p1.spaces = ["display:EXT-UUID"]
        var p2 = DockProfile(name: "S", plistData: Data()); p2.spaces = ["space:BBB"]
        #expect(SpaceRules.profile(for: ext.map(\.id), in: [p1, p2]) == p2.id)
    }

    @Test func lastContextNoteAskedAndShown() throws {
        let a = try #require(profiles.captureCurrent(name: "A"))
        let b = try #require(profiles.captureCurrent(name: "B"))
        store.settings.askLastContext = true
        var shown: [String] = []
        profiles.askContextNote = { leaving in "left \(leaving.name)" }
        profiles.showContextNote = { shown.append($0.note) }
        profiles.apply(a.id, skipIfActive: false)
        profiles.apply(b.id, skipIfActive: false)
        #expect(profiles.profile(a.id)?.note == "left A")
        profiles.apply(a.id, skipIfActive: false)
        #expect(shown.last == "left A")
        // Automatic switches never ask.
        profiles.askContextNote = { _ in Issue.record("asked"); return nil }
        profiles.apply(b.id, skipIfActive: false, interactive: false)
    }

    @Test func exportAllSkipsPrivateAndStripsLocalData() throws {
        let a = try #require(profiles.captureCurrent(name: "A"))
        let b = try #require(profiles.captureCurrent(name: "B"))
        profiles.updateProfile(a.id) { $0.hotkey = Hotkey(keyCode: 1, modifiers: 256); $0.spaces = ["space:X"]; $0.note = "secret" }
        profiles.updateProfile(b.id) { $0.isPrivate = true }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("all-\(UUID().uuidString).json")
        try profiles.exportAll(to: url)
        let added = try profiles.importProfiles(from: url)
        #expect(added.count == 1)
        #expect(added[0].hotkey == nil && added[0].spaces.isEmpty && added[0].note.isEmpty)
        #expect(added[0].name == "A (Imported)")
        #expect(store.library.profiles.count == 3)
    }

    @Test func browserProfileParsing() {
        let state = #"{"profile":{"info_cache":{"Default":{"name":"Personal"},"Profile 1":{"name":"Work"}}}}"#
        let parsed = BrowserProfiles.parseChromiumLocalState(Data(state.utf8))
        #expect(parsed == [.init(id: "Default", name: "Personal"), .init(id: "Profile 1", name: "Work")])
        let ini = "[General]\nStartWithLastProfile=1\n\n[Profile0]\nName=default\nPath=abc.default\n\n[Install123]\nDefault=x\n[Profile1]\nName=Work\n"
        #expect(BrowserProfiles.parseFirefoxINI(ini).map(\.name) == ["default", "Work"])
        #expect(BrowserProfiles.arguments(bundleID: "org.mozilla.firefox", profile: "Work") == ["-P", "Work"])
        #expect(BrowserProfiles.browser("com.apple.Safari") == nil)
    }

    @Test func newRoutes() {
        #expect(PocketwerkRoute.parse(URL(string: "pocketwerk://profile?action=next")!) == .nextProfile)
        #expect(PocketwerkRoute.parse(URL(string: "pocketwerk://group?action=openAll&name=Office")!) == .groupAction(action: "openall", group: "Office"))
        #expect(PocketwerkRoute.parse(URL(string: "pocketwerk://group?action=delete&name=Office")!) == nil)
    }
}
