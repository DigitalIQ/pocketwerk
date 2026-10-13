import AppKit

/// macOS Services menu entry "Add to Pocketwerk" for URLs, file URLs and text containing links.
/// `register()` also starts the app module's background services (usage tracking, missing item
/// checks, the daily update check, the login item sync, the hot corner) and shows the welcome
/// window once, or the main window when "Open this window when Pocketwerk starts" is on.
final class ServicesProvider: NSObject {
    static let shared = ServicesProvider()

    func register() {
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
        LoginItem.sync(wanted: LibraryStore.shared.settings.launchAtLogin)
        UsageTracker.shared.start()
        LibraryHealth.shared.start()
        UpdateChecker.shared.startDaily()
        HotCornerWatcher.shared.start()
        LibraryStore.shared.removeSmartOnlySlots()
        WelcomeWindowController.shared.showIfNeeded()
        if LibraryStore.shared.settings.onboardingDone && LibraryStore.shared.settings.showWindowOnLaunch {
            // Wait a moment: a start from a link, shortcut or Dock icon opens a popup and stays windowless.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                guard !PopupController.shared.isVisible, !MainWindowController.shared.isVisible else { return }
                MainWindowController.shared.show()
            }
        }
    }

    /// NSMessage "addToPocketwerk" in Info.plist.
    @objc func addToPocketwerk(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        let urls = Self.urls(from: pboard)
        guard !urls.isEmpty else {
            error.pointee = String(localized: "No link, file or folder found.") as NSString
            return
        }
        guard let groupID = GroupPicker.choose(itemCount: urls.count) else { return }
        LibraryStore.shared.insertURLs(urls, into: groupID)
    }

    static func urls(from pboard: NSPasteboard) -> [URL] {
        if let objects = pboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !objects.isEmpty {
            return objects
        }
        if let text = pboard.string(forType: .string) {
            let found = GroupOrdering.links(in: text)
            if !found.isEmpty { return found }
            if let single = GroupOrdering.normalizedLink(text) { return [single] }
        }
        return []
    }
}

/// Small panel that asks which group to add to. Skipped when there is only one group.
enum GroupPicker {
    private static var lastChoice: UUID?

    static func choose(itemCount: Int) -> UUID? {
        let groups = LibraryStore.shared.library.regularGroups
        guard let first = groups.first else {
            return LibraryStore.shared.addGroup(name: String(localized: "Inbox"), emoji: "📥").id
        }
        if groups.count == 1 { return first.id }

        let alert = NSAlert()
        alert.messageText = itemCount == 1
            ? String(localized: "Add to which group?")
            : String(localized: "Add \(itemCount) items to which group?")
        alert.addButton(withTitle: String(localized: "Add"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 240, height: 26), pullsDown: false)
        for g in groups {
            popup.addItem(withTitle: [g.emoji, g.name].compactMap { $0 }.joined(separator: " "))
            popup.lastItem?.representedObject = g.id
        }
        if let last = lastChoice, let i = groups.firstIndex(where: { $0.id == last }) { popup.selectItem(at: i) }
        popup.setAccessibilityLabel(String(localized: "Group"))
        alert.accessoryView = popup
        NSApp.activate()
        guard alert.runModal() == .alertFirstButtonReturn,
              let id = popup.selectedItem?.representedObject as? UUID else { return nil }
        lastChoice = id
        return id
    }
}

/// Reads the front tab of a running browser via AppleScript (asks for Automation permission once).
enum BrowserTab {
    struct Browser: Hashable {
        var name: String
        var bundleID: String
        var script: String
    }

    static let browsers: [Browser] = [
        Browser(name: "Safari", bundleID: "com.apple.Safari",
                script: "tell application id \"com.apple.Safari\" to return (URL of front document) & linefeed & (name of front document)"),
        Browser(name: "Google Chrome", bundleID: "com.google.Chrome", script: chromium("com.google.Chrome")),
        Browser(name: "Arc", bundleID: "company.thebrowser.Browser", script: chromium("company.thebrowser.Browser")),
        Browser(name: "Brave", bundleID: "com.brave.Browser", script: chromium("com.brave.Browser")),
    ]

    private static func chromium(_ id: String) -> String {
        "tell application id \"\(id)\" to return (URL of active tab of front window) & linefeed & (title of active tab of front window)"
    }

    /// Browsers that are running, frontmost first.
    static var running: [Browser] {
        let apps = NSWorkspace.shared.runningApplications
        let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let list = browsers.filter { b in apps.contains { $0.bundleIdentifier == b.bundleID } }
        return list.filter { $0.bundleID == front } + list.filter { $0.bundleID != front }
    }

    enum Failure: Error { case notRunning, noTab, denied(String) }

    static func currentTab(of browser: Browser) -> Result<(url: URL, title: String), Failure> {
        var info: NSDictionary?
        guard let script = NSAppleScript(source: browser.script) else { return .failure(.noTab) }
        let result = script.executeAndReturnError(&info)
        if let info {
            let message = info[NSAppleScript.errorMessage] as? String ?? String(localized: "The browser did not answer.")
            return .failure(.denied(message))
        }
        let lines = (result.stringValue ?? "").components(separatedBy: "\n")
        guard let first = lines.first, let url = URL(string: first), url.scheme != nil else { return .failure(.noTab) }
        return .success((url, lines.dropFirst().joined(separator: " ")))
    }
}

/// "Open All" with the optional confirmation from Settings > General.
enum OpenAllAction {
    static func run(_ group: ItemGroup) {
        let items = LibraryStore.shared.visibleItems(of: group)
        guard !items.isEmpty else { return }
        if LibraryStore.shared.settings.confirmBeforeOpenAll && items.count > 1 {
            let alert = NSAlert()
            alert.messageText = String(localized: "Open all \(items.count) items of “\(group.name)”?")
            alert.addButton(withTitle: String(localized: "Open All"))
            alert.addButton(withTitle: String(localized: "Cancel"))
            alert.showsSuppressionButton = true
            alert.suppressionButton?.title = String(localized: "Don’t ask again")
            NSApp.activate()
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            if alert.suppressionButton?.state == .on { LibraryStore.shared.settings.confirmBeforeOpenAll = false }
        }
        ItemOpener.openAll(group)
    }
}
