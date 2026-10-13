import AppKit
import PocketwerkShared

/// A parsed `pocketwerk://` URL.
///
///     pocketwerk://open?slot=<uuid>&x=<x>&y=<y>     popup of a slot, above the clicked tile
///     pocketwerk://open?group=<uuid or name>         popup of one group
///     pocketwerk://open                              every group
///     pocketwerk://add?slot=<uuid>&url=<u>&url=<u>   add items (drop on a tile) to the slot's first group
///     pocketwerk://add?group=<uuid>&url=<u>
///     pocketwerk://settings
///     pocketwerk://profile?id=<uuid> | ?name=<name>  apply a Dock profile (&skip=1 skips an active one)
///     pocketwerk://profile?action=capture&name=<n>   save the current Dock as a new profile
///     pocketwerk://profile?action=save               save the current Dock into the active profile
///     pocketwerk://profile?action=next               apply the next profile in the cycle
///     pocketwerk://group?action=openAll|hideAll|quitAll&id=<uuid or name>
nonisolated enum PocketwerkRoute: Equatable {
    case open(slot: UUID?, group: String?, anchor: CGPoint?)
    case add(urls: [URL], slot: UUID?, group: UUID?)
    case settings
    case applyProfile(query: String, skipIfActive: Bool?)
    case captureProfile(name: String)
    case saveProfile
    case nextProfile
    case groupAction(action: String, group: String)

    static func parse(_ url: URL) -> PocketwerkRoute? {
        guard url.scheme?.lowercased() == PWShared.urlScheme,
              let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let items = comps.queryItems ?? []
        func value(_ name: String) -> String? {
            items.first { $0.name == name }?.value.flatMap { $0.isEmpty ? nil : $0 }
        }
        // Accept both pocketwerk://open and pocketwerk:open.
        let host = (comps.host ?? comps.path.split(separator: "/").first.map(String.init) ?? "").lowercased()
        switch host {
        case "open":
            var anchor: CGPoint?
            if let x = value("x").flatMap(Double.init), let y = value("y").flatMap(Double.init) { anchor = CGPoint(x: x, y: y) }
            return .open(slot: value("slot").flatMap(UUID.init(uuidString:)), group: value("group"), anchor: anchor)
        case "add":
            let urls = items.filter { $0.name == "url" }.compactMap { $0.value.flatMap(URL.init(string:)) }
            guard !urls.isEmpty else { return nil }
            return .add(urls: urls, slot: value("slot").flatMap(UUID.init(uuidString:)),
                        group: value("group").flatMap(UUID.init(uuidString:)))
        case "settings":
            return .settings
        case "group":
            guard let action = value("action"), ["openall", "hideall", "quitall"].contains(action.lowercased()),
                  let group = value("id") ?? value("name") else { return nil }
            return .groupAction(action: action.lowercased(), group: group)
        case "profile":
            switch value("action")?.lowercased() {
            case "capture": return .captureProfile(name: value("name") ?? String(localized: "Saved Dock"))
            case "save": return .saveProfile
            case "next": return .nextProfile
            default:
                guard let q = value("id") ?? value("name") else { return nil }
                let skip = value("skip").map { $0 == "1" || $0.lowercased() == "true" }
                return .applyProfile(query: q, skipIfActive: skip)
            }
        default:
            return nil
        }
    }
}

enum DockRoutes {
    /// Handles a `pocketwerk://` URL. Returns false for URLs it does not know.
    @discardableResult
    static func handle(_ url: URL, store: LibraryStore = .shared) -> Bool {
        guard let route = PocketwerkRoute.parse(url) else { return false }
        switch route {
        case .open(let slot, let group, let anchor):
            if let slot {
                DockManager.shared.openSlot(slot, anchor: anchor)
            } else if let group, let g = store.group(matching: group) {
                PopupController.shared.toggle(groupIDs: [g.id], slotID: nil, anchor: anchor)
            } else {
                PopupController.shared.toggleAll()
            }
        case .add(let urls, let slot, let group):
            let target = group.flatMap { store.group($0)?.id }
                ?? slot.flatMap { store.groups(for: $0).first?.id }
                ?? store.library.groups.first?.id
            if let target { store.addItems(urls, to: target) }
        case .settings:
            MainWindowController.shared.show(page: .general)
        case .applyProfile(let query, let skip):
            if let p = DockProfiles.shared.profile(matching: query) { DockProfiles.shared.apply(p.id, skipIfActive: skip) }
        case .captureProfile(let name):
            DockProfiles.shared.captureCurrent(name: name)
        case .saveProfile:
            DockProfiles.shared.saveCurrentToActive()
        case .nextProfile:
            DockProfiles.shared.applyNext()
        case .groupAction(let action, let query):
            guard let g = store.group(matching: query) else { return true }
            switch action {
            case "openall": ItemOpener.openAll(g)
            case "hideall": ItemOpener.hideAll(store.visibleItems(of: g))
            default: ItemOpener.quitAll(store.visibleItems(of: g), force: false)
            }
        }
        return true
    }
}
