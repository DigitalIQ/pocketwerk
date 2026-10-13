import AppKit
import SwiftUI
import Testing
@testable import PocketwerkKit

/// Renders app module views to PNG for a visual check. Runs only with
/// POCKETWERK_SHOTS=<folder> and POCKETWERK_DATA_DIR=<scratch folder>, so it never touches real data.
@Suite struct AppSnapshotTests {
    nonisolated static var enabled: Bool {
        let env = ProcessInfo.processInfo.environment
        return env["POCKETWERK_SHOTS"] != nil && env["POCKETWERK_DATA_DIR"] != nil
    }

    func render<V: View>(_ view: V, size: CGSize, name: String) throws {
        _ = NSApplication.shared
        let folder = URL(fileURLWithPath: ProcessInfo.processInfo.environment["POCKETWERK_SHOTS"]!)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled, .resizable],
                              backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .aqua)
        let host = NSHostingView(rootView: view.frame(width: size.width, height: size.height))
        window.contentView = host
        window.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.6))
        let rep = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: rep)
        try #require(rep.representation(using: .png, properties: [:])).write(to: folder.appendingPathComponent("\(name).png"))
    }

    @Test(.enabled(if: AppSnapshotTests.enabled)) func shots() async throws {
        await AppCatalog.shared.reload()
        let store = LibraryStore.shared
        if store.library.groups.count < 3 {
            let work = store.addGroup(name: "Work", emoji: "💼")
            store.insertURLs(["/System/Applications/Mail.app", "/System/Applications/Calendar.app",
                              "/System/Applications/Notes.app", "/Users"].map { URL(fileURLWithPath: $0) }, into: work.id)
            store.addLink(URL(string: "https://github.com")!, name: "GitHub", to: work.id)
            store.updateGroup(work.id) { $0.pinned = true }
            _ = store.addGroup(name: "Creative", emoji: "🎨")
            _ = store.addGroup(name: "Most Used", emoji: nil, smart: .mostUsed)
        }
        let model = MainWindowModel()
        model.selection = .group(store.library.orderedGroups[0].id)
        try render(MainWindowView(model: model), size: CGSize(width: 980, height: 640), name: "main-items")
        model.groupTab = .options
        try render(MainWindowView(model: model), size: CGSize(width: 980, height: 640), name: "main-options")
        for page in SettingsPage.allCases {
            model.selection = .settings(page)
            try render(MainWindowView(model: model), size: CGSize(width: 980, height: 640), name: "settings-\(page.rawValue)")
        }
        try render(AppDrawerView(groupID: store.library.orderedGroups[0].id), size: CGSize(width: 760, height: 520), name: "drawer")
        try render(AddLinkSheet(groupID: store.library.orderedGroups[0].id), size: CGSize(width: 440, height: 260), name: "link")
        try render(AssistantView(groupID: store.library.orderedGroups[0].id), size: CGSize(width: 760, height: 520), name: "assistant")
        try render(HelpView(initial: "keys"), size: CGSize(width: 760, height: 520), name: "help")
        model.selection = .group(store.library.orderedGroups[0].id)
        model.groupTab = .options
        try render(MainWindowView(model: model), size: CGSize(width: 1260, height: 800), name: "main-options-b")
        let starters = StarterGroups.build { AppLocator.url(forBundleID: $0) }
        try render(WelcomeView(starters: starters) {}, size: CGSize(width: 520, height: 520), name: "welcome")
        try render(ImportReviewView(summary: ImportSummary(newGroups: ["Games"], existingGroups: ["Work"], newProfiles: [],
                                                           existingProfiles: [], newThemes: 1, missingApps: ["Games: Nope"],
                                                           totalGroups: 2, totalItems: 5),
                                    apply: { _ in }, cancel: {}), size: CGSize(width: 460, height: 420), name: "import")
    }
}
