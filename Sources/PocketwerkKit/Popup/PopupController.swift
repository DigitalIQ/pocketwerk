import AppKit
import SwiftUI

// OWNER: popup agent. Placeholder with the final API.

/// Shows the popup ("Pop") for a Dock slot or a list of groups, near the Dock icon.
final class PopupController {
    static let shared = PopupController()

    private var panel: NSPanel?
    private(set) var currentSlotID: UUID?
    private(set) var isVisible = false

    /// Called when a launcher's Dock icon is clicked or a slot hotkey fires.
    func toggle(slotID: UUID) {
        let groups = LibraryStore.shared.groups(for: slotID).map(\.id)
        toggle(groupIDs: groups, slotID: slotID)
    }

    /// Every group, swipeable. Used by the main app Dock icon, the menu bar, and the main hotkey.
    func toggleAll() {
        toggle(groupIDs: LibraryStore.shared.library.groups.map(\.id), slotID: nil)
    }

    func toggle(groupIDs: [UUID], slotID: UUID?, anchor: CGPoint? = nil) {
        if isVisible, currentSlotID == slotID { hide(); return }
        show(groupIDs: groupIDs, slotID: slotID, anchor: anchor)
    }

    /// anchor: screen point (Cocoa coordinates) to place the popup near; nil = mouse location.
    func show(groupIDs: [UUID], slotID: UUID?, anchor: CGPoint? = nil) {
        hide()
        let view = NSHostingView(rootView: PlaceholderPopupView(groupIDs: groupIDs))
        let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 360, height: 300), styleMask: [.titled, .closable, .nonactivatingPanel], backing: .buffered, defer: false)
        p.contentView = view
        let mouse = anchor ?? NSEvent.mouseLocation
        p.setFrameOrigin(NSPoint(x: mouse.x - 180, y: max(mouse.y, 80)))
        p.isFloatingPanel = true
        p.makeKeyAndOrderFront(nil)
        panel = p
        currentSlotID = slotID
        isVisible = true
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
        isVisible = false
        currentSlotID = nil
    }
}

private struct PlaceholderPopupView: View {
    let groupIDs: [UUID]
    var body: some View {
        let store = LibraryStore.shared
        ScrollView {
            ForEach(groupIDs, id: \.self) { id in
                if let g = store.group(id) {
                    Text(g.name).font(.headline)
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(70)), count: 4)) {
                        ForEach(g.items) { item in
                            Button {
                                ItemOpener.open(item, in: g.id)
                            } label: {
                                VStack {
                                    Image(nsImage: IconRenderer.icon(for: item, size: 48))
                                    Text(item.displayName).font(.caption).lineLimit(1)
                                }
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
        }.padding()
    }
}
