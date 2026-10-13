import AppKit
import SwiftUI

// OWNER: app agent. Placeholder with the final API.

/// The management window: groups, items, Dock slots, themes/studio, profiles, settings.
final class MainWindowController {
    static let shared = MainWindowController()
    private var window: NSWindow?

    func show(selecting groupID: UUID? = nil) {
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
                             styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                             backing: .buffered, defer: false)
            w.title = "Pocketwerk"
            w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: Text("Pocketwerk").frame(minWidth: 600, minHeight: 400))
            w.center()
            window = w
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}
