import AppKit
import SwiftUI

/// Short welcome shown once (`onboardingDone`), offering starter groups filled with installed apps.
final class WelcomeWindowController: NSObject, NSWindowDelegate {
    static let shared = WelcomeWindowController()
    private var window: NSWindow?

    func showIfNeeded() {
        guard !LibraryStore.shared.settings.onboardingDone else { return }
        show()
    }

    func show() {
        if window == nil {
            let starters = StarterGroups.build { AppLocator.url(forBundleID: $0) }
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 520),
                             styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
            w.titlebarAppearsTransparent = true
            w.title = String(localized: "Welcome to Pocketwerk")
            w.isReleasedWhenClosed = false
            w.contentViewController = NSHostingController(rootView: WelcomeView(starters: starters) { [weak self] in
                self?.finish()
            })
            w.center()
            w.delegate = self
            window = w
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    private func finish() {
        LibraryStore.shared.settings.onboardingDone = true
        window?.close()
        window = nil
        MainWindowController.shared.show()
    }

    /// Closing the window counts as "skip".
    func windowWillClose(_ notification: Notification) {
        if !LibraryStore.shared.settings.onboardingDone { LibraryStore.shared.settings.onboardingDone = true }
        window = nil
    }
}

struct WelcomeView: View {
    let starters: [StarterGroup]
    let done: () -> Void
    @State private var chosen: Set<String>
    @State private var mostUsed = true

    init(starters: [StarterGroup], done: @escaping () -> Void) {
        self.starters = starters
        self.done = done
        _chosen = State(initialValue: Set(starters.map(\.name)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 56, height: 56)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Welcome to Pocketwerk").font(.title.weight(.semibold))
                    Text("Your apps, files and links in groups, one click from the Dock.")
                        .foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                point("square.grid.2x2", "Put apps, files, folders and links into groups.")
                point("dock.rectangle", "Give each group its own Dock icon. A click opens it as a popup.")
                point("keyboard", "Open groups from anywhere with ⌥⇧1 to ⌥⇧9.")
            }
            Divider()
            Text("Start with a few groups?").font(.headline)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(starters) { s in
                    Toggle(isOn: Binding(get: { chosen.contains(s.name) },
                                         set: { on in if on { chosen.insert(s.name) } else { chosen.remove(s.name) } })) {
                        HStack(spacing: 8) {
                            Text(s.emoji)
                            Text(LocalizedStringKey(s.name)).frame(width: 80, alignment: .leading)
                            HStack(spacing: -6) {
                                ForEach(s.apps.prefix(7), id: \.self) { url in
                                    Image(nsImage: AppIconCache.icon(for: url)).resizable().frame(width: 24, height: 24)
                                }
                            }
                            .accessibilityHidden(true)
                            Text("\(s.apps.count) apps").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Toggle(isOn: $mostUsed) {
                    HStack(spacing: 8) {
                        Image(systemName: "star.fill").foregroundStyle(.yellow)
                        Text("Most Used, fills itself as you work")
                    }
                }
            }
            Spacer(minLength: 0)
            HStack {
                Button("Skip") { done() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add Groups") {
                    LibraryStore.shared.addStarterGroups(starters.filter { chosen.contains($0.name) }, includeMostUsed: mostUsed)
                    done()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(chosen.isEmpty && !mostUsed)
            }
        }
        .padding(28)
        .frame(width: 520)
    }

    private func point(_ symbol: String, _ text: LocalizedStringKey) -> some View {
        Label { Text(text) } icon: { Image(systemName: symbol).foregroundStyle(Color.accentColor).frame(width: 22) }
    }
}
