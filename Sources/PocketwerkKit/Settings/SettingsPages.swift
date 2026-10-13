import AppKit
import SwiftUI

/// Where Pocketwerk shows up: menu bar, Dock, or both.
enum AppPresence: String, CaseIterable, Hashable {
    case menuBarOnly, menuBarAndDock, dockOnly

    init(_ s: AppSettings) {
        switch (s.showMenuBarIcon, s.showMainDockIcon) {
        case (true, false): self = .menuBarOnly
        case (false, true): self = .dockOnly
        default: self = .menuBarAndDock
        }
    }

    func apply(to s: inout AppSettings) {
        s.showMenuBarIcon = self != .dockOnly
        s.showMainDockIcon = self != .menuBarOnly
    }
}

/// Binding to one setting. Settings changes are not undoable.
@MainActor
func settingBinding<T>(_ path: WritableKeyPath<AppSettings, T>) -> Binding<T> {
    Binding(get: { LibraryStore.shared.settings[keyPath: path] },
            set: { v in LibraryStore.shared.settings[keyPath: path] = v })
}

struct SettingsPageView: View {
    let page: SettingsPage

    var body: some View {
        Group {
            switch page {
            case .general: GeneralSettings()
            case .popup: PopupSettings()
            case .hotkeys: HotkeySettings()
            case .backup: BackupSettings()
            case .diagnostics: DiagnosticsSettings()
            case .updates: UpdateSettings()
            case .about: AboutView()
            }
        }
        .formStyle(.grouped)
        .navigationTitle(Text(page.title))
    }
}

// MARK: - General

struct GeneralSettings: View {
    private var store: LibraryStore { LibraryStore.shared }
    @State private var needsApproval = LoginItem.needsApproval

    var body: some View {
        Form {
            Section("App") {
                Picker("Show Pocketwerk in", selection: Binding(get: { AppPresence(store.settings) },
                                                                set: { p in var s = store.settings; p.apply(to: &s); store.settings = s })) {
                    Text("Menu bar only").tag(AppPresence.menuBarOnly)
                    Text("Menu bar and Dock").tag(AppPresence.menuBarAndDock)
                    Text("Dock only").tag(AppPresence.dockOnly)
                }
                Toggle("Launch at login", isOn: Binding(get: { store.settings.launchAtLogin }, set: { on in
                    store.settings.launchAtLogin = on
                    LoginItem.sync(wanted: on)
                    needsApproval = LoginItem.needsApproval
                }))
                if needsApproval && store.settings.launchAtLogin {
                    HStack {
                        Text("macOS asks you to allow Pocketwerk in Login Items.").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("Open Login Items") { LoginItem.openSystemSettings() }.controlSize(.small)
                    }
                }
            }
            Section("Windows") {
                Toggle("Open this window when Pocketwerk starts", isOn: settingBinding(\.showWindowOnLaunch))
                Text("Starts from links, shortcuts and Dock icons stay without a window.")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("Seasonal touches", isOn: settingBinding(\.seasonalTouches))
            }
            Section("Apple Intelligence") {
                Toggle("Assistant in the group editor", isOn: settingBinding(\.assistantEnabled))
                Toggle("App suggestions in the App Drawer", isOn: settingBinding(\.suggestionsEnabled))
                Text(AIStatus.current.message).font(.caption).foregroundStyle(.secondary)
            }
            Section("Opening") {
                Toggle("Close the popup after opening an item", isOn: settingBinding(\.closeAfterOpen))
                Toggle("Ask before Open All", isOn: settingBinding(\.confirmBeforeOpenAll))
                LabeledContent("Pause between apps in Open All") {
                    HStack {
                        Slider(value: settingBinding(\.openAllDelay), in: 0...2, step: 0.25)
                            .frame(width: 160)
                            .accessibilityLabel(Text("Pause between apps"))
                        Text(store.settings.openAllDelay.formatted(.number.precision(.fractionLength(2))) + " s")
                            .monospacedDigit().foregroundStyle(.secondary).frame(width: 48, alignment: .trailing)
                    }
                }
                Picker("Animation speed", selection: settingBinding(\.animationSpeed)) {
                    Text("Slow").tag(AnimationSpeed.slow)
                    Text("Medium").tag(AnimationSpeed.medium)
                    Text("Fast").tag(AnimationSpeed.fast)
                    Text("Off").tag(AnimationSpeed.off)
                }
            }
            Section("Missing Items") {
                Toggle("Remove items whose app or file is gone", isOn: settingBinding(\.removeMissingItems))
                let count = LibraryHealth.shared.missing.count
                LabeledContent("Missing now") {
                    HStack {
                        Text("\(count)").monospacedDigit()
                        Button("Remove") { LibraryHealth.shared.removeMissing() }.disabled(count == 0)
                    }
                }
            }
            Section("App Drawer") {
                Toggle("Hide menu bar apps", isOn: settingBinding(\.hideAgentApps))
                Text(store.settings.appSearchPaths.joined(separator: ", "))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .onAppear { needsApproval = LoginItem.needsApproval }
    }
}

// MARK: - Popup

struct PopupSettings: View {
    private var store: LibraryStore { LibraryStore.shared }

    var body: some View {
        Form {
            Section("Placement") {
                placementPicker("When clicking a Dock icon", \.placement)
                placementPicker("When using a shortcut", \.hotkeyPlacement)
                LabeledContent("Distance from the Dock") {
                    HStack {
                        Slider(value: settingBinding(\.popoverOffset), in: 0...40, step: 1).frame(width: 160)
                            .accessibilityLabel(Text("Distance from the Dock"))
                        Text("\(Int(store.settings.popoverOffset)) pt").monospacedDigit().foregroundStyle(.secondary)
                            .frame(width: 44, alignment: .trailing)
                    }
                }
            }
            Section("Several Groups") {
                // RELEASE-1.0: the sidebar navigation ships in 1.1; the picker returns with it.
                if PopupController.supportsSidebar {
                    Picker("Navigation", selection: settingBinding(\.popupNavigation)) {
                        Text("Carousel (swipe between groups)").tag(PopupNavigation.carousel)
                        Text("Sidebar (list of groups)").tag(PopupNavigation.sidebar)
                    }
                }
                Toggle("Keep the size while swiping", isOn: settingBinding(\.lockSizeWhileSwiping))
                Toggle("Show the Most Used group", isOn: settingBinding(\.showMostUsed))
            }
            Section("Menu Bar") {
                Picker("Clicking the menu bar icon shows", selection: settingBinding(\.menuBarClick)) {
                    Text("All groups").tag(MenuBarClick.carousel)
                    Text("A menu").tag(MenuBarClick.menu)
                }
                Picker("Icon", selection: settingBinding(\.menuBarIconStyle)) {
                    ForEach(MenuBarIcon.allCases, id: \.self) { style in
                        Label { Text(style.title) } icon: { Image(nsImage: style.image(groups: store.library.carouselGroups)) }
                            .tag(style.rawValue)
                    }
                }
                Text("Right-click the icon to always get the menu.").font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Picker("Hot corner", selection: settingBinding(\.hotCorner)) {
                    Text(HotCornerGeometry.title(nil)).tag(Int?.none)
                    ForEach(0..<4, id: \.self) { c in Text(HotCornerGeometry.title(c)).tag(Int?.some(c)) }
                }
            } header: {
                Text("Hot Corner")
            } footer: {
                Text("Rest the pointer in this corner to show all groups. Pick a corner that macOS does not use for its own hot corners.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func placementPicker(_ title: LocalizedStringKey, _ path: WritableKeyPath<AppSettings, PopupPlacement>) -> some View {
        Picker(title, selection: settingBinding(path)) {
            Text("Above the Dock icon").tag(PopupPlacement.aboveTile)
            Text("Center of the Dock").tag(PopupPlacement.dockCenter)
            Text("At the pointer").tag(PopupPlacement.mouse)
            Text("Center of the screen").tag(PopupPlacement.center)
        }
    }
}

// MARK: - Hotkeys

struct HotkeySettings: View {
    private var store: LibraryStore { LibraryStore.shared }
    private var center: HotkeyCenter { HotkeyCenter.shared }

    var body: some View {
        let lib = store.library
        let defaults = Dictionary(HotkeyPlan.defaultGroupBindings(lib).compactMap { b -> (UUID, Hotkey)? in
            if case .group(let id) = b.target { return (id, b.hotkey) }
            return nil
        }, uniquingKeysWith: { a, _ in a })
        let conflicts = HotkeyPlan.conflicts(lib)
        Form {
            if !conflicts.isEmpty || !center.failed.isEmpty {
                Section {
                    ForEach(Array(conflicts.enumerated()), id: \.offset) { _, c in
                        Label("\(HotkeyCenter.describe(c.hotkey)) is used by \(c.targets.map { HotkeyPlan.name(of: $0, in: lib) }.joined(separator: " and ")). Only the first one works.",
                              systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                    ForEach(Array(center.failed), id: \.self) { t in
                        Label("\(HotkeyPlan.name(of: t, in: lib)): another app already uses this shortcut.",
                              systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            Section {
                row(Text("Show all groups"), hotkey: settingBinding(\.mainHotkey), target: .main)
                if !lib.profiles.isEmpty {
                    row(Text("Next Dock profile"), hotkey: settingBinding(\.nextProfileHotkey), target: .nextProfile)
                    row(Text("Save Dock into active profile"), hotkey: settingBinding(\.saveToLastHotkey), target: .saveToActiveProfile)
                }
                Toggle("⌥⇧1 to ⌥⇧9 open the first nine groups", isOn: settingBinding(\.numberHotkeys))
            } footer: {
                Text("Shortcuts work everywhere, also in full screen apps. No extra permission is needed. Use the … button to require a double press or a follow-up key.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                LabeledContent("Leader key") {
                    HotkeyRecorder(hotkey: settingBinding(\.leaderHotkey), target: nil, allowsAdvanced: false)
                }
                LabeledContent("Wait for the letter") {
                    HStack {
                        Slider(value: settingBinding(\.leaderTimeout), in: 0.5...4, step: 0.25).frame(width: 160)
                            .accessibilityLabel(Text("Wait for the letter"))
                        Text(store.settings.leaderTimeout.formatted(.number.precision(.fractionLength(2))) + " s")
                            .monospacedDigit().foregroundStyle(.secondary).frame(width: 48, alignment: .trailing)
                    }
                }
            } header: {
                Text("Leader Key")
            } footer: {
                Text("Press the leader key, then the letter of a group or profile. A small list shows the letters while Pocketwerk waits.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Groups") {
                ForEach(lib.orderedGroups) { g in
                    LabeledContent {
                        HStack(spacing: 8) {
                            LeaderLetterField(letter: groupLetter(g.id))
                            HotkeyRecorder(hotkey: groupBinding(g.id), target: .group(g.id),
                                           placeholder: defaults[g.id].map(HotkeyCenter.describe))
                        }
                    } label: {
                        Text(verbatim: [g.emoji, g.name].compactMap { $0 }.joined(separator: " "))
                    }
                }
            }
            if !lib.slots.isEmpty {
                Section("Dock Icons") {
                    ForEach(lib.slots) { s in
                        row(Text(verbatim: s.name), hotkey: slotBinding(s.id), target: .slot(s.id))
                    }
                }
            }
            if !lib.profiles.isEmpty {
                Section("Dock Profiles") {
                    ForEach(lib.profiles) { p in
                        LabeledContent {
                            HStack(spacing: 8) {
                                LeaderLetterField(letter: profileLetter(p.id))
                                HotkeyRecorder(hotkey: profileBinding(p.id), target: .profile(p.id))
                            }
                        } label: {
                            Text(verbatim: p.name)
                        }
                    }
                }
            }
        }
    }

    private func row(_ title: Text, hotkey: Binding<Hotkey?>, target: HotkeyTarget, placeholder: String? = nil) -> some View {
        LabeledContent {
            HotkeyRecorder(hotkey: hotkey, target: target, placeholder: placeholder)
        } label: {
            title
        }
    }

    private func groupBinding(_ id: UUID) -> Binding<Hotkey?> {
        Binding(get: { store.group(id)?.hotkey }, set: { v in store.updateGroup(id) { $0.hotkey = v } })
    }

    private func groupLetter(_ id: UUID) -> Binding<String?> {
        Binding(get: { store.group(id)?.leaderKey }, set: { v in store.updateGroup(id) { $0.leaderKey = v } })
    }

    private func profileLetter(_ id: UUID) -> Binding<String?> {
        Binding(get: { store.library.profiles.first { $0.id == id }?.leaderKey },
                set: { v in store.mutate { lib in
                    if let i = lib.profiles.firstIndex(where: { $0.id == id }) { lib.profiles[i].leaderKey = v }
                } })
    }

    private func slotBinding(_ id: UUID) -> Binding<Hotkey?> {
        Binding(get: { store.slot(id)?.hotkey }, set: { v in store.updateSlot(id) { $0.hotkey = v } })
    }

    private func profileBinding(_ id: UUID) -> Binding<Hotkey?> {
        Binding(get: { store.library.profiles.first { $0.id == id }?.hotkey },
                set: { v in store.mutate { lib in
                    if let i = lib.profiles.firstIndex(where: { $0.id == id }) { lib.profiles[i].hotkey = v }
                } })
    }
}

/// One letter used after the leader key. Empty = none.
struct LeaderLetterField: View {
    @Binding var letter: String?
    @State private var text = ""

    var body: some View {
        TextField("", text: $text, prompt: Text("–"))
            .frame(width: 30)
            .multilineTextAlignment(.center)
            .onAppear { text = letter ?? "" }
            .onChange(of: letter) { _, new in if (new ?? "") != text { text = new ?? "" } }
            .onChange(of: text) { _, new in
                let one = new.trimmingCharacters(in: .whitespaces).suffix(1).uppercased()
                if one != new { text = one; return }
                letter = one.isEmpty ? nil : one
            }
            .help("Letter after the leader key")
            .accessibilityLabel(Text("Leader letter"))
    }
}

// MARK: - Backup

struct BackupSettings: View {
    private var store: LibraryStore { LibraryStore.shared }
    @State private var pending: Library?
    @State private var summary: ImportSummary?
    @State private var done: String?

    var body: some View {
        Form {
            Section {
                LabeledContent("Export") {
                    Button("Export Backup…") { BackupService.exportWithPanel() }
                }
                LabeledContent("Import") {
                    Button("Import Backup…") {
                        if let lib = BackupService.pickImportFile() {
                            pending = lib
                            summary = BackupService.summary(for: lib)
                        }
                    }
                }
                if let done { Text(done).font(.caption).foregroundStyle(.secondary) }
            } footer: {
                Text("One readable JSON file with groups, Dock icons, profiles, shortcuts and settings.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Data") {
                LabeledContent("Library") {
                    Text((store.fileURL.path as NSString).abbreviatingWithTildeInPath)
                        .font(.caption).foregroundStyle(.secondary).textSelection(.enabled).lineLimit(2)
                }
                Button("Show in Finder") { BackupService.showDataFolder() }
            }
            Section {
                if let path = store.settings.syncFolderPath {
                    LabeledContent("Extra copy in") {
                        Text((path as NSString).abbreviatingWithTildeInPath).font(.caption).foregroundStyle(.secondary)
                    }
                    HStack {
                        Button("Change…") { BackupService.chooseSyncFolder() }
                        Button("Turn Off") { store.settings.syncFolderPath = nil }
                    }
                } else {
                    Button("Choose Folder…") { BackupService.chooseSyncFolder() }
                }
            } header: {
                Text("Copy to Another Folder")
            } footer: {
                Text("Pocketwerk writes a copy of the library there after every change, for example to iCloud Drive. It never reads it back on its own.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .sheet(item: Binding(get: { summary.map(SummaryBox.init) }, set: { if $0 == nil { summary = nil; pending = nil } })) { box in
            ImportReviewView(summary: box.summary) { mode in
                if let pending { BackupService.apply(pending, mode: mode) }
                done = mode == .merge
                    ? String(localized: "Merged. Undo with ⌘Z.")
                    : String(localized: "Library replaced. Undo with ⌘Z.")
                summary = nil
                pending = nil
            } cancel: {
                summary = nil
                pending = nil
            }
        }
    }

    private struct SummaryBox: Identifiable {
        let summary: ImportSummary
        let id = UUID()
    }
}

/// Conflict summary before importing, with Merge or Replace.
struct ImportReviewView: View {
    let summary: ImportSummary
    let apply: (BackupService.Mode) -> Void
    let cancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Import Backup").font(.headline)
            Text("The file has \(summary.totalGroups) groups with \(summary.totalItems) items.")
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    list("Merge adds these groups", summary.newGroups, color: .green)
                    list("Merge skips these groups, you already have them", summary.existingGroups, color: .orange)
                    list("New Dock profiles", summary.newProfiles, color: .green)
                    list("Dock profiles you already have", summary.existingProfiles, color: .orange)
                    if summary.newThemes > 0 { Text("\(summary.newThemes) new looks.") }
                    list("Apps not installed on this Mac", summary.missingApps, color: .red)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 260)
            Text("Merge only adds and never deletes. Replace swaps your groups, Dock icons and settings for the backup. Both can be undone with ⌘Z.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Cancel", action: cancel).keyboardShortcut(.cancelAction)
                Spacer()
                Button("Replace All") { apply(.replace) }
                Button("Merge") { apply(.merge) }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 460)
    }

    @ViewBuilder private func list(_ title: LocalizedStringKey, _ names: [String], color: Color) -> some View {
        if !names.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                ForEach(names.prefix(30), id: \.self) { n in
                    HStack(spacing: 6) {
                        Circle().fill(color).frame(width: 6, height: 6).accessibilityHidden(true)
                        Text(n).font(.callout)
                    }
                }
                if names.count > 30 { Text("and \(names.count - 30) more").font(.caption).foregroundStyle(.secondary) }
            }
        }
    }
}

// MARK: - Diagnostics

struct DiagnosticsSettings: View {
    private var store: LibraryStore { LibraryStore.shared }

    var body: some View {
        let lib = store.library
        Form {
            Section {
                LabeledContent("Groups") { Text("\(lib.groups.count)").monospacedDigit() }
                LabeledContent("Items") { Text("\(lib.groups.reduce(0) { $0 + $1.items.count })").monospacedDigit() }
                LabeledContent("Dock icons") { Text("\(lib.slots.count)").monospacedDigit() }
                LabeledContent("Profiles") { Text("\(lib.profiles.count)").monospacedDigit() }
                LabeledContent("Missing items") { Text("\(LibraryHealth.shared.missing.count)").monospacedDigit() }
                LabeledContent("Active shortcuts") { Text("\(HotkeyCenter.shared.active.count)").monospacedDigit() }
            }
            Section {
                Button("Export Diagnostics…") { Diagnostics.exportWithPanel() }
                Button("Show Data Folder") { BackupService.showDataFolder() }
            } footer: {
                Text("Saves the last five hours of Pocketwerk's own log and a short summary as a text file. Nothing is sent. Look at the file before you share it.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Updates

struct UpdateSettings: View {
    private var store: LibraryStore { LibraryStore.shared }
    private var checker: UpdateChecker { UpdateChecker.shared }

    var body: some View {
        Form {
            Section {
                Toggle("Check for updates once a day", isOn: settingBinding(\.checkForUpdates))
                LabeledContent("Installed version") { Text(UpdateChecker.currentVersion ?? "–") }
                LabeledContent("Last check") {
                    Text(store.settings.lastUpdateCheck?.formatted(date: .abbreviated, time: .shortened)
                         ?? String(localized: "Never"))
                }
                HStack {
                    Button("Check Now") { Task { await checker.check() } }.disabled(checker.isChecking)
                    if checker.isChecking { ProgressView().controlSize(.small) }
                    if let result = checker.lastResult { Text(result).foregroundStyle(.secondary) }
                }
            } footer: {
                Text("The check asks GitHub for the latest release. Nothing else is sent.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let release = checker.available {
                Section("Available") {
                    LabeledContent("Version") { Text(release.version) }
                    HStack {
                        Button("Open Download Page") { checker.openAvailable() }
                        Button("Skip This Version") { checker.skipAvailable() }
                    }
                }
            }
            if let skipped = store.settings.skippedVersion {
                Section {
                    LabeledContent("Skipped version") {
                        HStack {
                            Text(skipped)
                            Button("Reset") { store.settings.skippedVersion = nil }.controlSize(.small)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - About

struct AboutView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 96, height: 96)
                .accessibilityHidden(true)
            Text("Pocketwerk").font(.largeTitle.weight(.semibold))
            Text("Version \(UpdateChecker.currentVersion ?? "dev")").foregroundStyle(.secondary)
            Text("Groups of apps, files and links behind your Dock icons.")
                .multilineTextAlignment(.center)
            Link("Pocketwerk on GitHub", destination: UpdateChecker.project)
            Text("Free and open source under the MIT license.").font(.callout).foregroundStyle(.secondary)
            Text("No analytics, no account, no server. Your data stays on this Mac.")
                .font(.callout).foregroundStyle(.secondary)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(alignment: .top) {
            SeasonalSnow()
                .frame(height: 220)
                .background(SeasonalSnow.isSeason() && LibraryStore.shared.settings.seasonalTouches
                            ? AnyShapeStyle(LinearGradient(colors: [.blue.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom))
                            : AnyShapeStyle(.clear))
        }
    }
}
