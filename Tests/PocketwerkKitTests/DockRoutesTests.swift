import Foundation
import PocketwerkShared
import Testing
@testable import PocketwerkKit

@Suite struct DockRoutesTests {
    @Test func openURLRoundTrip() {
        let id = UUID()
        let url = PWShared.openURL(slotID: id.uuidString, at: CGPoint(x: 512.5, y: 40))
        #expect(PocketwerkRoute.parse(url) == .open(slot: id, group: nil, anchor: CGPoint(x: 512.5, y: 40)))
        #expect(PocketwerkRoute.parse(PWShared.openURL(slotID: id.uuidString)) == .open(slot: id, group: nil, anchor: nil))
    }

    @Test func openGroupAndAll() {
        #expect(PocketwerkRoute.parse(URL(string: "pocketwerk://open?group=Office%20Apps")!) == .open(slot: nil, group: "Office Apps", anchor: nil))
        #expect(PocketwerkRoute.parse(URL(string: "pocketwerk://open")!) == .open(slot: nil, group: nil, anchor: nil))
        #expect(PocketwerkRoute.parse(URL(string: "pocketwerk:open")!) == .open(slot: nil, group: nil, anchor: nil))
    }

    @Test func addKeepsEveryURLIntact() {
        let id = UUID()
        let files = [URL(fileURLWithPath: "/Users/me/A & B.pdf"), URL(string: "https://example.com/x?a=1&b=2+3#f")!]
        let url = PWShared.addURL(slotID: id.uuidString, urls: files)
        #expect(PocketwerkRoute.parse(url) == .add(urls: files, slot: id, group: nil))
        #expect(PocketwerkRoute.parse(URL(string: "pocketwerk://add?slot=\(id.uuidString)")!) == nil)
    }

    @Test func profileRoutes() {
        let id = UUID()
        #expect(PocketwerkRoute.parse(URL(string: "pocketwerk://profile?id=\(id.uuidString)")!) == .applyProfile(query: id.uuidString, skipIfActive: nil))
        #expect(PocketwerkRoute.parse(URL(string: "pocketwerk://profile?name=Work&skip=1")!) == .applyProfile(query: "Work", skipIfActive: true))
        #expect(PocketwerkRoute.parse(URL(string: "pocketwerk://profile?action=capture&name=Home")!) == .captureProfile(name: "Home"))
        #expect(PocketwerkRoute.parse(URL(string: "pocketwerk://profile?action=save")!) == .saveProfile)
        #expect(PocketwerkRoute.parse(URL(string: "pocketwerk://profile")!) == nil)
    }

    @Test func otherURLs() {
        #expect(PocketwerkRoute.parse(URL(string: "pocketwerk://settings")!) == .settings)
        #expect(PocketwerkRoute.parse(URL(string: "pocketwerk://nope")!) == nil)
        #expect(PocketwerkRoute.parse(URL(string: "https://open")!) == nil)
    }

    @Test func cliPrintsUsageAndRejectsUnknown() {
        var out = ""
        var err = ""
        #expect(PocketwerkCLI.execute(["help"], out: &out, err: &err) == 0)
        #expect(out.contains("profiles apply"))
        #expect(PocketwerkCLI.execute(["bogus"], out: &out, err: &err) == 64)
        #expect(err.contains("Unknown command"))
    }
}
