import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Quiet interface sounds, only with "Sound effects" on.
enum PopupSound {
    enum Kind { case open, launch, remove }

    static func play(_ kind: Kind) {
        guard LibraryStore.shared.settings.soundEffects else { return }
        let name: String
        let volume: Float
        switch kind {
        case .open: name = "Tink"; volume = 0.25
        case .launch: name = "Pop"; volume = 0.3
        case .remove: name = "Bottle"; volume = 0.25
        }
        guard let sound = NSSound(named: NSSound.Name(name))?.copy() as? NSSound else { return }
        sound.volume = volume
        sound.play()
    }
}

/// Missing items: find the new location, or drop the item.
enum MissingItemActions {
    static func isMissing(_ item: DockItem) -> Bool {
        LibraryHealth.shared.missing.contains(item.id)
    }

    /// Menu shown when a missing item is clicked.
    static func menu(for item: DockItem, group: ItemGroup, model: PopupModel) -> NSMenu {
        let menu = NSMenu()
        let title = NSMenuItem(title: String(localized: "“\(PopupIconCache.shared.name(for: item))” can’t be found"), action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(MenuAction.item(String(localized: "Locate…")) { locate(item, group: group, model: model) })
        menu.addItem(MenuAction.item(String(localized: "Remove from Group")) {
            let store = LibraryStore.shared
            store.removeItem(item.id, from: store.owningGroupID(of: item.id, fallback: group.id))
        })
        return menu
    }

    /// File picker for the new location; apps keep their bundle ID up to date.
    static func locate(_ item: DockItem, group: ItemGroup, model: PopupModel) {
        model.actions.suspendAutoClose(true)
        let panel = NSOpenPanel()
        panel.message = String(localized: "Choose the new location of “\(PopupIconCache.shared.name(for: item))”.")
        panel.prompt = String(localized: "Choose")
        panel.canChooseDirectories = item.kind == .folder
        panel.canChooseFiles = item.kind != .folder
        if item.kind == .app {
            panel.allowedContentTypes = [.application]
            panel.directoryURL = URL(fileURLWithPath: "/Applications")
        } else {
            panel.directoryURL = item.url.deletingLastPathComponent()
        }
        NSApp.activate()
        let response = panel.runModal()
        model.actions.suspendAutoClose(false)
        guard response == .OK, let url = panel.url else { return }
        LibraryStore.shared.relinkItem(item.id, in: group.id, to: url)
    }
}

/// Slider for the distance between Dock and popup, with a live preview over the Dock while dragging.
/// For the settings page.
struct PopoverOffsetSlider: View {
    var range: ClosedRange<Double> = 0...60
    @State private var value = LibraryStore.shared.settings.popoverOffset
    @State private var editing = false

    var body: some View {
        Slider(value: $value, in: range, step: 1) { isEditing in
            editing = isEditing
            PopupController.shared.previewOffset(isEditing ? value : nil)
        }
        .onChange(of: value) { _, v in
            LibraryStore.shared.settings.popoverOffset = v
            if editing { PopupController.shared.previewOffset(v) }
        }
        .onDisappear { PopupController.shared.previewOffset(nil) }
        .accessibilityLabel("Distance to Dock")
        .accessibilityValue(Text("\(Int(value)) points"))
    }
}
