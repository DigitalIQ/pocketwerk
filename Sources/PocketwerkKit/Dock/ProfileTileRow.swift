import AppKit
import SwiftUI

/// One tile in the profile editor. Apps get a note and actions, folders get their stack options.
struct ProfileTileRow: View {
    let tile: DockTile
    let profileID: UUID

    private var profiles: DockProfiles { DockProfiles.shared }

    /// Row height for the surrounding list, which needs a fixed frame.
    static func height(for tile: DockTile) -> CGFloat {
        switch tile.kind {
        case .app, .folder: 56
        default: 30
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Image(nsImage: ProfileTiles.icon(for: tile))
                    .resizable()
                    .frame(width: 20, height: 20)
                    .accessibilityHidden(true)
                Text(ProfileTiles.title(for: tile)).lineLimit(1)
                if let path = tile.url?.path, tile.url?.isFileURL == true, !FileManager.default.fileExists(atPath: path) {
                    Text("Missing").font(.caption).foregroundStyle(.orange)
                }
                if !tile.actions.isEmpty {
                    Image(systemName: "bolt.fill").font(.caption).foregroundStyle(.tint)
                        .help(Text(actionSummary))
                        .accessibilityLabel(Text(actionSummary))
                }
                Spacer()
                if tile.kind == .app {
                    TileActionsMenu(tile: tile, profileID: profileID)
                }
                Button {
                    guard let p = profiles.profile(profileID) else { return }
                    profiles.setTiles(p.tiles.filter { $0.id != tile.id }, of: profileID)
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text("Remove \(ProfileTiles.title(for: tile))"))
            }
            if tile.kind == .app {
                TextField("Note", text: Binding(get: { tile.note }, set: { n in update { $0.note = n } }))
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 28)
                    .accessibilityLabel(Text("Note for \(ProfileTiles.title(for: tile))"))
            } else if tile.kind == .folder {
                StackOptionsRow(stack: Binding(
                    get: { tile.folder ?? StackSettings() },
                    set: { s in update(rebuild: true) { $0.folder = s } }))
                    .padding(.leading, 28)
            }
        }
    }

    private var actionSummary: String {
        tile.actions.map { action in
            switch action {
            case .openApp: String(localized: "Opens when applied")
            case .openProject(let url): String(localized: "Opens \(url.lastPathComponent)")
            case .browserProfile(_, let profile): String(localized: "Opens profile \(profile)")
            }
        }.joined(separator: ", ")
    }

    /// Notes do not touch the Dock data; stack options do.
    private func update(rebuild: Bool = false, _ change: (inout DockTile) -> Void) {
        guard var tiles = profiles.profile(profileID)?.tiles, let i = tiles.firstIndex(where: { $0.id == tile.id }) else { return }
        change(&tiles[i])
        if rebuild {
            profiles.setTiles(tiles, of: profileID)
        } else {
            let t = tiles
            profiles.updateProfile(profileID) { $0.tiles = t }
        }
    }
}

/// View, display and sort of a folder tile, as the Dock offers them.
private struct StackOptionsRow: View {
    @Binding var stack: StackSettings

    var body: some View {
        HStack(spacing: 10) {
            Picker("View", selection: $stack.view) {
                Text("Automatic").tag(0)
                Text("Fan").tag(1)
                Text("Grid").tag(2)
                Text("List").tag(3)
            }
            Picker("Display as", selection: $stack.displayAs) {
                Text("Stack").tag(0)
                Text("Folder").tag(1)
            }
            Picker("Sort by", selection: $stack.sort) {
                Text("Name").tag(1)
                Text("Date Added").tag(2)
                Text("Date Modified").tag(3)
                Text("Date Created").tag(4)
                Text("Kind").tag(5)
            }
        }
        .pickerStyle(.menu)
        .controlSize(.small)
        .font(.caption)
        .fixedSize()
    }
}

/// Actions run when the profile is applied: open the app, open a project with it, open a browser profile.
private struct TileActionsMenu: View {
    let tile: DockTile
    let profileID: UUID
    @State private var found: [BrowserProfiles.Profile]?

    private var profiles: DockProfiles { DockProfiles.shared }

    var body: some View {
        Menu {
            Toggle("Open When Applied", isOn: Binding(
                get: { tile.actions.contains(.openApp) },
                set: { on in setActions { a in
                    a.removeAll { $0 == .openApp }
                    if on { a.insert(.openApp, at: 0) }
                } }))
            Button("Open Project or Folder…") { pickProject() }
            if let browser = BrowserProfiles.browser(tile.bundleID) {
                Divider()
                if let found {
                    if found.isEmpty { Text("No profiles found") }
                    ForEach(found, id: \.self) { p in
                        Button(String(localized: "Open Profile “\(p.name)”")) {
                            setActions { $0.append(.browserProfile(bundleID: browser.bundleID, profile: p.id)) }
                        }
                    }
                } else {
                    // Reading another app's profile list may trigger a privacy prompt, so only on request.
                    Button("Find \(browser.name) Profiles") { found = BrowserProfiles.discover(browser) }
                }
            }
            let removable = tile.actions.filter { $0 != .openApp }
            if !removable.isEmpty {
                Divider()
                ForEach(Array(removable.enumerated()), id: \.offset) { _, action in
                    Button(String(localized: "Remove: \(label(action))")) { setActions { $0.removeAll { $0 == action } } }
                }
            }
        } label: {
            Image(systemName: "gearshape")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .accessibilityLabel(Text("Actions for \(ProfileTiles.title(for: tile))"))
    }

    private func label(_ action: TileAction) -> String {
        switch action {
        case .openApp: String(localized: "Open")
        case .openProject(let url): url.lastPathComponent
        case .browserProfile(_, let profile): profile
        }
    }

    private func pickProject() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        setActions { $0.append(.openProject(url)) }
    }

    private func setActions(_ change: (inout [TileAction]) -> Void) {
        guard var tiles = profiles.profile(profileID)?.tiles, let i = tiles.firstIndex(where: { $0.id == tile.id }) else { return }
        change(&tiles[i].actions)
        let t = tiles
        profiles.updateProfile(profileID) { $0.tiles = t }
    }
}
