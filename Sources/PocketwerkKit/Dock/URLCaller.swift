import AppKit
import PocketwerkShared

/// The app that opened a `pocketwerk://` URL.
///
/// Any website, mail or document can open such a URL. Routes that change the library, the Dock or
/// running apps therefore ask first, unless the URL comes from Pocketwerk itself (app, CLI,
/// launchers) or from Shortcuts. Opening a popup and showing Settings never ask.
nonisolated struct URLCaller: Equatable {
    var bundleID: String?
    var executablePath: String?
    var name: String?

    init(bundleID: String? = nil, executablePath: String? = nil, name: String? = nil) {
        self.bundleID = bundleID
        self.executablePath = executablePath
        self.name = name
    }

    /// Calls from inside Pocketwerk, for example the self test.
    static let pocketwerk = URLCaller(bundleID: PWShared.mainBundleID, executablePath: nil, name: "Pocketwerk")
    /// The Apple event carried no sender we could identify.
    static let unknown = URLCaller(bundleID: nil, executablePath: nil, name: nil)

    /// Shortcuts runs "Open URLs" in one of these processes.
    static let trustedBundlePrefixes = ["com.apple.shortcuts", "com.apple.WorkflowKit"]

    func isTrusted(ownExecutable: String? = Bundle.main.executablePath) -> Bool {
        if let id = bundleID {
            if id == PWShared.mainBundleID || id.hasPrefix(PWShared.launcherBundleIDPrefix)
                || id.hasPrefix(PWShared.spacerBundleIDPrefix) { return true }
            if Self.trustedBundlePrefixes.contains(where: { id.hasPrefix($0) }) { return true }
        }
        // The CLI runs Pocketwerk's own executable outside the app.
        if let path = executablePath, let own = ownExecutable, path == own { return true }
        return false
    }

    /// Sender of the Apple event Pocketwerk is handling right now, if macOS names one.
    static func current() -> URLCaller? {
        guard let pid = NSAppleEventManager.shared().currentAppleEvent?
            .attributeDescriptor(forKeyword: keySenderPIDAttr)?.int32Value, pid > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: 4096) // PROC_PIDPATHINFO_MAXSIZE
        let path = proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 ? String(cString: buffer) : nil
        let app = NSRunningApplication(processIdentifier: pid)
        return URLCaller(bundleID: app?.bundleIdentifier, executablePath: path, name: app?.localizedName)
    }
}

extension PocketwerkRoute {
    /// True for routes that change the library, the Dock or running apps.
    nonisolated var changesSomething: Bool {
        switch self {
        case .open, .settings: return false
        case .groupAction(let action, _): return action != "hideall"
        case .add, .applyProfile, .captureProfile, .saveProfile, .nextProfile: return true
        }
    }
}

enum URLConfirmation {
    /// Asks before a changing route from an untrusted app runs. Returns true to go ahead.
    static func ask(_ route: PocketwerkRoute, caller: URLCaller) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = question(for: route)
        let who = caller.name ?? String(localized: "Another app")
        var info = String(localized: "\(who) opened a Pocketwerk link. Only allow this if you started it yourself.")
        if case .add(let urls, _, _) = route {
            let shown = urls.prefix(5).map { $0.isFileURL ? $0.path : $0.absoluteString }
            info += "\n\n" + shown.joined(separator: "\n")
            if urls.count > 5 { info += "\n…" }
        }
        alert.informativeText = info
        alert.addButton(withTitle: String(localized: "Cancel"))
        alert.addButton(withTitle: String(localized: "Allow"))
        NSApp.activate()
        return alert.runModal() == .alertSecondButtonReturn
    }

    static func question(for route: PocketwerkRoute) -> String {
        switch route {
        case .add: return String(localized: "Add these items to Pocketwerk?")
        case .applyProfile(let query, _): return String(localized: "Apply the Dock profile “\(query)”?")
        case .captureProfile(let name): return String(localized: "Save the current Dock as the profile “\(name)”?")
        case .saveProfile: return String(localized: "Overwrite the active Dock profile with the current Dock?")
        case .nextProfile: return String(localized: "Switch to the next Dock profile?")
        case .groupAction(let action, let group):
            return action == "quitall"
                ? String(localized: "Quit every app in “\(group)”?")
                : String(localized: "Open every item in “\(group)”?")
        case .open, .settings: return ""
        }
    }
}
