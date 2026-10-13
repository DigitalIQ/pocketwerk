import SwiftUI

/// Sidebar with every built-in look and the user's own themes. A click applies the look.
struct StudioGallery: View {
    @Bindable var editor: StudioEditor
    @State private var renaming: Theme?
    @State private var renameText = ""
    @State private var deleting: Theme?

    var body: some View {
        let group = editor.group
        let samples = Array(editor.store.visibleItems(of: group).prefix(3))
        let sections = filtered(ThemeLibrary.sections(custom: editor.store.library.customThemes))
        VStack(spacing: 0) {
            TextField("Search Looks", text: $editor.search)
                .textFieldStyle(.roundedBorder)
                .padding(12)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10, pinnedViews: [.sectionHeaders]) {
                    ForEach(sections) { section in
                        Section {
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 12) {
                                ForEach(section.themes) { theme in
                                    ThemeTile(theme: theme, selected: group.themeID == theme.id, items: samples) {
                                        editor.apply(theme)
                                    }
                                    .contextMenu { if !theme.isBuiltIn { customMenu(theme) } }
                                }
                            }
                            .padding(.bottom, 8)
                        } header: {
                            Text(LocalizedStringKey(section.title))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .padding(.vertical, 5)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.bar)
                                .accessibilityAddTraits(.isHeader)
                        }
                    }
                    if sections.isEmpty {
                        Text("No Matching Looks")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .alert("Rename Theme", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $renameText)
            Button("Rename") {
                if let renaming { editor.store.renameTheme(renaming.id, to: renameText) }
                renaming = nil
            }
            Button("Cancel", role: .cancel) { renaming = nil }
        }
        .confirmationDialog("Delete this theme?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                            presenting: deleting) { theme in
            Button("Delete “\(theme.name)”", role: .destructive) { editor.store.deleteTheme(theme.id) }
        } message: { _ in
            Text("Groups using it keep their look.")
        }
    }

    @ViewBuilder private func customMenu(_ theme: Theme) -> some View {
        Button("Rename…") {
            renameText = theme.name
            renaming = theme
        }
        Button("Update with Current Look") { editor.store.updateTheme(theme.id, from: editor.groupID) }
        Divider()
        Button("Delete…", role: .destructive) { deleting = theme }
    }

    private func filtered(_ sections: [ThemeLibrary.Section]) -> [ThemeLibrary.Section] {
        let q = editor.search.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return sections }
        return sections.compactMap { s in
            if s.title.localizedCaseInsensitiveContains(q) { return s }
            let hits = s.themes.filter { $0.name.localizedCaseInsensitiveContains(q) }
            return hits.isEmpty ? nil : ThemeLibrary.Section(title: s.title, themes: hits)
        }
    }
}

/// One look in the gallery. Animated looks play while the pointer rests on them.
struct ThemeTile: View {
    let theme: Theme
    let selected: Bool
    let items: [DockItem]
    let action: () -> Void
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let radius = min(theme.style.cornerRadius * 0.5, 14)
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                ThemeSwatch(style: theme.style, items: items, animate: hovering, height: 58)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius + 3, style: .continuous)
                            .strokeBorder(Color.accentColor, lineWidth: selected ? 2.5 : 0)
                            .padding(-3)
                    )
                Text(theme.name)
                    .font(.caption)
                    .foregroundStyle(selected ? .primary : .secondary)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .scaleEffect(hovering && !reduceMotion ? 1.03 : 1)
        .animation(.snappy(duration: 0.18), value: hovering)
        .onHover { hovering = $0 }
        .help(Text(theme.name))
        .accessibilityLabel(Text(theme.name))
        .accessibilityHint(Text("Applies this look"))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
