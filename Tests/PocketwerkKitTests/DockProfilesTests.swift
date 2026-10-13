import Foundation
import Testing
@testable import PocketwerkKit

/// In-memory stand-in for com.apple.dock.
final class FakeDockDomain: DockDomain {
    var values: [String: Any] = [:]
    var commits = 0
    var restarts = 0

    func value(forKey key: String) -> Any? { values[key] }
    func set(_ value: Any?, forKey key: String) { values[key] = value }
    func commit(restartDock: Bool) {
        commits += 1
        if restartDock { restarts += 1 }
    }
}

final class FakeSystem: ProfileSystem {
    var running: [(bundleID: String, path: String?)] = []
    var existing: Set<String> = []
    var moved: [String: String] = [:]
    var quits: [String] = []
    var launches: [URL] = []
    var opened: [URL] = []

    func runningApps() -> [(bundleID: String, path: String?)] { running }
    func quit(bundleID: String) { quits.append(bundleID) }
    func launch(appAt url: URL) { launches.append(url) }
    func open(_ url: URL) { opened.append(url) }
    func fileExists(_ path: String) -> Bool { existing.contains(path) }
    func locate(bundleID: String) -> String? { moved[bundleID] }
}

@Suite struct DockProfilesTests {
    let store: LibraryStore
    let domain = FakeDockDomain()
    let system = FakeSystem()
    let profiles: DockProfiles

    init() {
        store = LibraryStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("dp-\(UUID().uuidString).json"))
        profiles = DockProfiles(store: store, domain: domain, system: system)
        domain.values = Self.sampleDock()
        system.existing = ["/Applications/Mail.app", "/Applications/Notes.app", "/Users/me/Downloads"]
    }

    static func sampleDock() -> [String: Any] {
        var mail = DockPlist.appTile(path: "/Applications/Mail.app", label: "Mail", bundleID: "com.apple.mail")
        mail["tile-data"] = DockPlist.tileData(mail).merging(["book": Data([9, 9, 9])]) { $1 }
        return [
            DockPlist.appsKey: [
                mail,
                DockPlist.spacerTile(.spacer),
                DockPlist.appTile(path: "/Applications/Notes.app", label: "Notes", bundleID: "com.apple.Notes"),
            ],
            DockPlist.othersKey: [
                DockPlist.folderTile(path: "/Users/me/Downloads", label: "Downloads", stack: StackSettings(view: 2, displayAs: 0, sort: 2)),
                DockPlist.urlTile(url: URL(string: "https://example.com")!, label: "Example"),
            ],
            "tilesize": 48,
            "orientation": "left",
            "autohide": true,
        ]
    }

    @Test func captureReadsTilesAndSettings() throws {
        let p = try #require(profiles.captureCurrent(name: "Work"))
        #expect(store.library.profiles.count == 1)
        #expect(p.tiles.map(\.kind) == [.app, .spacer, .app, .folder, .url])
        #expect(p.tiles.filter(\.isOther).count == 2)
        #expect(p.tiles[3].folder == StackSettings(view: 2, displayAs: 0, sort: 2))
        let values = DockSnapshot.decode(p.plistData)
        #expect(values["tilesize"] as? Int == 48)
        #expect(values["orientation"] as? String == "left")
        #expect(values["autohide"] as? Bool == true)
    }

    @Test func captureRefusesEmptyDock() {
        domain.values = [:]
        #expect(profiles.captureCurrent(name: "Empty") == nil)
        #expect(throws: DockProfiles.ProfileError.self) { try profiles.makeProfileFromCurrentDock(name: "x") }
    }

    @Test func applyWritesOnceAndRestartsOnce() throws {
        let p = try #require(profiles.captureCurrent(name: "Work"))
        domain.values = [DockPlist.appsKey: [DockPlist.appTile(path: "/Applications/Notes.app", label: "Notes", bundleID: nil)], "tilesize": 64]
        let r = profiles.apply(p.id, skipIfActive: false)
        #expect(r.status == .applied)
        #expect(domain.restarts == 1)
        #expect(DockSnapshot.signature(domain.values) == DockSnapshot.signature(Self.sampleDock()))
        #expect(domain.values["tilesize"] as? Int == 48)
        #expect(store.settings.lastAppliedProfileID == p.id)
        // Bookmark data of unchanged entries is kept.
        let mail = (domain.values[DockPlist.appsKey] as? [[String: Any]])?.first
        #expect(DockPlist.tileData(mail ?? [:])["book"] as? Data == Data([9, 9, 9]))
    }

    @Test func skipIfActive() throws {
        let p = try #require(profiles.captureCurrent(name: "Work"))
        profiles.apply(p.id, skipIfActive: false)
        let r = profiles.apply(p.id, skipIfActive: true)
        #expect(r.status == .skippedActive)
        #expect(domain.restarts == 1)
        // A changed Dock is not "active" any more.
        domain.values[DockPlist.othersKey] = []
        #expect(profiles.apply(p.id, skipIfActive: true).status == .applied)
        #expect(domain.restarts == 2)
    }

    @Test func missingFilesAreSkippedAndMovedAppsFound() throws {
        let p = try #require(profiles.captureCurrent(name: "Work"))
        system.existing = ["/Applications/Mail.app", "/Applications/Utilities/Notes.app"]
        system.moved = ["com.apple.Notes": "/Applications/Utilities/Notes.app"]
        let r = profiles.apply(p.id, skipIfActive: false)
        #expect(r.missing == ["Downloads"])
        let apps = domain.values[DockPlist.appsKey] as? [[String: Any]] ?? []
        #expect(apps.compactMap(DockPlist.path(of:)) == ["/Applications/Mail.app", "/Applications/Utilities/Notes.app"])
        let others = domain.values[DockPlist.othersKey] as? [[String: Any]] ?? []
        #expect(others.count == 1) // the link stays
    }

    @Test func quitOthersKeepsProfileAppsAndKeepList() throws {
        let p = try #require(profiles.captureCurrent(name: "Work"))
        profiles.updateProfile(p.id) { $0.quitOthers = true; $0.keepRunning = ["com.spotify.client"] }
        system.running = [("com.apple.mail", "/Applications/Mail.app"), ("com.spotify.client", nil), ("com.tinyspeck.slackmacgap", nil),
                          ("io.github.digitaliq.pocketwerk.slot.X", nil), ("com.apple.finder", nil)]
        let r = profiles.apply(p.id, skipIfActive: false)
        #expect(r.quit == ["com.tinyspeck.slackmacgap"])
        #expect(system.quits == ["com.tinyspeck.slackmacgap"])

        profiles.updateProfile(p.id) { $0.keepAppsOpen = true }
        system.quits = []
        profiles.apply(p.id, skipIfActive: false)
        #expect(system.quits.isEmpty)
    }

    @Test func launchAppsStartsOnlyWhatIsNotRunning() throws {
        let p = try #require(profiles.captureCurrent(name: "Work"))
        profiles.updateProfile(p.id) {
            $0.launchApps = true
            $0.openAfterApply = [URL(string: "https://example.org")!, URL(fileURLWithPath: "/nope/gone.txt")]
        }
        system.running = [("com.apple.mail", "/Applications/Mail.app")]
        let r = profiles.apply(p.id, skipIfActive: false)
        #expect(system.launches.map(\.path) == ["/Applications/Notes.app"])
        #expect(system.opened == [URL(string: "https://example.org")!])
        #expect(r.missing.contains("gone.txt"))
    }

    @Test func editedTilesAreApplied() throws {
        let p = try #require(profiles.captureCurrent(name: "Work"))
        var tiles = p.tiles
        tiles.swapAt(0, 2) // Notes before Mail
        tiles.remove(at: 1) // drop the spacer
        tiles.append(DockTile(kind: .smallSpacer))
        profiles.setTiles(tiles, of: p.id)
        domain.values = [:]
        profiles.apply(p.id, skipIfActive: false)
        let apps = domain.values[DockPlist.appsKey] as? [[String: Any]] ?? []
        #expect(apps.map(DockPlist.tileType) == ["file-tile", "file-tile", "small-spacer-tile"])
        #expect(DockPlist.path(of: apps[0]) == "/Applications/Notes.app")
        #expect(DockPlist.tileData(apps[1])["book"] as? Data == Data([9, 9, 9]))
    }

    @Test func emptyProfileBuiltFromTiles() throws {
        let p = profiles.createEmpty(name: "Blank")
        profiles.setTiles([DockTile(kind: .app, url: URL(fileURLWithPath: "/Applications/Mail.app"), label: "Mail")], of: p.id)
        profiles.apply(p.id, skipIfActive: false)
        let apps = domain.values[DockPlist.appsKey] as? [[String: Any]] ?? []
        #expect(apps.count == 1)
        #expect((domain.values[DockPlist.othersKey] as? [Any])?.isEmpty == true)
        #expect(domain.values["tilesize"] as? Int == 48) // settings untouched
    }

    @Test func saveCurrentIntoActiveAndAutoSave() throws {
        let a = try #require(profiles.captureCurrent(name: "A"))
        let b = profiles.createEmpty(name: "B")
        profiles.setTiles([DockTile(kind: .app, url: URL(fileURLWithPath: "/Applications/Notes.app"), label: "Notes")], of: b.id)
        profiles.apply(a.id, skipIfActive: false)
        domain.values[DockPlist.othersKey] = []
        #expect(profiles.saveCurrentToActive())
        #expect(profiles.profile(a.id)?.tiles.filter(\.isOther).isEmpty == true)
        // Options survive a save.
        profiles.updateProfile(a.id) { $0.quitOthers = true }
        #expect(profiles.saveCurrent(into: a.id))
        #expect(profiles.profile(a.id)?.quitOthers == true)
    }

    @Test func overlappingApplyIsRefusedAndUnknownIsReported() {
        #expect(profiles.apply(UUID()).status == .notFound)
    }

    @Test func lookupByNameIdAndPrefix() throws {
        let work = try #require(profiles.captureCurrent(name: "Work Dock"))
        _ = profiles.captureCurrent(name: "Weekend")
        #expect(profiles.profile(matching: work.id.uuidString)?.id == work.id)
        #expect(profiles.profile(matching: "work dock")?.id == work.id)
        #expect(profiles.profile(matching: "Wor")?.id == work.id)
        #expect(profiles.profile(matching: "W") == nil) // ambiguous
    }

    @Test func exportImportAddsCopy() throws {
        let p = try #require(profiles.captureCurrent(name: "Work"))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("profile-\(UUID().uuidString).json")
        try profiles.export(p.id, to: url)
        let imported = try profiles.importProfile(from: url)
        #expect(imported.id != p.id)
        #expect(imported.name != p.name)
        #expect(imported.tiles.count == p.tiles.count)
        #expect(store.library.profiles.count == 2)
    }

    @Test func duplicateAndDelete() throws {
        let p = try #require(profiles.captureCurrent(name: "Work"))
        store.settings.startupProfileID = p.id
        let copy = try #require(profiles.duplicate(p.id))
        #expect(store.library.profiles.map(\.id) == [p.id, copy.id])
        profiles.delete(p.id)
        #expect(store.library.profiles.map(\.id) == [copy.id])
        #expect(store.settings.startupProfileID == nil)
    }

    @Test func repairFillsMissingHalf() throws {
        let p = try #require(profiles.captureCurrent(name: "Work"))
        profiles.updateProfile(p.id) { $0.tiles = [] }
        profiles.repairProfiles()
        #expect(profiles.profile(p.id)?.tiles.count == 5)
    }
}
