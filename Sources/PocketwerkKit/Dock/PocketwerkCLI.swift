import AppKit
import PocketwerkShared

/// Command line interface: `Pocketwerk --cli <command>`. `scripts/pocketwerk` wraps it.
/// When the app is running, commands that change state are sent to it as URLs, so the running
/// app stays the only writer of the library.
public enum PocketwerkCLI {
    static let usage = """
    Usage: pocketwerk <command>

      profiles list                       List Dock profiles (* = active)
      profiles apply <name|id> [--skip-if-active]
      profiles capture <name>             Save the current Dock as a new profile
      profiles save                       Save the current Dock into the active profile
      open <group name|id>                Show a group's popup
      dock                                List the tiles in the current Dock
      slots list                          List Dock slots and their launchers
      slots install <name|id>             Build or update a slot's launcher
      help
    """

    public static func run(_ args: [String]) -> Int32 {
        var out = StandardOutput()
        var err = StandardError()
        let code = execute(args, out: &out, err: &err)
        DockManager.shared.flushDockChanges()
        return code
    }

    static func execute(_ args: [String], out: inout some TextOutputStream, err: inout some TextOutputStream) -> Int32 {
        let words = args.filter { !$0.hasPrefix("--") }
        let flags = Set(args.filter { $0.hasPrefix("--") })
        guard let command = words.first else { print(usage, to: &out); return 0 }
        let rest = Array(words.dropFirst())
        switch command {
        case "help", "-h":
            print(usage, to: &out)
            return 0
        case "profiles":
            return profiles(rest, skipIfActive: flags.contains("--skip-if-active") ? true : nil, out: &out, err: &err)
        case "open":
            guard let query = rest.first else { print("open needs a group name or id", to: &err); return 64 }
            guard let g = LibraryStore.shared.group(matching: rest.joined(separator: " ")) ?? LibraryStore.shared.group(matching: query) else {
                print("No group named \"\(query)\"", to: &err); return 1
            }
            return send(PWShared.url(host: "open", [URLQueryItem(name: "group", value: g.id.uuidString)]), err: &err)
        case "dock":
            let values = DockProfiles.shared.currentValues()
            for t in DockSnapshot.tiles(from: values) {
                let place = t.isOther ? "other" : "app"
                print("\(place)\t\(t.kind.rawValue)\t\(t.label ?? "")\t\(t.url?.isFileURL == true ? t.url!.path : t.url?.absoluteString ?? "")", to: &out)
            }
            return 0
        case "slots":
            return slots(rest, out: &out, err: &err)
        default:
            print("Unknown command \"\(command)\"\n\n\(usage)", to: &err)
            return 64
        }
    }

    private static func profiles(_ args: [String], skipIfActive: Bool?, out: inout some TextOutputStream, err: inout some TextOutputStream) -> Int32 {
        let profiles = DockProfiles.shared
        let store = LibraryStore.shared
        let sub = args.first ?? "list"
        let arg = args.dropFirst().joined(separator: " ")
        switch sub {
        case "list":
            for p in store.library.profiles {
                let mark = store.settings.lastAppliedProfileID == p.id ? "*" : " "
                print("\(mark) \(p.id.uuidString)\t\(p.name)\t\(p.tiles.count) tiles", to: &out)
            }
            return 0
        case "apply":
            guard !arg.isEmpty else { print("apply needs a profile name or id", to: &err); return 64 }
            guard let p = profiles.profile(matching: arg) else { print("No profile \"\(arg)\"", to: &err); return 1 }
            if appIsRunning {
                var items = [URLQueryItem(name: "id", value: p.id.uuidString)]
                if let skipIfActive { items.append(URLQueryItem(name: "skip", value: skipIfActive ? "1" : "0")) }
                return send(PWShared.url(host: "profile", items), err: &err)
            }
            let result = profiles.apply(p.id, skipIfActive: skipIfActive)
            store.saveNow()
            switch result.status {
            case .applied: print("Applied \(p.name)", to: &out)
            case .skippedActive: print("\(p.name) is already active", to: &out)
            case .busy, .notFound: print("Could not apply \(p.name)", to: &err); return 1
            }
            if !result.missing.isEmpty { print("Skipped (missing): \(result.missing.joined(separator: ", "))", to: &out) }
            return 0
        case "capture":
            let name = arg.isEmpty ? String(localized: "Saved Dock") : arg
            if appIsRunning {
                return send(PWShared.url(host: "profile", [URLQueryItem(name: "action", value: "capture"), URLQueryItem(name: "name", value: name)]), err: &err)
            }
            guard let p = profiles.captureCurrent(name: name) else { print("The Dock is empty or could not be read", to: &err); return 1 }
            store.saveNow()
            print("\(p.id.uuidString)\t\(p.name)", to: &out)
            return 0
        case "save":
            if appIsRunning {
                return send(PWShared.url(host: "profile", [URLQueryItem(name: "action", value: "save")]), err: &err)
            }
            guard profiles.saveCurrentToActive() else { print("No active profile, or the Dock could not be read", to: &err); return 1 }
            store.saveNow()
            return 0
        default:
            print("Unknown profiles command \"\(sub)\"", to: &err)
            return 64
        }
    }

    private static func slots(_ args: [String], out: inout some TextOutputStream, err: inout some TextOutputStream) -> Int32 {
        let store = LibraryStore.shared
        switch args.first ?? "list" {
        case "list":
            for s in store.library.slots {
                let dock = DockManager.shared.isInDock(slotID: s.id) ? "in Dock" : "-"
                print("\(s.id.uuidString)\t\(s.name)\t\(dock)\t\(s.launcherPath ?? "not installed")", to: &out)
            }
            return 0
        case "install":
            let q = args.dropFirst().joined(separator: " ")
            guard let s = store.slot(matching: q) else { print("No slot \"\(q)\"", to: &err); return 1 }
            do {
                let url = try DockManager.shared.installLauncher(for: s.id)
                store.saveNow()
                print(url.path, to: &out)
                return 0
            } catch {
                print(error.localizedDescription, to: &err)
                return 1
            }
        default:
            print("Unknown slots command", to: &err)
            return 64
        }
    }

    /// True when the GUI app runs (not this CLI process).
    static var appIsRunning: Bool {
        NSRunningApplication.runningApplications(withBundleIdentifier: PWShared.mainBundleID)
            .contains { $0.processIdentifier != getpid() }
    }

    /// Opens a pocketwerk:// URL in the background and waits until it is delivered.
    private static func send(_ url: URL, err: inout some TextOutputStream) -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        p.arguments = ["-g", url.absoluteString]
        do {
            try p.run()
            p.waitUntilExit()
        } catch {
            print(error.localizedDescription, to: &err)
            return 1
        }
        return p.terminationStatus
    }
}

private struct StandardOutput: TextOutputStream {
    mutating func write(_ string: String) { FileHandle.standardOutput.write(Data(string.utf8)) }
}

private struct StandardError: TextOutputStream {
    mutating func write(_ string: String) { FileHandle.standardError.write(Data(string.utf8)) }
}
