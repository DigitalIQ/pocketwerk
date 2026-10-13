import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Saved Dock layouts: list on the left, editor on the right. Every change saves right away.
struct DockProfilesView: View {
    @State private var selection: UUID?
    @State private var error: String?

    init(selection: UUID? = nil) {
        _selection = State(initialValue: selection)
    }

    private var store: LibraryStore { LibraryStore.shared }
    private var profiles: DockProfiles { DockProfiles.shared }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                List(selection: $selection) {
                    ForEach(store.library.profiles) { p in
                        ProfileListRow(profile: p)
                            .tag(p.id)
                            .contextMenu { contextMenu(for: p) }
                    }
                    .onMove { profiles.move(from: $0, to: $1) }
                }
                Divider()
                HStack(spacing: 6) {
                    Menu {
                        Button("From Current Dock") { captureCurrent() }
                        Button("Empty Profile") { selection = profiles.createEmpty(name: String(localized: "New Profile")).id }
                        Divider()
                        Button("Import…") { importProfile() }
                        Button("Export All…") { exportAll() }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .accessibilityLabel(Text("Add profile"))
                    Spacer()
                }
                .padding(8)
                GlobalProfileOptions()
                    .padding(8)
            }
            .frame(width: 230)
            Divider()
            Group {
                if let id = selection, store.library.profiles.contains(where: { $0.id == id }) {
                    ProfileEditor(profileID: id)
                } else {
                    VStack(spacing: 10) {
                        Text("No Profile Selected").font(.title3)
                        Text("A profile is a saved copy of your whole Dock. Switch between them with one click, a hotkey, a URL or the command line.")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: 320)
                        Button("Save Current Dock") { captureCurrent() }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .alert(Text("Dock Profiles"), isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK") { error = nil }
        } message: {
            Text(error ?? "")
        }
    }

    @ViewBuilder
    private func contextMenu(for p: DockProfile) -> some View {
        Button("Apply") { profiles.apply(p.id) }
        Button("Duplicate") { selection = profiles.duplicate(p.id)?.id }
        Button("Export…") { export(p) }
        Button("Share…") { share(p) }.disabled(p.isPrivate)
        Divider()
        Button("Delete", role: .destructive) {
            if selection == p.id { selection = nil }
            profiles.delete(p.id)
        }
    }

    private func captureCurrent() {
        let name = String(localized: "Dock \(Date().formatted(date: .abbreviated, time: .shortened))")
        if let p = profiles.captureCurrent(name: name) {
            selection = p.id
        } else {
            error = DockProfiles.ProfileError.dockUnreadable.localizedDescription
        }
    }

    private func export(_ p: DockProfile) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(p.name).json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try profiles.export(p.id, to: url) } catch { self.error = error.localizedDescription }
    }

    private func importProfile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { selection = try profiles.importProfiles(from: url).first?.id } catch { self.error = error.localizedDescription }
    }

    private func exportAll() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = String(localized: "Dock Profiles.json")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try profiles.exportAll(to: url) } catch { self.error = error.localizedDescription }
    }

    /// The system share sheet (AirDrop, Mail, Messages) with the profile as a JSON file.
    private func share(_ p: DockProfile) {
        do {
            let file = try profiles.shareFile(p.id)
            guard let view = NSApp.keyWindow?.contentView else { return }
            let mouse = view.convert(view.window?.mouseLocationOutsideOfEventStream ?? .zero, from: nil)
            NSSharingServicePicker(items: [file]).show(relativeTo: NSRect(origin: mouse, size: .zero), of: view, preferredEdge: .minY)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct ProfileListRow: View {
    let profile: DockProfile
    private var store: LibraryStore { LibraryStore.shared }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(profile.name).lineLimit(1)
                Text("\(profile.tiles.count) tiles").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if profile.isPrivate {
                Image(systemName: "lock.fill").foregroundStyle(.secondary).help(Text("Private"))
                    .accessibilityLabel(Text("Private"))
            }
            if !profile.spaces.isEmpty {
                Image(systemName: "rectangle.on.rectangle").foregroundStyle(.secondary).help(Text("Linked to a Space or display"))
                    .accessibilityLabel(Text("Linked to a Space or display"))
            }
            if store.settings.startupProfileID == profile.id {
                Image(systemName: "power").foregroundStyle(.secondary).help(Text("Startup profile"))
                    .accessibilityLabel(Text("Startup profile"))
            }
            if store.settings.lastAppliedProfileID == profile.id {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint)
                    .accessibilityLabel(Text("Active"))
            }
        }
    }
}

/// Settings that apply to every profile switch.
private struct GlobalProfileOptions: View {
    @State private var showCommands = false
    private var store: LibraryStore { LibraryStore.shared }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Skip if already active", isOn: setting(\.skipIfActive))
            Toggle("Save Dock into active profile before switching", isOn: setting(\.autoSaveOnSwitch))
            Toggle("Ask for a note when switching away", isOn: setting(\.askLastContext))
            Toggle("Switch with Spaces and displays", isOn: setting(\.profilePerSpace))
                .help(Text("Applies the profile linked to the Space or display you move to."))
            Button("Commands…") { showCommands = true }
                .padding(.top, 4)
                .help(Text("Siri, Shortcuts, URL and command line commands"))
        }
        .toggleStyle(.checkbox)
        .font(.caption)
        .sheet(isPresented: $showCommands) { AutomationCommandsView() }
    }

    private func setting(_ key: WritableKeyPath<AppSettings, Bool>) -> Binding<Bool> {
        Binding(get: { store.settings[keyPath: key] }, set: { store.settings[keyPath: key] = $0 })
    }
}

// MARK: - Editor

private struct ProfileEditor: View {
    let profileID: UUID
    @State private var newLink = ""

    private var store: LibraryStore { LibraryStore.shared }
    private var profiles: DockProfiles { DockProfiles.shared }

    var body: some View {
        if let p = profiles.profile(profileID) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header(p)
                    if let r = profiles.lastResult, r.profileName == p.name, !r.missing.isEmpty || r.status == .skippedActive {
                        ResultNote(result: r)
                    }
                    TileSection(title: String(localized: "Apps"), profileID: profileID, isOther: false)
                    TileSection(title: String(localized: "Folders, Files and Links"), profileID: profileID, isOther: true)
                    addBar
                    Divider()
                    ProfileOptions(profile: p)
                }
                .padding(20)
            }
        }
    }

    private func header(_ p: DockProfile) -> some View {
        HStack {
            TextField("Profile Name", text: Binding(
                get: { p.name },
                set: { name in profiles.updateProfile(profileID) { $0.name = name } }))
                .textFieldStyle(.plain)
                .font(.title2.weight(.semibold))
                .accessibilityLabel(Text("Profile name"))
            Spacer()
            Button("Save Current Dock Here") { profiles.saveCurrent(into: profileID) }
                .help(Text("Replace this profile's tiles with what the Dock shows now."))
            Button("Apply") { profiles.apply(profileID, skipIfActive: false) }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(profiles.isApplying)
        }
    }

    private var addBar: some View {
        HStack {
            Menu {
                Button("App…") { addFiles(apps: true) }
                Button("File or Folder…") { addFiles(apps: false) }
                Divider()
                Button("Spacer") { append(DockTile(kind: .spacer)) }
                Button("Small Spacer") { append(DockTile(kind: .smallSpacer)) }
                let spacers = store.library.spacers.filter { $0.launcherPath != nil }
                if !spacers.isEmpty {
                    Menu("Custom Spacer") {
                        ForEach(spacers) { s in
                            Button(s.text.isEmpty ? String(localized: "Spacer") : s.text) {
                                append(DockTile(kind: .customSpacer, url: URL(fileURLWithPath: s.launcherPath!, isDirectory: true),
                                                bundleID: LauncherTarget.spacer(s.id).bundleID, label: s.text))
                            }
                        }
                    }
                }
            } label: {
                Label("Add", systemImage: "plus")
            }
            .fixedSize()
            .accessibilityLabel(Text("Add a tile"))
            Spacer()
            TextField("https://", text: $newLink)
                .frame(width: 220)
                .onSubmit(addLink)
                .accessibilityLabel(Text("Link address"))
            Button("Add Link", action: addLink).disabled(URL(string: newLink)?.scheme == nil)
        }
    }

    private func append(_ tile: DockTile) {
        guard let p = profiles.profile(profileID) else { return }
        var t = tile
        t.isOther = !(tile.kind == .app || tile.kind.isSpacer || tile.kind == .customSpacer)
        profiles.setTiles(p.tiles + [t], of: profileID)
    }

    private func addFiles(apps: Bool) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = !apps
        if apps {
            panel.allowedContentTypes = [.application]
            panel.directoryURL = URL(fileURLWithPath: "/Applications")
        }
        guard panel.runModal() == .OK else { return }
        for url in panel.urls { append(ProfileTiles.tile(for: url)) }
    }

    private func addLink() {
        guard let url = URL(string: newLink.trimmingCharacters(in: .whitespaces)), url.scheme != nil else { return }
        append(DockTile(kind: .url, url: url, label: DockPlist.defaultLabel(for: url)))
        newLink = ""
    }
}

/// Tile helpers shared by the editor's buttons and Finder drops.
enum ProfileTiles {
    static func tile(for url: URL) -> DockTile {
        guard url.isFileURL else { return DockTile(kind: .url, url: url, label: DockPlist.defaultLabel(for: url), isOther: true) }
        if url.pathExtension == "app" {
            return DockTile(kind: .app, url: url, bundleID: Bundle(url: url)?.bundleIdentifier, label: DockPlist.defaultLabel(for: url))
        }
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        var t = DockTile(kind: isDir.boolValue ? .folder : .file, url: url, label: url.lastPathComponent, isOther: true)
        if isDir.boolValue { t.folder = StackSettings() }
        return t
    }

    static func icon(for tile: DockTile) -> NSImage {
        switch tile.kind {
        case .spacer, .smallSpacer, .flexSpacer:
            return NSImage(systemSymbolName: "space", accessibilityDescription: nil) ?? NSImage()
        case .url:
            return NSImage(systemSymbolName: "globe", accessibilityDescription: nil) ?? NSImage()
        default:
            guard let path = tile.url?.path, FileManager.default.fileExists(atPath: path) else {
                return NSImage(systemSymbolName: "questionmark.square.dashed", accessibilityDescription: nil) ?? NSImage()
            }
            return NSWorkspace.shared.icon(forFile: path)
        }
    }

    static func title(for tile: DockTile) -> String {
        switch tile.kind {
        case .spacer: String(localized: "Spacer")
        case .smallSpacer: String(localized: "Small Spacer")
        case .flexSpacer: String(localized: "Flexible Spacer")
        default: tile.label ?? tile.url.map(DockPlist.defaultLabel(for:)) ?? ""
        }
    }
}

/// One section of tiles (left or right of the Dock divider), reorderable, accepts Finder drops.
private struct TileSection: View {
    let title: String
    let profileID: UUID
    let isOther: Bool
    @State private var dropTargeted = false

    private var profiles: DockProfiles { DockProfiles.shared }

    var body: some View {
        let all = profiles.profile(profileID)?.tiles ?? []
        let tiles = all.filter { $0.isOther == isOther }
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            if tiles.isEmpty {
                Text("Drop apps, files or folders here.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 44)
            } else {
                List {
                    ForEach(tiles) { tile in
                        ProfileTileRow(tile: tile, profileID: profileID)
                    }
                    .onMove { move($0, $1) }
                    .onDelete { remove($0) }
                }
                .frame(height: min(tiles.map(ProfileTileRow.height(for:)).reduce(12, +), 420))
                .scrollContentBackground(.hidden)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10).fill(dropTargeted ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.06)))
        .dropDestination(for: URL.self) { urls, _ in
            var tiles = profiles.profile(profileID)?.tiles ?? []
            for url in urls {
                var t = ProfileTiles.tile(for: url)
                t.isOther = isOther ? true : t.kind != .app
                tiles.append(t)
            }
            profiles.setTiles(tiles, of: profileID)
            return true
        } isTargeted: { dropTargeted = $0 }
    }

    /// Moves inside this section and keeps the other section as it is.
    private func move(_ source: IndexSet, _ destination: Int) {
        guard let p = profiles.profile(profileID) else { return }
        var mine = p.tiles.filter { $0.isOther == isOther }
        mine.move(fromOffsets: source, toOffset: destination)
        let other = p.tiles.filter { $0.isOther != isOther }
        profiles.setTiles(isOther ? other + mine : mine + other, of: profileID)
    }

    private func remove(_ offsets: IndexSet) {
        guard let p = profiles.profile(profileID) else { return }
        let ids = Set(offsets.map { p.tiles.filter { $0.isOther == isOther }[$0].id })
        profiles.setTiles(p.tiles.filter { !ids.contains($0.id) }, of: profileID)
    }
}

private struct ResultNote: View {
    let result: ProfileApplyResult

    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: "info.circle").accessibilityHidden(true)
            if result.status == .skippedActive {
                Text("This profile is already active.")
            } else {
                Text("Applied. Left out because they are missing: \(result.missing.joined(separator: ", "))")
            }
        }
        .font(.callout)
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(.yellow.opacity(0.15)))
    }
}

// MARK: - Options

private struct ProfileOptions: View {
    let profile: DockProfile
    @State private var newKeep = ""

    private var store: LibraryStore { LibraryStore.shared }
    private var profiles: DockProfiles { DockProfiles.shared }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("When Applied").font(.headline)
            Toggle("Quit apps that are not in this profile", isOn: bind(\.quitOthers))
            if profile.quitOthers {
                keepRunningEditor.padding(.leading, 20)
            }
            Toggle("Never quit apps for this profile", isOn: bind(\.keepAppsOpen))
            Toggle("Open the profile's apps in the background", isOn: bind(\.launchApps))
            openAfterEditor
            Toggle("Apply at startup", isOn: Binding(
                get: { store.settings.startupProfileID == profile.id },
                set: { on in store.settings.startupProfileID = on ? profile.id : nil }))
            HStack {
                Text("Hotkey")
                HotkeyRecorder(hotkey: Binding(
                    get: { profile.hotkey },
                    set: { h in profiles.updateProfile(profile.id) { $0.hotkey = h } }),
                    target: .profile(profile.id))
            }
            Divider()
            ProfileMoreOptions(profile: profile)
        }
        .toggleStyle(.checkbox)
    }

    private func bind(_ key: WritableKeyPath<DockProfile, Bool>) -> Binding<Bool> {
        Binding(get: { profile[keyPath: key] }, set: { v in profiles.updateProfile(profile.id) { $0[keyPath: key] = v } })
    }

    private var keepRunningEditor: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Keep running").font(.caption).foregroundStyle(.secondary)
            ForEach(profile.keepRunning, id: \.self) { bid in
                HStack {
                    Text(appName(bid))
                    Spacer()
                    Button { profiles.updateProfile(profile.id) { $0.keepRunning.removeAll { $0 == bid } } } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(Text("Remove \(appName(bid))"))
                }
            }
            Menu("Add Running App") {
                let running = NSWorkspace.shared.runningApplications
                    .filter { $0.activationPolicy == .regular && !profile.keepRunning.contains($0.bundleIdentifier ?? "") }
                ForEach(running, id: \.processIdentifier) { app in
                    Button(app.localizedName ?? app.bundleIdentifier ?? "") {
                        if let bid = app.bundleIdentifier { profiles.updateProfile(profile.id) { $0.keepRunning.append(bid) } }
                    }
                }
            }
            .fixedSize()
        }
    }

    private var openAfterEditor: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Open after applying").font(.caption).foregroundStyle(.secondary)
            ForEach(profile.openAfterApply, id: \.self) { url in
                HStack {
                    Text(url.isFileURL ? url.lastPathComponent : url.absoluteString).lineLimit(1)
                    Spacer()
                    Button { profiles.updateProfile(profile.id) { $0.openAfterApply.removeAll { $0 == url } } } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(Text("Remove"))
                }
            }
            HStack {
                Button("Add File or Folder…") {
                    let panel = NSOpenPanel()
                    panel.canChooseDirectories = true
                    panel.allowsMultipleSelection = true
                    guard panel.runModal() == .OK else { return }
                    let urls = panel.urls
                    profiles.updateProfile(profile.id) { $0.openAfterApply += urls }
                }
                TextField("https://", text: $newKeep)
                    .frame(width: 180)
                    .accessibilityLabel(Text("Link to open"))
                Button("Add Link") {
                    guard let url = URL(string: newKeep), url.scheme != nil else { return }
                    profiles.updateProfile(profile.id) { $0.openAfterApply.append(url) }
                    newKeep = ""
                }
                .disabled(URL(string: newKeep)?.scheme == nil)
            }
        }
    }

    private func appName(_ bundleID: String) -> String {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID).map(DockPlist.defaultLabel(for:)) ?? bundleID
    }
}
