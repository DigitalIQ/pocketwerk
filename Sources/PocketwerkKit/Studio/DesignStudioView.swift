import SwiftUI

/// Live editor for a group's look: a gallery of looks, a large preview canvas, and an
/// inspector with the tabs Icon, Popup and Grid. Every change applies at once and can be undone.
struct DesignStudioView: View {
    let groupID: UUID
    @State private var editor: StudioEditor
    @State private var savingTheme = false
    @State private var themeName = ""

    init(groupID: UUID, store: LibraryStore = .shared) {
        self.groupID = groupID
        _editor = State(initialValue: StudioEditor(store: store, groupID: groupID))
    }

    var body: some View {
        Group {
            if editor.exists {
                HStack(spacing: 0) {
                    StudioGallery(editor: editor)
                        .frame(width: 244)
                    Divider()
                    StudioCanvas(editor: editor, onSaveTheme: beginSave)
                        .frame(minWidth: 440, maxWidth: .infinity, maxHeight: .infinity)
                    Divider()
                    StudioInspector(editor: editor)
                        .frame(width: 320)
                }
            } else {
                ContentUnavailableView("No Group", systemImage: "square.dashed",
                                       description: Text("Choose a group to design its look."))
            }
        }
        .frame(minWidth: 1000, minHeight: 640)
        .onChange(of: groupID) { _, new in
            editor = StudioEditor(store: editor.store, groupID: new)
        }
        .alert("Save as Theme", isPresented: $savingTheme) {
            TextField("Name", text: $themeName)
            Button("Save") { editor.saveTheme(named: themeName) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The theme keeps the popup and Dock icon look. Use it for any group.")
        }
    }

    private func beginSave() {
        themeName = String(localized: "\(editor.group.name) Look")
        savingTheme = true
    }
}

/// Inspector with three tabs.
struct StudioInspector: View {
    @Bindable var editor: StudioEditor

    var body: some View {
        VStack(spacing: 0) {
            Picker("Inspector", selection: $editor.tab) {
                ForEach(StudioTab.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(12)
            Divider()
            switch editor.tab {
            case .icon: StudioIconInspector(editor: editor)
            case .popup: StudioPopupInspector(editor: editor)
            case .grid: StudioGridInspector(editor: editor)
            }
        }
        .background(alignment: .topLeading) {
            // Hidden buttons give the tabs keyboard shortcuts.
            VStack {
                Button("Icon") { editor.tab = .icon }.keyboardShortcut("1", modifiers: [.command, .option])
                Button("Popup") { editor.tab = .popup }.keyboardShortcut("2", modifiers: [.command, .option])
                Button("Grid") { editor.tab = .grid }.keyboardShortcut("3", modifiers: [.command, .option])
            }
            .opacity(0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}
