import Foundation

/// Slot and spacer helpers used by the Dock views, the CLI and URL routes.
extension LibraryStore {
    @discardableResult
    func addSlot(name: String, groupIDs: [UUID]) -> DockSlot {
        let slot = DockSlot(name: name, groupIDs: groupIDs)
        mutate { $0.slots.append(slot) }
        return slot
    }

    /// Removes the slot; DockManager notices and deletes its launcher.
    func deleteSlot(_ id: UUID) {
        mutate { $0.slots.removeAll { $0.id == id } }
    }

    func moveSlots(from source: IndexSet, to destination: Int) {
        mutate { $0.slots.move(fromOffsets: source, toOffset: destination) }
    }

    @discardableResult
    func addSpacer(text: String) -> CustomSpacer {
        var spacer = CustomSpacer()
        spacer.text = text
        spacer.icon = IconSpec(content: .text(text), shape: .none)
        let s = spacer
        mutate { $0.spacers.append(s) }
        return spacer
    }

    func updateSpacer(_ id: UUID, _ change: (inout CustomSpacer) -> Void) {
        mutate { lib in
            guard let i = lib.spacers.firstIndex(where: { $0.id == id }) else { return }
            change(&lib.spacers[i])
        }
    }

    func deleteSpacer(_ id: UUID) {
        mutate { $0.spacers.removeAll { $0.id == id } }
    }

    /// Group by UUID string or name (case-insensitive).
    func group(matching query: String) -> ItemGroup? {
        if let id = UUID(uuidString: query), let g = group(id) { return g }
        return library.groups.first { $0.name.caseInsensitiveCompare(query) == .orderedSame }
    }

    /// Slot by UUID string or name (case-insensitive).
    func slot(matching query: String) -> DockSlot? {
        if let id = UUID(uuidString: query), let s = slot(id) { return s }
        return library.slots.first { $0.name.caseInsensitiveCompare(query) == .orderedSame }
    }
}
