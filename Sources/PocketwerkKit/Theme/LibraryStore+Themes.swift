import Foundation

/// Own themes and whole-look edits. All changes are undoable.
extension LibraryStore {
    /// Saves the current look of a group as an own theme and marks the group with it.
    @discardableResult
    func saveTheme(from groupID: UUID, name: String) -> Theme? {
        guard let group = group(groupID) else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let theme = ThemeLibrary.makeCustom(from: group, name: trimmed.isEmpty ? group.name : trimmed)
        mutate { lib in
            lib.customThemes.append(theme)
            if let i = lib.groups.firstIndex(where: { $0.id == groupID }) { lib.groups[i].themeID = theme.id }
        }
        return theme
    }

    func renameTheme(_ id: String, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        mutate { lib in
            guard let i = lib.customThemes.firstIndex(where: { $0.id == id }) else { return }
            lib.customThemes[i].name = trimmed
        }
    }

    /// Deletes an own theme. Groups keep their look; only the theme mark is cleared.
    func deleteTheme(_ id: String) {
        mutate { lib in
            lib.customThemes.removeAll { $0.id == id }
            for i in lib.groups.indices where lib.groups[i].themeID == id { lib.groups[i].themeID = nil }
        }
    }

    /// Overwrites an own theme with the current look of a group.
    func updateTheme(_ id: String, from groupID: UUID) {
        guard let group = group(groupID) else { return }
        mutate { lib in
            guard let i = lib.customThemes.firstIndex(where: { $0.id == id }) else { return }
            lib.customThemes[i].style = group.style
            lib.customThemes[i].icon = group.icon
        }
    }

    /// Back to the default look. Layout fields stay.
    func resetLook(of groupID: UUID) {
        updateGroup(groupID) { g in
            g.style = ThemeLibrary.apply(Theme(id: "default", name: "", style: GroupStyle()), to: g.style)
            g.icon = ThemeLibrary.apply(IconSpec(), to: g.icon)
            g.icon.background = nil
            g.themeID = nil
        }
    }

    /// A random look. Layout fields and icon content stay.
    func randomizeLook(of groupID: UUID, seed: UInt64 = UInt64.random(in: 0...UInt64.max)) {
        updateGroup(groupID) { g in
            let (style, icon) = StyleRandomizer.randomLook(base: g.style, icon: g.icon, seed: seed)
            g.style = style
            g.icon = icon
            g.themeID = nil
        }
    }
}
