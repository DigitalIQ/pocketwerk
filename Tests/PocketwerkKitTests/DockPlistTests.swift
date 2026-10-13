import Foundation
import Testing
@testable import PocketwerkKit

@Suite struct DockPlistTests {
    @Test func appTileShape() {
        let e = DockPlist.appTile(path: "/Applications/Safari.app", label: "Safari", bundleID: "com.apple.Safari")
        #expect(DockPlist.tileType(e) == "file-tile")
        let data = DockPlist.tileData(e)
        #expect(data["file-type"] as? Int == 41)
        #expect(data["bundle-identifier"] as? String == "com.apple.Safari")
        let fd = data["file-data"] as? [String: Any]
        #expect(fd?["_CFURLString"] as? String == "file:///Applications/Safari.app/")
        #expect(fd?["_CFURLStringType"] as? Int == 15)
        #expect(DockPlist.path(of: e) == "/Applications/Safari.app")
    }

    @Test func pathParsingHandlesEncodingAndPlainPaths() {
        let encoded: [String: Any] = ["_CFURLString": "file:///Users/me/My%20Folder/", "_CFURLStringType": 15]
        #expect(DockPlist.path(fromURLData: encoded) == "/Users/me/My Folder")
        let plain: [String: Any] = ["_CFURLString": "/Users/me/My Folder/", "_CFURLStringType": 0]
        #expect(DockPlist.path(fromURLData: plain) == "/Users/me/My Folder")
        #expect(DockPlist.path(fromURLData: ["_CFURLString": "https://example.com", "_CFURLStringType": 15]) == nil)
        #expect(DockPlist.path(fromURLData: nil) == nil)
    }

    @Test func tilesRoundTrip() throws {
        let tiles: [DockTile] = [
            DockTile(kind: .app, url: URL(fileURLWithPath: "/Applications/Mail.app"), bundleID: "com.apple.mail", label: "Mail"),
            DockTile(kind: .spacer),
            DockTile(kind: .smallSpacer),
            DockTile(kind: .flexSpacer),
            {
                var t = DockTile(kind: .folder, url: URL(fileURLWithPath: "/Users/me/Downloads", isDirectory: true), label: "Downloads", isOther: true)
                t.folder = StackSettings(view: 2, displayAs: 1, sort: 2)
                return t
            }(),
            DockTile(kind: .file, url: URL(fileURLWithPath: "/Users/me/notes.txt"), label: "notes.txt", isOther: true),
            DockTile(kind: .url, url: URL(string: "https://example.com/a?b=c")!, label: "Example", isOther: true),
            DockTile(kind: .customSpacer, url: URL(fileURLWithPath: "/x/Spacer Work.app"),
                     bundleID: "io.github.digitaliq.pocketwerk.spacer.ABC", label: "Work"),
        ]
        for tile in tiles {
            let entry = try #require(DockPlist.entry(for: tile))
            let back = try #require(DockPlist.tile(from: entry, isOther: tile.isOther))
            #expect(back.kind == tile.kind)
            #expect(back.isOther == tile.isOther)
            if !tile.kind.isSpacer {
                #expect(back.url?.standardizedFileURL.path == tile.url?.standardizedFileURL.path || back.url == tile.url)
                #expect(back.label == tile.label)
            }
            if tile.kind == .folder { #expect(back.folder == tile.folder) }
            if tile.kind == .app { #expect(back.bundleID == "com.apple.mail") }
        }
    }

    @Test func unknownTileTypesAreNotEditorTiles() {
        let e: [String: Any] = ["tile-type": "recents-tile", "tile-data": [String: Any]()]
        #expect(DockPlist.tile(from: e, isOther: true) == nil)
    }

    @Test func addingRemovingAndMoving() {
        let path = "/Users/me/Applications/Pocketwerk/Work.app"
        let bid = "io.github.digitaliq.pocketwerk.slot.1"
        var entries = [DockPlist.appTile(path: "/Applications/Mail.app", label: "Mail", bundleID: "com.apple.mail")]
        entries = DockPlist.adding(app: path, label: "Work", bundleID: bid, to: entries)
        #expect(entries.count == 2)
        // Adding again does not duplicate.
        entries = DockPlist.adding(app: path, label: "Work", bundleID: bid, to: entries)
        #expect(entries.count == 2)
        #expect(DockPlist.contains(entries, path: path, bundleID: nil))
        // A renamed launcher keeps its position and gets the new path and label.
        var moved = entries
        moved[1]["tile-data"] = (moved[1]["tile-data"] as! [String: Any]).merging(["book": Data([1, 2])]) { $1 }
        moved = DockPlist.adding(app: "/Users/me/Applications/Pocketwerk/Office.app", label: "Office", bundleID: bid, to: moved)
        #expect(moved.count == 2)
        #expect(DockPlist.path(of: moved[1]) == "/Users/me/Applications/Pocketwerk/Office.app")
        #expect(DockPlist.label(of: moved[1]) == "Office")
        #expect(DockPlist.tileData(moved[1])["book"] == nil)
        // Remove by bundle id only.
        let removed = DockPlist.removing(path: nil, bundleID: bid, from: moved)
        #expect(removed.count == 1)
        #expect(DockPlist.bundleID(of: removed[0]) == "com.apple.mail")
    }

    @Test func identityMatchesSameTarget() {
        let a = DockPlist.appTile(path: "/Applications/Mail.app", label: "Mail", bundleID: nil)
        let b = DockPlist.appTile(path: "/Applications/Mail.app/", label: "Other Label", bundleID: "x")
        #expect(DockPlist.identity(of: a) == DockPlist.identity(of: b))
        let c = DockPlist.urlTile(url: URL(string: "https://a.example")!, label: "A")
        #expect(DockPlist.identity(of: c) == "url|https://a.example")
    }
}
