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

    @Test func trustedCallers() {
        #expect(URLCaller.pocketwerk.isTrusted())
        #expect(URLCaller(bundleID: PWShared.launcherBundleIDPrefix + UUID().uuidString).isTrusted())
        #expect(URLCaller(bundleID: PWShared.spacerBundleIDPrefix + UUID().uuidString).isTrusted())
        #expect(URLCaller(bundleID: "com.apple.shortcuts").isTrusted())
        #expect(URLCaller(bundleID: "com.apple.WorkflowKit.BackgroundShortcutRunner").isTrusted())
        #expect(URLCaller(executablePath: "/Applications/Pocketwerk.app/Contents/MacOS/Pocketwerk")
            .isTrusted(ownExecutable: "/Applications/Pocketwerk.app/Contents/MacOS/Pocketwerk"))
        #expect(!URLCaller(bundleID: "com.google.Chrome").isTrusted())
        #expect(!URLCaller(bundleID: "com.apple.mail").isTrusted())
        // Lookalike: shares the prefix text but not the dot.
        #expect(!URLCaller(bundleID: "io.github.digitaliq.pocketwerkevil").isTrusted())
        #expect(!URLCaller.unknown.isTrusted())
    }

    @Test func changingRoutes() {
        #expect(!PocketwerkRoute.open(slot: nil, group: nil, anchor: nil).changesSomething)
        #expect(!PocketwerkRoute.settings.changesSomething)
        #expect(!PocketwerkRoute.groupAction(action: "hideall", group: "A").changesSomething)
        #expect(PocketwerkRoute.groupAction(action: "quitall", group: "A").changesSomething)
        #expect(PocketwerkRoute.groupAction(action: "openall", group: "A").changesSomething)
        #expect(PocketwerkRoute.add(urls: [URL(string: "https://example.com")!], slot: nil, group: nil).changesSomething)
        #expect(PocketwerkRoute.applyProfile(query: "Work", skipIfActive: nil).changesSomething)
        #expect(PocketwerkRoute.captureProfile(name: "X").changesSomething)
        #expect(PocketwerkRoute.saveProfile.changesSomething)
        #expect(PocketwerkRoute.nextProfile.changesSomething)
    }

    @Test func foreignAddNeedsConfirmation() {
        let store = LibraryStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("pw-routes-\(UUID().uuidString).json"))
        let g = store.addGroup(name: "Links", withSlot: false)
        let url = URL(string: "pocketwerk://add?group=\(g.id.uuidString)&url=https://phish.example/login")!
        let browser = URLCaller(bundleID: "com.google.Chrome", name: "Google Chrome")
        var asked = 0

        #expect(DockRoutes.handle(url, store: store, caller: browser) { _, _ in asked += 1; return false })
        #expect(asked == 1)
        #expect(store.group(g.id)!.items.isEmpty)

        #expect(DockRoutes.handle(url, store: store, caller: browser) { _, _ in asked += 1; return true })
        #expect(asked == 2)
        #expect(store.group(g.id)!.items.map(\.url.absoluteString) == ["https://phish.example/login"])

        // Pocketwerk's own launchers add dropped files without asking.
        let launcher = URLCaller(bundleID: PWShared.launcherBundleIDPrefix + UUID().uuidString)
        let file = URL(string: "pocketwerk://add?group=\(g.id.uuidString)&url=file:///tmp/a.txt")!
        #expect(DockRoutes.handle(file, store: store, caller: launcher) { _, _ in asked += 1; return false })
        #expect(asked == 2)
        #expect(store.group(g.id)!.items.count == 2)
    }

    @Test func confirmationTexts() {
        #expect(!URLConfirmation.question(for: .groupAction(action: "quitall", group: "Work")).isEmpty)
        #expect(URLConfirmation.question(for: .applyProfile(query: "Home", skipIfActive: nil)).contains("Home"))
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
