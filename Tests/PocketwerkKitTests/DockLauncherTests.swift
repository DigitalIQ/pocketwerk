import Foundation
import PocketwerkShared
import Testing
@testable import PocketwerkKit

@Suite struct DockLauncherTests {
    @Test func patchedInfoSetsIdentity() {
        let id = UUID()
        let spec = LauncherSpec(id: id, kind: .slot, name: "Work", mainAppPath: "/Applications/Pocketwerk.app", buildID: "f2-abc", dataDir: nil)
        var base = LauncherBuilder.defaultInfo
        base[PWShared.dataDirInfoKey] = "/stale"
        let info = LauncherBuilder.patchedInfo(base: base, spec: spec)
        #expect(info["CFBundleIdentifier"] as? String == PWShared.launcherBundleIDPrefix + id.uuidString)
        #expect(info["CFBundleName"] as? String == "Work")
        #expect(info["CFBundleDisplayName"] as? String == "Work")
        #expect(info["LSUIElement"] as? Bool == true)
        #expect(info[PWShared.slotInfoKey] as? String == id.uuidString)
        #expect(info[PWShared.kindInfoKey] as? String == "slot")
        #expect(info[PWShared.mainAppPathInfoKey] as? String == "/Applications/Pocketwerk.app")
        #expect(info[PWShared.buildIDInfoKey] as? String == "f2-abc")
        #expect(info[PWShared.dataDirInfoKey] == nil)
        #expect(info["CFBundleDocumentTypes"] != nil)
        #expect(PropertyListSerialization.propertyList(info, isValidFor: .xml))
    }

    @Test func spacerInfoHasNoDocumentTypes() {
        let spec = LauncherSpec(id: UUID(), kind: .spacer, name: "", buildID: "b", dataDir: "/tmp/data")
        let info = LauncherBuilder.patchedInfo(base: LauncherBuilder.defaultInfo, spec: spec)
        #expect((info["CFBundleIdentifier"] as? String)?.hasPrefix(PWShared.spacerBundleIDPrefix) == true)
        #expect(info["CFBundleName"] as? String == " ")
        #expect(info["CFBundleDocumentTypes"] == nil)
        #expect(info[PWShared.dataDirInfoKey] as? String == "/tmp/data")
    }

    @Test func bundleNames() {
        #expect(LauncherBuilder.bundleName(for: "Work/Play: Mix") == "Work-Play- Mix")
        #expect(LauncherBuilder.bundleName(for: "  ") == "Pocketwerk")
        #expect(LauncherBuilder.bundleName(for: "..hidden") == "hidden")
        #expect(LauncherBuilder.bundleName(for: String(repeating: "a", count: 80)).count == 60)
        #expect(LauncherBuilder.bundleName(for: "Two\nLines") == "Two Lines")
    }

    @Test func isCurrentComparesBuildAndName() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("lb-\(UUID().uuidString).app")
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("Contents"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let spec = LauncherSpec(id: UUID(), name: "Work", mainAppPath: "", buildID: "f2-1", dataDir: nil)
        let data = try PropertyListSerialization.data(fromPropertyList: LauncherBuilder.patchedInfo(base: [:], spec: spec), format: .xml, options: 0)
        try data.write(to: dir.appendingPathComponent("Contents/Info.plist"))
        #expect(LauncherBuilder.isCurrent(dir, spec: spec))
        var renamed = spec
        renamed.name = "Office"
        #expect(!LauncherBuilder.isCurrent(dir, spec: renamed))
        var rebuilt = spec
        rebuilt.buildID = "f2-2"
        #expect(!LauncherBuilder.isCurrent(dir, spec: rebuilt))
    }

    @Test func iconHashChangesWithInputs() {
        var lib = Library()
        var g = ItemGroup(name: "A")
        g.items = [DockItem(kind: .link, url: URL(string: "https://a.example")!)]
        lib.groups = [g]
        let slot = DockSlot(name: "A", groupIDs: [g.id])
        lib.slots = [slot]
        let h1 = LauncherIcon.hash(LauncherIcon.inputs(for: slot, library: lib))
        #expect(h1 == LauncherIcon.hash(LauncherIcon.inputs(for: slot, library: lib)))
        lib.groups[0].icon.content = .emoji("x")
        #expect(h1 != LauncherIcon.hash(LauncherIcon.inputs(for: slot, library: lib)))
    }

    @Test func dockManagerPinsThroughDomainWithOneRestart() {
        let store = LibraryStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("dm-\(UUID().uuidString).json"))
        let domain = FakeDockDomain()
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("dm-\(UUID().uuidString)")
        let manager = DockManager(store: store, domain: domain, folder: folder)
        let slot = store.addSlot(name: "Work", groupIDs: [])
        let path = folder.appendingPathComponent("Work.app").path
        store.updateSlot(slot.id) { $0.launcherPath = path }
        #expect(!manager.isInDock(slotID: slot.id))
        let bid = LauncherTarget.slot(slot.id).bundleID
        manager.modifyDock { DockPlist.adding(app: path, label: "Work", bundleID: bid, to: $0) }
        manager.modifyDock { DockPlist.adding(app: "/Applications/Mail.app", label: "Mail", bundleID: nil, to: $0) }
        #expect(manager.isInDock(slotID: slot.id))
        #expect(domain.restarts == 0)
        manager.flushDockChanges()
        manager.flushDockChanges()
        #expect(domain.restarts == 1)
        manager.removeFromDock(slotID: slot.id)
        #expect(!manager.isInDock(slotID: slot.id))
        #expect((domain.values[DockPlist.appsKey] as? [Any])?.count == 1)
    }
}
