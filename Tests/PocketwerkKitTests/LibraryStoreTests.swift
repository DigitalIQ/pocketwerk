import Foundation
import Testing
@testable import PocketwerkKit

@Suite struct LibraryStoreTests {
    func tempStore() -> LibraryStore {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("dw-\(UUID().uuidString).json")
        return LibraryStore(fileURL: url)
    }

    @Test func addGroupCreatesSlot() {
        let store = tempStore()
        let before = store.library.slots.count
        let g = store.addGroup(name: "Arbeit")
        #expect(store.group(g.id)?.name == "Arbeit")
        #expect(store.library.slots.count == before + 1)
        #expect(store.library.slots.last?.groupIDs == [g.id])
    }

    @Test func undoRedo() {
        let store = tempStore()
        let g = store.addGroup(name: "A")
        store.updateGroup(g.id) { $0.name = "B" }
        store.undo()
        #expect(store.group(g.id)?.name == "A")
        store.redo()
        #expect(store.group(g.id)?.name == "B")
    }

    @Test func lenientDecodingFillsMissingKeys() throws {
        var lib = Library()
        var g = ItemGroup(name: "X")
        g.style.background = .fx(FXParams(kind: .snow, palette: [.white]))
        lib.groups = [g]
        var json = try JSONSerialization.jsonObject(with: LibraryStore.encoder.encode(lib)) as! [String: Any]
        // Simulate an older file: drop keys.
        json.removeValue(forKey: "profiles")
        var groups = json["groups"] as! [[String: Any]]
        groups[0].removeValue(forKey: "sortOrder")
        var style = groups[0]["style"] as! [String: Any]
        style.removeValue(forKey: "spacing")
        groups[0]["style"] = style
        json["groups"] = groups
        let data = try JSONSerialization.data(withJSONObject: json)
        let decoded = try #require(LibraryStore.decodeLeniently(data))
        #expect(decoded.groups[0].name == "X")
        #expect(decoded.groups[0].sortOrder == .manual)
        #expect(decoded.groups[0].style.background == .fx(FXParams(kind: .snow, palette: [.white])))
    }

    @Test func itemKindDetection() {
        #expect(DockItem(url: URL(fileURLWithPath: "/System/Applications/Mail.app")).kind == .app)
        #expect(DockItem(url: URL(fileURLWithPath: "/System")).kind == .folder)
        #expect(DockItem(url: URL(string: "https://example.com")!).kind == .link)
    }
}
