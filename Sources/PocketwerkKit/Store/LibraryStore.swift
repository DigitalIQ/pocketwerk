import AppKit
import Observation

extension Notification.Name {
    /// Posted after every library change. Listeners: Dock icons, hotkeys, menu bar.
    static let libraryDidChange = Notification.Name("PocketwerkLibraryDidChange")
}

/// Single source of truth. Every change goes through `mutate`, which records undo,
/// saves to disk (debounced) and posts `.libraryDidChange`.
@Observable
final class LibraryStore {
    static let shared = LibraryStore()

    private(set) var library: Library
    @ObservationIgnored private var undoStack: [Library] = []
    @ObservationIgnored private var redoStack: [Library] = []
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored let fileURL: URL

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    /// ~/Library/Application Support/Pocketwerk, or $POCKETWERK_DATA_DIR for development runs.
    static var directory: URL {
        let env = ProcessInfo.processInfo.environment["POCKETWERK_DATA_DIR"]
        let dir = env.map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Pocketwerk", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.directory.appendingPathComponent("library.json")
        self.library = Self.load(from: self.fileURL) ?? Self.starterLibrary()
    }

    // MARK: Mutation

    var settings: AppSettings {
        get { library.settings }
        set { mutate(undoable: false) { $0.settings = newValue } }
    }

    func mutate(undoable: Bool = true, _ change: (inout Library) -> Void) {
        var copy = library
        change(&copy)
        guard copy != library else { return }
        if undoable {
            undoStack.append(library)
            if undoStack.count > 100 { undoStack.removeFirst() }
            redoStack.removeAll()
        }
        library = copy
        didChange()
    }

    func undo() {
        guard let last = undoStack.popLast() else { return }
        redoStack.append(library)
        library = last
        didChange()
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(library)
        library = next
        didChange()
    }

    /// Replaces the whole library (import). Undoable.
    func replace(with newLibrary: Library) {
        mutate { $0 = newLibrary }
    }

    private func didChange() {
        scheduleSave()
        NotificationCenter.default.post(name: .libraryDidChange, object: self)
    }

    // MARK: Groups

    func group(_ id: UUID) -> ItemGroup? { library.group(id) }

    func updateGroup(_ id: UUID, undoable: Bool = true, _ change: (inout ItemGroup) -> Void) {
        mutate(undoable: undoable) { lib in
            guard let i = lib.groups.firstIndex(where: { $0.id == id }) else { return }
            change(&lib.groups[i])
        }
    }

    /// Creates a group and, by default, a Dock slot that shows just this group.
    @discardableResult
    func addGroup(name: String, withSlot: Bool = true) -> ItemGroup {
        let group = ItemGroup(name: name)
        mutate { lib in
            lib.groups.append(group)
            if withSlot { lib.slots.append(DockSlot(name: name, groupIDs: [group.id])) }
        }
        return group
    }

    func deleteGroup(_ id: UUID) {
        mutate { lib in
            lib.groups.removeAll { $0.id == id }
            for i in lib.slots.indices { lib.slots[i].groupIDs.removeAll { $0 == id } }
        }
    }

    func addItems(_ urls: [URL], to groupID: UUID, at index: Int? = nil) {
        updateGroup(groupID) { g in
            let existing = Set(g.items.map(\.url))
            let new = urls.filter { !existing.contains($0) }.map { DockItem(url: $0) }
            let at = min(index ?? g.items.count, g.items.count)
            g.items.insert(contentsOf: new, at: at)
        }
    }

    func removeItem(_ itemID: UUID, from groupID: UUID) {
        updateGroup(groupID) { $0.items.removeAll { $0.id == itemID } }
    }

    func moveItems(in groupID: UUID, from source: IndexSet, to destination: Int) {
        updateGroup(groupID) { g in
            g.items.move(fromOffsets: source, toOffset: destination)
            g.sortOrder = .manual
        }
    }

    /// Usage stats. Not undoable, so it never pollutes the undo history.
    func recordOpen(_ itemID: UUID, in groupID: UUID) {
        updateGroup(groupID, undoable: false) { g in
            guard let i = g.items.firstIndex(where: { $0.id == itemID }) else { return }
            g.items[i].openCount += 1
            g.items[i].lastOpenedAt = Date()
        }
    }

    /// Items a popup shows for a group: sorted, and computed for smart groups.
    func visibleItems(of group: ItemGroup) -> [DockItem] {
        guard let smart = group.smart else { return group.sortedItems }
        return smartItems(smart, limit: group.smartLimit)
    }

    /// The group that really holds an item (smart groups only borrow items).
    func owningGroupID(of itemID: UUID, fallback: UUID) -> UUID {
        library.groups.first { $0.smart == nil && $0.items.contains { $0.id == itemID } }?.id ?? fallback
    }

    // MARK: Slots

    func slot(_ id: UUID) -> DockSlot? { library.slot(id) }

    func updateSlot(_ id: UUID, undoable: Bool = true, _ change: (inout DockSlot) -> Void) {
        mutate(undoable: undoable) { lib in
            guard let i = lib.slots.firstIndex(where: { $0.id == id }) else { return }
            change(&lib.slots[i])
        }
    }

    /// Groups shown by a slot, in slot order, skipping deleted ones.
    func groups(for slotID: UUID) -> [ItemGroup] {
        guard let slot = slot(slotID) else { return [] }
        return slot.groupIDs.compactMap { group($0) }
    }

    // MARK: Themes

    var allThemes: [Theme] { ThemeLibrary.builtIn + library.customThemes }

    func applyTheme(_ theme: Theme, to groupID: UUID) {
        updateGroup(groupID) { g in
            g.style = ThemeLibrary.apply(theme, to: g.style)
            if let icon = theme.icon { g.icon = ThemeLibrary.apply(icon, to: g.icon) }
            g.themeID = theme.id
        }
    }

    // MARK: Persistence

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    func saveNow() {
        do {
            let data = try Self.encoder.encode(library)
            try data.write(to: fileURL, options: .atomic)
            if let folder = library.settings.syncFolderPath {
                let copy = URL(fileURLWithPath: folder).appendingPathComponent("Pocketwerk-library.json")
                try? data.write(to: copy, options: .atomic)
            }
        } catch {
            NSLog("Pocketwerk: save failed: \(error)")
        }
    }

    func export(to url: URL) throws {
        try Self.encoder.encode(library).write(to: url, options: .atomic)
    }

    func importLibrary(from url: URL) throws {
        let data = try Data(contentsOf: url)
        guard let lib = Self.decodeLeniently(data) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        replace(with: lib)
    }

    nonisolated static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    nonisolated static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private static func load(from url: URL) -> Library? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        if let lib = decodeLeniently(data) { return lib }
        // Keep the unreadable file so nothing is lost.
        let backup = url.deletingLastPathComponent()
            .appendingPathComponent("library-unreadable-\(Int(Date().timeIntervalSince1970)).json")
        try? FileManager.default.copyItem(at: url, to: backup)
        NSLog("Pocketwerk: library unreadable, copy kept at \(backup.path)")
        return nil
    }

    /// Decodes a library and fills keys that older files do not have with defaults.
    static func decodeLeniently(_ data: Data) -> Library? {
        if let lib = try? decoder.decode(Library.self, from: data) { return lib }
        guard let stored = try? JSONSerialization.jsonObject(with: data),
              let merged = LenientMerge.merge(stored, LenientMerge.templateValue(for: "library")),
              let mergedData = try? JSONSerialization.data(withJSONObject: merged)
        else { return nil }
        return try? decoder.decode(Library.self, from: mergedData)
    }

    static func starterLibrary() -> Library {
        var lib = Library()
        var g = ItemGroup(name: "Favorites")
        let apps = ["/System/Applications/Mail.app", "/System/Applications/Calendar.app",
                    "/System/Applications/Notes.app", "/Applications/Safari.app",
                    "/System/Applications/Music.app", "/System/Applications/System Settings.app"]
        g.items = apps.filter { FileManager.default.fileExists(atPath: $0) }
            .map { DockItem(kind: .app, url: URL(fileURLWithPath: $0)) }
        lib.groups = [g]
        lib.slots = [DockSlot(name: g.name, groupIDs: [g.id])]
        return lib
    }
}

/// Deep-merges stored JSON over a default template so new model fields get defaults.
/// Enum values (synthesized Codable: an object with exactly one case key) are never mixed.
nonisolated enum LenientMerge {
    static func templateValue(for key: String) -> Any? {
        let value: (any Encodable)? = switch key {
        case "library": Library()
        case "groups": ItemGroup(name: "")
        case "items": DockItem(kind: .file, url: URL(fileURLWithPath: "/"))
        case "slots": DockSlot(name: "", groupIDs: [])
        case "customThemes": Theme(id: "", name: "", style: GroupStyle())
        case "profiles": DockProfile(name: "", plistData: Data())
        case "spacers": CustomSpacer()
        case "tiles": DockTile(kind: .app)
        default: nil
        }
        guard let value, let data = try? LibraryStore.encoder.encode(value) else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }

    static func merge(_ stored: Any, _ template: Any?, key: String? = nil) -> Any? {
        if let arr = stored as? [Any] {
            let elementTemplate = key.flatMap { templateValue(for: $0) }
            return arr.map { elementTemplate == nil ? $0 : (merge($0, elementTemplate) ?? $0) }
        }
        guard let dict = stored as? [String: Any] else { return stored }
        guard let tdict = template as? [String: Any] else {
            var out: [String: Any] = [:]
            for (k, v) in dict { out[k] = merge(v, nil, key: k) }
            return out
        }
        if dict.count == 1, tdict.count == 1, dict.keys.first != tdict.keys.first { return dict }
        var out = tdict
        for (k, v) in dict { out[k] = merge(v, tdict[k], key: k) }
        return out
    }
}
