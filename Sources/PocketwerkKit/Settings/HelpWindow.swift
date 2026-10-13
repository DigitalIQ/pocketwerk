import AppKit
import SwiftUI

/// Built-in help: short topics, searchable, works offline.
final class HelpWindowController {
    static let shared = HelpWindowController()
    static let issues = URL(string: "https://github.com/DigitalIQ/pocketwerk/issues")!
    private var window: NSWindow?

    func show(topic: HelpTopic.ID? = nil) {
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 540),
                             styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            w.title = String(localized: "Pocketwerk Help")
            w.isReleasedWhenClosed = false
            w.contentMinSize = NSSize(width: 560, height: 380)
            w.contentViewController = NSHostingController(rootView: HelpView(initial: topic))
            w.center()
            window = w
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    /// Opens the issue tracker. Nothing is sent automatically.
    static func reportProblem() {
        NSWorkspace.shared.open(issues)
    }
}

struct HelpTopic: Identifiable, Hashable {
    let id: String
    let title: LocalizedStringKey
    let symbol: String
    let paragraphs: [LocalizedStringKey]

    static func == (a: HelpTopic, b: HelpTopic) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }

    static let all: [HelpTopic] = [
        HelpTopic(id: "start", title: "Getting Started", symbol: "sparkles", paragraphs: [
            "Pocketwerk keeps apps, files, folders and links in groups. Each group can have its own icon in the Dock. Click the icon and the group opens as a popup above it.",
            "Create a group with ⌘N, then add apps from the App Drawer, files with ⇧⌘F, or drop anything from the Finder onto the list.",
        ]),
        HelpTopic(id: "groups", title: "Groups and Items", symbol: "square.grid.2x2", paragraphs: [
            "Drag items to change their order, or pick a sort order in the toolbar. Right-click an item to rename it, move it to another group or remove it. An empty name brings back the original one.",
            "Drag an item onto a group in the sidebar to move it there. If that group already has it, the item only leaves the old group.",
            "Pin a group to keep it at the top. Hidden groups stay out of All Groups but keep their own Dock icon and shortcut.",
            "Smart groups fill themselves: Most Used, Recently Opened and Running Apps. They are counted on this Mac only.",
        ]),
        HelpTopic(id: "dock", title: "Dock Icons and Profiles", symbol: "dock.rectangle", paragraphs: [
            "A Dock icon can show one group or several. With several, swipe or use the arrow keys in the popup to switch.",
            "A profile is a saved copy of the whole Dock. Apply it from the menu bar, with a shortcut, or with the leader key.",
        ]),
        HelpTopic(id: "keys", title: "Shortcuts", symbol: "keyboard", paragraphs: [
            "⌥⇧1 to ⌥⇧9 open the first nine groups. Give any group, Dock icon or profile its own shortcut under Settings > Hotkeys.",
            "The … button next to a shortcut makes it a double or triple press, or adds a follow-up key, for example ⌃⌥G then W.",
            "The leader key works like a prefix: press it, then the letter of a group or profile. A small list shows the letters while Pocketwerk waits.",
            "Shortcuts need no extra permission and work in full screen apps.",
        ]),
        HelpTopic(id: "corner", title: "Hot Corner and Menu Bar", symbol: "rectangle.inset.topleft.filled", paragraphs: [
            "Under Settings > Popup you can pick a screen corner. Rest the pointer there for a moment to show all groups.",
            "The menu bar icon opens all groups or a menu with every group and its items. Right-click it to always get the menu.",
        ]),
        HelpTopic(id: "assistant", title: "Assistant and Suggestions", symbol: "wand.and.stars", paragraphs: [
            "The Assistant tab changes the selected group from plain language, for example “make it dark blue with list view” or “add Pages and Numbers”. It runs on this Mac with Apple Intelligence.",
            "Every change is listed and can be undone. Items are only removed after you confirm.",
            "The App Drawer suggests apps that fit the group. Without Apple Intelligence the suggestions come from app categories and the apps you use together.",
        ]),
        HelpTopic(id: "backup", title: "Backup", symbol: "externaldrive", paragraphs: [
            "Settings > Backup exports everything into one JSON file. Import offers Merge, which only adds, and Replace. Both can be undone with ⌘Z.",
            "An extra copy of the library can go to any folder, for example iCloud Drive, after every change.",
        ]),
        HelpTopic(id: "privacy", title: "Privacy", symbol: "lock", paragraphs: [
            "Pocketwerk has no account, no analytics and no server. Your groups and usage counts stay on this Mac.",
            "The only network requests are the daily update check against GitHub (can be turned off) and website icons for links.",
            "Diagnostics are written to a local text file only when you export them.",
        ]),
    ]
}

struct HelpView: View {
    @State private var selection: HelpTopic.ID?

    init(initial: HelpTopic.ID?) {
        _selection = State(initialValue: initial ?? HelpTopic.all.first?.id)
    }

    var body: some View {
        NavigationSplitView {
            List(HelpTopic.all, selection: $selection) { topic in
                Label(topic.title, systemImage: topic.symbol).tag(topic.id)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 210)
        } detail: {
            if let topic = HelpTopic.all.first(where: { $0.id == selection }) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Label(topic.title, systemImage: topic.symbol).font(.title2.weight(.semibold))
                        ForEach(Array(topic.paragraphs.enumerated()), id: \.offset) { _, p in
                            Text(p).fixedSize(horizontal: false, vertical: true)
                        }
                        Divider().padding(.vertical, 6)
                        HStack {
                            Text("Something not working?").foregroundStyle(.secondary)
                            Button("Report a Problem…") { HelpWindowController.reportProblem() }
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: 620, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
