import AppKit
import SwiftUI

/// "Last context": asks for a short note when switching away from a profile and shows it on return.
/// Only active when `AppSettings.askLastContext` is on.
enum LastContextUI {
    private static var hud: NSPanel?
    private static var hideWork: DispatchWorkItem?

    static func install() {
        DockProfiles.shared.askContextNote = { ask(leaving: $0) }
        DockProfiles.shared.showContextNote = { show($0) }
    }

    /// Modal prompt. Returns nil when skipped, so the old note stays.
    static func ask(leaving profile: DockProfile) -> String? {
        let alert = NSAlert()
        alert.messageText = String(localized: "Leaving \(profile.name)")
        alert.informativeText = String(localized: "A note for when you come back. It shows when you switch to this profile again.")
        let field = NSTextField(string: profile.note)
        field.placeholderString = String(localized: "Where you left off")
        field.frame = NSRect(x: 0, y: 0, width: 300, height: 24)
        field.setAccessibilityLabel(String(localized: "Note"))
        alert.accessoryView = field
        alert.addButton(withTitle: String(localized: "Save Note"))
        alert.addButton(withTitle: String(localized: "Skip"))
        alert.window.initialFirstResponder = field
        NSApp.activate()
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Small non-activating panel at the top of the screen for a few seconds.
    static func show(_ profile: DockProfile) {
        hud?.orderOut(nil)
        let view = NSHostingView(rootView: ContextNoteView(name: profile.name, note: profile.note))
        let size = view.fittingSize
        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size), styleMask: [.nonactivatingPanel, .borderless],
                            backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.hasShadow = true
        panel.contentView = view
        if let screen = NSScreen.main?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: screen.midX - size.width / 2, y: screen.maxY - size.height - 24))
        }
        panel.orderFrontRegardless()
        NSAccessibility.post(element: panel, notification: .announcementRequested,
                             userInfo: [.announcement: "\(profile.name): \(profile.note)"])
        hud = panel
        hideWork?.cancel()
        let work = DispatchWorkItem { MainActor.assumeIsolated { hud?.orderOut(nil); hud = nil } }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 6, execute: work)
    }
}

private struct ContextNoteView: View {
    let name: String
    let note: String
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Last time in \(name)").font(.caption).foregroundStyle(.secondary)
            Text(note).font(.body).fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 320, alignment: .leading)
        .padding(14)
        .background {
            if reduceTransparency {
                RoundedRectangle(cornerRadius: 14).fill(Color(nsColor: .windowBackgroundColor))
            } else {
                RoundedRectangle(cornerRadius: 14).fill(.regularMaterial)
            }
        }
    }
}
