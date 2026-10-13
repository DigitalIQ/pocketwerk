import Foundation
import Testing
@testable import PocketwerkKit

/// Talks to the real on-device model. Runs only with POCKETWERK_AI=1 and POCKETWERK_DATA_DIR set.
@Suite struct AppModelLiveTests {
    nonisolated static var enabled: Bool {
        let env = ProcessInfo.processInfo.environment
        return env["POCKETWERK_AI"] == "1" && env["POCKETWERK_DATA_DIR"] != nil
    }

    @Test(.enabled(if: AppModelLiveTests.enabled), .timeLimit(.minutes(3))) func assistantEditsAGroup() async throws {
        try #require(AIStatus.current.isAvailable)
        let store = LibraryStore.shared
        await AppCatalog.shared.reload()
        let g = store.addGroup(name: "Office", emoji: nil)
        store.insertURLs([URL(fileURLWithPath: "/System/Applications/Notes.app")], into: g.id)
        let chat = AssistantConversation.forGroup(g.id)
        await chat.send("Make it dark blue, use a list layout, and add Calendar and Reminders.")
        let turn = try #require(chat.turns.last)
        print("NAMED:", FindAppsTool.mentioned(in: "add Calendar and Reminders", apps: AppCatalog.shared.apps).map(\.name))
        print("REPLY:", turn.reply, "CHANGES:", turn.changes, "SKIPPED:", turn.skipped)
        #expect(!turn.failed)
        #expect(!turn.changes.isEmpty)
        let after = try #require(store.group(g.id))
        print("ITEMS:", after.items.map(\.displayName), "LAYOUT:", after.style.layout)
        if let id = chat.turns.last?.id { chat.undo(id) }
        #expect(store.group(g.id)?.items.count == 1)
    }

    @Test(.enabled(if: AppModelLiveTests.enabled), .timeLimit(.minutes(3))) func moreRequests() async throws {
        try #require(AIStatus.current.isAvailable)
        let store = LibraryStore.shared
        await AppCatalog.shared.reload()
        let g = store.addGroup(name: "Mixed", emoji: nil)
        store.insertURLs(["/System/Applications/Notes.app", "/System/Applications/Calculator.app"].map { URL(fileURLWithPath: $0) }, into: g.id)
        let chat = AssistantConversation.forGroup(g.id)
        for request in ["Add my music apps", "Remove Calculator", "Use a warm sunset gradient, labels only on hover, and a fitting emoji",
                        "Rename it to Studio", "What is the weather tomorrow?"] {
            await chat.send(request)
            let t = try #require(chat.turns.last)
            print("REQ:", request, "| REPLY:", t.reply, "| CHANGES:", t.changes, "| REMOVALS:", t.removals.map(\.displayName), "| SKIPPED:", t.skipped)
        }
        #expect(store.group(g.id)?.items.contains { $0.displayName == "Calculator" } == true) // removal waits for confirmation
    }

    @Test(.enabled(if: AppModelLiveTests.enabled), .timeLimit(.minutes(2))) func suggestionsFromModel() async throws {
        try #require(AIStatus.current.isAvailable)
        await AppCatalog.shared.reload()
        var g = ItemGroup(name: "Creative Studio")
        g.category = "Design"
        let engine = SuggestionEngine()
        await engine.generate(for: g, from: AppCatalog.shared.apps, usage: UsageStats())
        print("SOURCE:", engine.source, "APPS:", engine.apps.map(\.name))
        #expect(!engine.apps.isEmpty)
    }
}
