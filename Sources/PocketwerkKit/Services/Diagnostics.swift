import AppKit
import OSLog

/// "Export Diagnostics": the last hours of this app's own log plus a short summary, as a local
/// text file the user picks. Nothing is sent anywhere.
enum Diagnostics {
    /// Summary lines without item names or paths.
    nonisolated static func summary(_ lib: Library, version: String?, system: String) -> String {
        let items = lib.groups.reduce(0) { $0 + $1.items.count }
        let s = lib.settings
        return """
        Pocketwerk \(version ?? "dev")
        macOS \(system)
        Groups: \(lib.groups.count) (smart \(lib.groups.filter { $0.smart != nil }.count)), items: \(items)
        Dock icons: \(lib.slots.count) (in Dock \(lib.slots.filter(\.pinnedInDock).count)), profiles: \(lib.profiles.count)
        Presence: menu bar \(s.showMenuBarIcon), Dock \(s.showMainDockIcon), launch at login \(s.launchAtLogin)
        Hotkeys: main \(s.mainHotkey != nil), numbers \(s.numberHotkeys), leader \(s.leaderHotkey != nil), hot corner \(s.hotCorner.map(String.init) ?? "off")
        """
    }

    /// Log lines of this process from the last `hours`.
    nonisolated static func logLines(hours: Double) -> [String] {
        guard let store = try? OSLogStore(scope: .currentProcessIdentifier) else { return ["(log not readable)"] }
        let since = store.position(date: Date().addingTimeInterval(-hours * 3600))
        guard let entries = try? store.getEntries(at: since) else { return ["(log not readable)"] }
        let format = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        return entries.compactMap { $0 as? OSLogEntryLog }.map { e in
            "\(e.date.formatted(format)) [\(e.category)] \(e.composedMessage)"
        }
    }

    static func exportWithPanel(hours: Double = 5) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "Pocketwerk Diagnostics \(Date().formatted(.iso8601.year().month().day())).txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let head = summary(LibraryStore.shared.library, version: UpdateChecker.currentVersion,
                           system: ProcessInfo.processInfo.operatingSystemVersionString)
        Task {
            let lines = await Task.detached(priority: .utility) { logLines(hours: hours) }.value
            let text = head + "\n\nLog, last \(Int(hours)) hours:\n" + lines.joined(separator: "\n") + "\n"
            do {
                try text.write(to: url, atomically: true, encoding: .utf8)
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } catch {
                NSAlert(error: error).runModal()
            }
        }
    }
}
