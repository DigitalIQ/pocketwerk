import AppKit
import FoundationModels
import Observation

/// Compact text about a group for the model. Keeps well inside the 8192 token context.
enum AssistantContext {
    static func summary(of group: ItemGroup, in lib: Library, apps: [AppInfo], themeName: String?) -> String {
        let s = group.usesDefaultStyle ? lib.settings.defaultStyle : group.style
        let fill: String = switch s.background {
        case .solid(let c): "solid \(c.hex)"
        case .gradient(let colors, _): "gradient \(colors.map(\.hex).joined(separator: ","))"
        case .mesh: "soft color mix"
        case .image: "photo"
        case .glass: "glass"
        case .fx(let p): "animated \(p.kind.rawValue)"
        case .wallpaper: "desktop picture"
        case .texture(let name, _): "texture \(name)"
        }
        let icon: String = switch group.icon.content {
        case .itemGrid: "grid of item icons"
        case .itemStack: "stack"
        case .symbol(let n): "symbol \(n)"
        case .emoji(let e): "emoji \(e)"
        case .text(let t): "text \(t)"
        case .monogram: "monogram"
        case .image: "own picture"
        }
        let byBundle = Dictionary(apps.compactMap { a in a.bundleID.map { ($0, a) } }, uniquingKeysWith: { a, _ in a })
        let items = group.smart == nil ? group.items : LibraryStore.shared.visibleItems(of: group)
        let itemText = items.prefix(30).map { item -> String in
            var parts = [item.kind.rawValue]
            if let bid = item.bundleID, let cat = byBundle[bid]?.category { parts.append(cat) }
            let launches = (item.bundleID.flatMap { lib.usage.launches[$0] } ?? 0) + item.openCount
            if launches > 0 { parts.append("used \(launches)x") }
            return "\(item.displayName) (\(parts.joined(separator: ", ")))"
        }.joined(separator: "; ")
        let others = lib.groups.filter { $0.id != group.id }.prefix(15)
            .map { "\($0.name) (\($0.items.count))" }.joined(separator: ", ")
        return """
        Group: \(group.name)\(group.emoji.map { " \($0)" } ?? ""), category \(group.category ?? "none")\(group.smart != nil ? ", smart group (items are automatic)" : "")
        Look: \(themeName.map { "theme \($0), " } ?? "")fill \(fill), layout \(s.layout.rawValue), columns \(s.columns == 0 ? "auto" : String(s.columns)), icon size \(Int(s.iconSize)), labels \(s.labels.mode.rawValue), corners \(Int(s.cornerRadius)), border \(s.border == nil ? "none" : "yes"), appearance \(s.appearance.rawValue)
        Dock icon: \(icon). Sort: \(group.sortOrder.rawValue)
        Items (\(items.count)): \(itemText.isEmpty ? "none" : itemText)\(items.count > 30 ? "; …" : "")
        Other groups: \(others.isEmpty ? "none" : others)
        """
    }
}

/// One request and what came of it.
struct AssistantTurn: Identifiable {
    let id = UUID()
    var request: String
    var reply = ""
    var changes: [String] = []
    var skipped: [String] = []
    /// Group before and after the change, for undo.
    var before: ItemGroup?
    var after: ItemGroup?
    /// Items waiting for the user's OK before they are removed.
    var removals: [DockItem] = []
    var undone = false
    var failed = false
}

/// Chat with the on-device model about one group. Lives in memory only and is gone when the app quits.
@Observable
final class AssistantConversation {
    private static var all: [UUID: AssistantConversation] = [:]

    static func forGroup(_ id: UUID) -> AssistantConversation {
        if let c = all[id] { return c }
        let c = AssistantConversation(groupID: id)
        all[id] = c
        return c
    }

    let groupID: UUID
    private(set) var turns: [AssistantTurn] = []
    private(set) var isWorking = false
    @ObservationIgnored private var session: LanguageModelSession?
    @ObservationIgnored private var turnsInSession = 0
    private var store: LibraryStore { LibraryStore.shared }

    init(groupID: UUID) { self.groupID = groupID }

    func prewarm() {
        guard AIStatus.current.isAvailable else { return }
        makeSessionIfNeeded().prewarm()
    }

    func clear() {
        turns = []
        session = nil
        turnsInSession = 0
    }

    private var instructions: String {
        let themes = store.allThemes.map(\.name)
        var seen = Set<String>()
        let names = themes.filter { seen.insert($0).inserted }.prefix(70).joined(separator: ", ")
        return """
        You change one group in Pocketwerk, a Mac app that keeps apps, files, folders and links in groups with their own look and Dock icon.
        Turn the user's request into edits. Only use these kinds and value formats:
        \(AssistantKinds.help)
        Before addApp, call findApps to get the exact installed app name. Only remove items the user clearly asks to remove.
        Theme names: \(names).
        If the request is not about this group, make no edits and say what you can do.
        """
    }

    @discardableResult
    private func makeSessionIfNeeded() -> LanguageModelSession {
        // A fresh session every few turns keeps the transcript small.
        if let session, turnsInSession < 4 { return session }
        let s = LanguageModelSession(tools: [FindAppsTool(apps: AppCatalog.shared.apps)], instructions: instructions)
        session = s
        turnsInSession = 0
        return s
    }

    func send(_ text: String) async {
        let request = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !request.isEmpty, !isWorking, store.group(groupID) != nil else { return }
        var turn = AssistantTurn(request: request)
        let status = AIStatus.current
        guard status.isAvailable else {
            turn.reply = status.message
            turn.failed = true
            turns.append(turn)
            return
        }
        isWorking = true
        defer { isWorking = false }
        turns.append(turn)
        await AppCatalog.shared.loadIfNeeded()

        do {
            let plan = try await ask(request, retry: true)
            guard let group = store.group(groupID) else { return }
            let outcome = AssistantInterpreter.apply(plan.edits.map { AssistantEditInput(kind: $0.kind, value: $0.value) },
                                                     to: group, themes: store.allThemes, apps: AppCatalog.shared.apps,
                                                     defaultStyle: store.settings.defaultStyle)
            turn.reply = plan.reply
            turn.changes = outcome.changes
            turn.skipped = outcome.skipped
            turn.removals = outcome.removals
            if outcome.group != group {
                turn.before = group
                turn.after = outcome.group
                store.updateGroup(groupID) { $0 = outcome.group }
                Announce.say(String(localized: "\(outcome.changes.count) changes made"))
            }
        } catch let error as LanguageModelSession.GenerationError {
            turn.failed = true
            turn.reply = switch error {
            case .guardrailViolation: String(localized: "Apple Intelligence did not accept this request. Try other words.")
            case .exceededContextWindowSize: String(localized: "That was too much at once. Try a shorter request.")
            default: String(localized: "Something went wrong: \(error.localizedDescription)")
            }
            session = nil
        } catch {
            turn.failed = true
            turn.reply = String(localized: "Something went wrong: \(error.localizedDescription)")
            session = nil
        }
        replace(turn)
    }

    private func ask(_ request: String, retry: Bool) async throws -> AssistantPlan {
        guard let group = store.group(groupID) else { throw CancellationError() }
        let themeName = group.themeID.flatMap { id in store.allThemes.first { $0.id == id }?.name }
        let prompt = AssistantContext.summary(of: group, in: store.library, apps: AppCatalog.shared.apps, themeName: themeName)
            + "\n\nRequest: " + request
        let session = makeSessionIfNeeded()
        do {
            let response = try await session.respond(to: prompt, generating: AssistantPlan.self,
                                                     options: GenerationOptions(temperature: 0.2))
            turnsInSession += 1
            return response.content
        } catch LanguageModelSession.GenerationError.exceededContextWindowSize(let context) where retry {
            Log.app.info("Assistant context full, new session: \(context.debugDescription)")
            self.session = nil
            return try await ask(request, retry: false)
        }
    }

    private func replace(_ turn: AssistantTurn) {
        if let i = turns.firstIndex(where: { $0.id == turn.id }) { turns[i] = turn }
    }

    // MARK: Undo and confirmations

    /// True when the group still looks exactly like right after this turn.
    func canUndo(_ turn: AssistantTurn) -> Bool {
        guard !turn.undone, let after = turn.after else { return false }
        return store.group(groupID) == after
    }

    func undo(_ turnID: UUID) {
        guard let i = turns.firstIndex(where: { $0.id == turnID }), canUndo(turns[i]), let before = turns[i].before else { return }
        store.updateGroup(groupID) { $0 = before }
        turns[i].undone = true
        Announce.say(String(localized: "Changes undone"))
    }

    func confirmRemovals(_ turnID: UUID) {
        guard let i = turns.firstIndex(where: { $0.id == turnID }) else { return }
        let ids = Set(turns[i].removals.map(\.id))
        let names = turns[i].removals.map(\.displayName)
        guard let before = store.group(groupID) else { return }
        store.removeItems(ids, from: groupID)
        var record = AssistantTurn(request: String(localized: "Remove \(names.joined(separator: ", "))"))
        record.reply = String(localized: "Removed.")
        record.changes = names.map { String(localized: "Removed \($0)") }
        record.before = before
        record.after = store.group(groupID)
        turns[i].removals = []
        turns.append(record)
    }

    func keepItems(_ turnID: UUID) {
        guard let i = turns.firstIndex(where: { $0.id == turnID }) else { return }
        turns[i].removals = []
    }
}

/// VoiceOver announcements for changes that happen without focus moving.
enum Announce {
    static func say(_ text: String) {
        guard let element = NSApp?.keyWindow ?? NSApp?.mainWindow else { return }
        NSAccessibility.post(element: element, notification: .announcementRequested,
                             userInfo: [.announcement: text, .priority: NSAccessibilityPriorityLevel.medium.rawValue])
    }
}
