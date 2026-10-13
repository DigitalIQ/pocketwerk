import AppIntents
import Foundation
import PocketwerkKit

// Shortcuts, Siri, Spotlight and Focus filter actions. They live in the executable target because
// the App Intents metadata step works per module and needs the final binary (see
// scripts/build-app.sh --intents). Keep the phrases in step with AutomationPhrases in PocketwerkKit.

// MARK: - Entities

nonisolated struct GroupEntity: AppEntity {
    let id: UUID
    let name: String

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Group"
    static let defaultQuery = GroupQuery()

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

nonisolated struct GroupQuery: EntityStringQuery {
    func entities(for identifiers: [UUID]) async throws -> [GroupEntity] {
        await all().filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> [GroupEntity] {
        await all().filter { $0.name.localizedCaseInsensitiveContains(string) }
    }

    func suggestedEntities() async throws -> [GroupEntity] { await all() }

    private func all() async -> [GroupEntity] {
        await MainActor.run { PocketwerkAutomation.groups().map { GroupEntity(id: $0.id, name: $0.name) } }
    }
}

nonisolated struct ProfileEntity: AppEntity {
    let id: UUID
    let name: String

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Dock Profile"
    static let defaultQuery = ProfileQuery()

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

nonisolated struct ProfileQuery: EntityStringQuery {
    func entities(for identifiers: [UUID]) async throws -> [ProfileEntity] {
        await all().filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> [ProfileEntity] {
        await all().filter { $0.name.localizedCaseInsensitiveContains(string) }
    }

    func suggestedEntities() async throws -> [ProfileEntity] { await all() }

    private func all() async -> [ProfileEntity] {
        await MainActor.run { PocketwerkAutomation.profiles().map { ProfileEntity(id: $0.id, name: $0.name) } }
    }
}

// MARK: - Group actions

struct ShowGroupIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Group"
    static let description = IntentDescription("Shows a group's popup at the pointer.")

    @Parameter(title: "Group") var group: GroupEntity

    func perform() async throws -> some IntentResult {
        let id = group.id
        _ = await MainActor.run { PocketwerkAutomation.showGroup(id) }
        return .result()
    }
}

struct OpenAllIntent: AppIntent {
    static let title: LocalizedStringResource = "Open All Items of Group"
    static let description = IntentDescription("Opens every app, file, folder and link of a group.")

    @Parameter(title: "Group") var group: GroupEntity

    func perform() async throws -> some IntentResult {
        let id = group.id
        _ = await MainActor.run { PocketwerkAutomation.openAll(id) }
        return .result()
    }
}

struct HideGroupIntent: AppIntent {
    static let title: LocalizedStringResource = "Hide Apps of Group"
    static let description = IntentDescription("Hides every running app of a group.")

    @Parameter(title: "Group") var group: GroupEntity

    func perform() async throws -> some IntentResult {
        let id = group.id
        _ = await MainActor.run { PocketwerkAutomation.hideAll(id) }
        return .result()
    }
}

struct QuitGroupIntent: AppIntent {
    static let title: LocalizedStringResource = "Quit Apps of Group"
    static let description = IntentDescription("Quits every running app of a group. Apps can still ask to save.")

    @Parameter(title: "Group") var group: GroupEntity

    func perform() async throws -> some IntentResult {
        let id = group.id
        _ = await MainActor.run { PocketwerkAutomation.quitAll(id) }
        return .result()
    }
}

// MARK: - Profile actions

struct ApplyProfileIntent: AppIntent {
    static let title: LocalizedStringResource = "Apply Dock Profile"
    static let description = IntentDescription("Rewrites the Dock with a saved profile.")

    @Parameter(title: "Profile") var profile: ProfileEntity

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let id = profile.id
        let text = await MainActor.run { PocketwerkAutomation.applyProfile(id, interactive: false) }
        return .result(dialog: "\(text)")
    }
}

nonisolated struct NextProfileIntent: AppIntent {
    static let title: LocalizedStringResource = "Apply Next Dock Profile"
    static let description = IntentDescription("Applies the next profile in the list.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let text = await MainActor.run { PocketwerkAutomation.applyNextProfile() }
        return .result(dialog: "\(text)")
    }
}

/// Focus filter: turning a Focus on applies the chosen Dock profile.
struct DockProfileFocusFilter: SetFocusFilterIntent {
    static let title: LocalizedStringResource = "Set Dock Profile"
    static let description: IntentDescription? = IntentDescription("Applies a Pocketwerk Dock profile when this Focus turns on.")

    @Parameter(title: "Dock Profile") var profile: ProfileEntity?

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(profile?.name ?? String(localized: "No profile"))")
    }

    func perform() async throws -> some IntentResult {
        if let id = profile?.id {
            _ = await MainActor.run { PocketwerkAutomation.applyProfile(id, interactive: false) }
        }
        return .result()
    }
}

// MARK: - Phrases

nonisolated struct PocketwerkShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: ShowGroupIntent(), phrases: ["Show \(\.$group) in \(.applicationName)"],
                    shortTitle: "Show Group", systemImageName: "square.grid.2x2")
        AppShortcut(intent: OpenAllIntent(), phrases: ["Open all of \(\.$group) in \(.applicationName)"],
                    shortTitle: "Open All", systemImageName: "arrow.up.forward.app")
        AppShortcut(intent: QuitGroupIntent(), phrases: ["Quit \(\.$group) in \(.applicationName)"],
                    shortTitle: "Quit Group", systemImageName: "xmark.app")
        AppShortcut(intent: ApplyProfileIntent(), phrases: ["Switch \(.applicationName) to \(\.$profile)"],
                    shortTitle: "Apply Dock Profile", systemImageName: "dock.rectangle")
        AppShortcut(intent: NextProfileIntent(), phrases: ["Next Dock profile in \(.applicationName)"],
                    shortTitle: "Next Dock Profile", systemImageName: "arrow.forward.circle")
    }
}
