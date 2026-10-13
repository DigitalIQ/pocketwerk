import AppKit

/// One place a profile can be linked to: a Space ("space:…") or a whole display ("display:…").
nonisolated struct SpacePlace: Hashable, Sendable {
    var id: String
    var label: String
}

/// Pure rules for linking profiles to Spaces and displays.
nonisolated enum SpaceRules {
    /// The profile for the current places: a Space link wins over a display link.
    static func profile(for identifiers: [String], in profiles: [DockProfile]) -> UUID? {
        for id in identifiers {
            if let p = profiles.first(where: { $0.spaces.contains(id) }) { return p.id }
        }
        return nil
    }

    /// Current Space and display from the window server's display list (`CGSCopyManagedDisplaySpaces`).
    /// `activeSpace` picks the display the user is on; `mainDisplayUUID` replaces the "Main" placeholder.
    static func places(displays: [[String: Any]], activeSpace: Int?, mainDisplayUUID: String?) -> [SpacePlace] {
        let active = displays.first { d in
            guard let activeSpace else { return false }
            return ((d["Current Space"] as? [String: Any])?["ManagedSpaceID"] as? Int) == activeSpace
        } ?? displays.first
        guard let display = active else { return [] }
        var displayID = display["Display Identifier"] as? String ?? ""
        if displayID == "Main" || displayID.isEmpty { displayID = mainDisplayUUID ?? "main" }
        var out: [SpacePlace] = []
        if let current = display["Current Space"] as? [String: Any] {
            let desktops = (display["Spaces"] as? [[String: Any]] ?? []).filter { ($0["type"] as? Int ?? 0) == 0 }
            let currentID = current["ManagedSpaceID"] as? Int
            let index = desktops.firstIndex { ($0["ManagedSpaceID"] as? Int) == currentID }
            let uuid = current["uuid"] as? String ?? ""
            // The first desktop can have an empty uuid; its position is the next best stable key.
            let key = uuid.isEmpty ? "\(displayID)#\(index ?? 0)" : uuid
            let label = index.map { String(localized: "Desktop \($0 + 1)") } ?? String(localized: "Full-Screen Space")
            out.append(SpacePlace(id: "space:\(key)", label: label))
        }
        out.append(SpacePlace(id: "display:\(displayID)", label: String(localized: "Display")))
        return out
    }
}

/// Watches Space and display changes and applies the linked profile (debounced, at most one Dock restart).
final class SpaceWatcher {
    static let shared = SpaceWatcher()

    private var observers: [NSObjectProtocol] = []
    private var pending: DispatchWorkItem?

    func start() {
        guard observers.isEmpty else { return }
        let ws = NSWorkspace.shared.notificationCenter
        observers.append(ws.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { SpaceWatcher.shared.changed() }
        })
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { SpaceWatcher.shared.changed() }
        })
    }

    private func changed() {
        guard LibraryStore.shared.settings.profilePerSpace else { return }
        pending?.cancel()
        // Swiping across several Spaces fires several times; only the last one counts.
        let work = DispatchWorkItem {
            MainActor.assumeIsolated { _ = DockProfiles.shared.applyForSpace(SpaceWatcher.currentPlaces().map(\.id)) }
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
    }

    /// The current Space (when the window server tells us) and the display under the pointer.
    static func currentPlaces() -> [SpacePlace] {
        if let cgs = CGSSpaces.load(), let displays = cgs.managedDisplaySpaces() {
            let places = SpaceRules.places(displays: displays, activeSpace: cgs.activeSpace(), mainDisplayUUID: displayUUID(CGMainDisplayID()))
            if !places.isEmpty { return places.map(labelled) }
        }
        // Fail safe: no private API, link by display only.
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let number = screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              let uuid = displayUUID(CGDirectDisplayID(number.uint32Value)) else { return [] }
        return [SpacePlace(id: "display:\(uuid)", label: screen?.localizedName ?? String(localized: "Display"))]
    }

    /// Adds the display's name to a display place.
    private static func labelled(_ place: SpacePlace) -> SpacePlace {
        guard place.id.hasPrefix("display:") else { return place }
        let uuid = String(place.id.dropFirst("display:".count))
        let screen = NSScreen.screens.first {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)
                .flatMap { displayUUID(CGDirectDisplayID($0.uint32Value)) } == uuid
        }
        return SpacePlace(id: place.id, label: screen?.localizedName ?? place.label)
    }

    static func displayUUID(_ id: CGDirectDisplayID) -> String? {
        guard let uuid = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() else { return nil }
        return CFUUIDCreateString(nil, uuid) as String?
    }
}

/// Window server calls for Spaces. Private API, looked up at runtime: when a symbol is missing,
/// `load()` returns nil and Pocketwerk links profiles to displays only.
private struct CGSSpaces {
    typealias MainConnection = @convention(c) () -> Int32
    typealias ActiveSpace = @convention(c) (Int32) -> UInt64
    typealias CopyDisplaySpaces = @convention(c) (Int32) -> Unmanaged<CFArray>?

    let connection: Int32
    let active: ActiveSpace
    let copySpaces: CopyDisplaySpaces

    static func load() -> CGSSpaces? {
        let h = UnsafeMutableRawPointer(bitPattern: -2) // RTLD_DEFAULT
        guard let m = dlsym(h, "CGSMainConnectionID"), let a = dlsym(h, "CGSGetActiveSpace"),
              let c = dlsym(h, "CGSCopyManagedDisplaySpaces") else { return nil }
        let main = unsafeBitCast(m, to: MainConnection.self)
        return CGSSpaces(connection: main(), active: unsafeBitCast(a, to: ActiveSpace.self),
                         copySpaces: unsafeBitCast(c, to: CopyDisplaySpaces.self))
    }

    func activeSpace() -> Int? {
        let id = active(connection)
        return id == 0 ? nil : Int(id)
    }

    func managedDisplaySpaces() -> [[String: Any]]? {
        copySpaces(connection)?.takeRetainedValue() as? [[String: Any]]
    }
}
