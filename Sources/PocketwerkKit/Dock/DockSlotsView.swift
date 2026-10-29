import AppKit
import SwiftUI

/// Dock slots and custom spacers: which groups each tile shows, its launcher, and its place in the Dock.
/// The main window embeds this. `onEditIcon` opens the icon editor for a slot (icon override).
struct DockSlotsView: View {
    var onEditIcon: ((UUID) -> Void)? = nil

    private var store: LibraryStore { LibraryStore.shared }
    private var dock: DockManager { DockManager.shared }

    var body: some View {
        VStack(spacing: 0) {
            if let failure = dock.lastFailure {
                FailureBanner(failure: failure) { dock.lastFailure = nil }
            }
            Form {
                Section {
                    ForEach(store.library.slots) { slot in
                        SlotRow(slot: slot, onEditIcon: onEditIcon)
                    }
                } header: {
                    Text("Dock Slots")
                } footer: {
                    if store.library.slots.isEmpty {
                        Text("Add a slot to give a group its own icon in the Dock.").foregroundStyle(.secondary)
                    } else {
                        Text("Drop files on a Dock icon to add them. Hold a drag over the icon to open its popup and drop inside.")
                            .foregroundStyle(.secondary)
                    }
                }
                Section {
                    ForEach(store.library.spacers) { spacer in
                        SpacerRow(spacer: spacer)
                    }
                } header: {
                    Text("Spacers")
                } footer: {
                    Text("A spacer is a Dock tile that shows only text or an image, to label a part of your Dock.")
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            Divider()
            HStack {
                Menu {
                    ForEach(store.library.groups) { g in
                        Button(g.name) { store.addSlot(name: g.name, groupIDs: [g.id]) }
                    }
                } label: {
                    Label("Add Slot", systemImage: "plus")
                }
                .fixedSize()
                .disabled(store.library.groups.isEmpty)
                .accessibilityLabel(Text("Add a Dock slot for a group"))
                Button {
                    store.addSpacer(text: String(localized: "Label"))
                } label: {
                    Label("Add Spacer", systemImage: "rectangle.dashed")
                }
                Spacer()
                Toggle("Live main Dock icon", isOn: Binding(
                    get: { store.settings.liveMainDockIcon },
                    set: { store.settings.liveMainDockIcon = $0 }))
                    .toggleStyle(.checkbox)
                    .help(Text("Pocketwerk's own Dock icon shows the first group as a mini grid."))
                Button("Reload Dock") { dock.reloadDock() }
                    .help(Text("Restart the Dock once so pinned tiles show their new icons."))
            }
            .padding(10)
        }
    }
}

// MARK: - Slot row

private struct SlotRow: View {
    let slot: DockSlot
    var onEditIcon: ((UUID) -> Void)?
    @State private var editingGroups = false

    private var store: LibraryStore { LibraryStore.shared }
    private var dock: DockManager { DockManager.shared }

    var body: some View {
        let installed = slot.launcherPath.map { FileManager.default.fileExists(atPath: $0) } ?? false
        let inDock = installed && dock.isInDock(slotID: slot.id)
        HStack(spacing: 10) {
            Image(nsImage: IconRenderer.slotIcon(slot, library: store.library, size: 64))
                .resizable()
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                TextField("Name", text: Binding(
                    get: { slot.name },
                    set: { name in store.updateSlot(slot.id) { $0.name = name } }))
                    .textFieldStyle(.plain)
                    .font(.headline)
                    .labelsHidden()
                    .accessibilityLabel(Text("Slot name"))
                Text(subtitle(installed: installed, inDock: inDock))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if dock.busy.contains(slot.id) {
                ProgressView().controlSize(.small)
            }
            if inDock {
                Button("Remove from Dock") { dock.removeFromDock(slotID: slot.id) }
            } else {
                Button("Add to Dock") { dock.addToDock(slotID: slot.id) }
                    .disabled(slot.groupIDs.isEmpty)
            }
            Menu {
                Button("Choose Groups…") { editingGroups = true }
                // A grouped form has no drag to reorder, so the order lives here.
                let index = store.library.slots.firstIndex { $0.id == slot.id } ?? 0
                Button("Move Up") { store.moveSlots(from: [index], to: index - 1) }
                    .disabled(index == 0)
                Button("Move Down") { store.moveSlots(from: [index], to: index + 2) }
                    .disabled(index >= store.library.slots.count - 1)
                Divider()
                Button(installed ? "Update Launcher" : "Install Launcher") { dock.installInBackground(.slot(slot.id)) }
                if installed {
                    Button("Uninstall Launcher") { dock.removeLauncher(for: slot.id) }
                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: slot.launcherPath!)])
                    }
                }
                if let onEditIcon {
                    Divider()
                    Button("Customize Icon…") { onEditIcon(slot.id) }
                }
                if slot.icon != nil {
                    Button("Use Group Icon") { store.updateSlot(slot.id) { $0.icon = nil } }
                }
                Divider()
                Button("Delete Slot", role: .destructive) { store.deleteSlot(slot.id) }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .accessibilityLabel(Text("More actions for \(slot.name)"))
        }
        .padding(.vertical, 2)
        .popover(isPresented: $editingGroups, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 8) {
                Text("The popup swipes between these groups.").font(.caption).foregroundStyle(.secondary)
                SlotGroupsEditor(slot: slot)
            }
            .padding(14)
            .frame(width: 280)
        }
    }

    /// Status, then the groups. Most slots show the one group they are named after; the name says that already.
    private func subtitle(installed: Bool, inDock: Bool) -> String {
        let status = status(installed: installed, inDock: inDock)
        let names = slot.groupIDs.compactMap { store.group($0)?.name }
        if names == [slot.name] { return status }
        let groups = names.isEmpty ? String(localized: "No groups") : names.joined(separator: ", ")
        return status + " · " + groups
    }

    private func status(installed: Bool, inDock: Bool) -> String {
        if inDock { return String(localized: "In the Dock") }
        if installed { return String(localized: "Launcher installed, not in the Dock") }
        return String(localized: "Not installed")
    }
}

/// Which groups a slot shows and in what order. The popup swipes between them.
private struct SlotGroupsEditor: View {
    let slot: DockSlot
    private var store: LibraryStore { LibraryStore.shared }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(slot.groupIDs.enumerated()), id: \.element) { index, gid in
                HStack {
                    Text(store.group(gid)?.name ?? String(localized: "Deleted group"))
                    Spacer()
                    Button { move(index, by: -1) } label: { Image(systemName: "chevron.up") }
                        .disabled(index == 0)
                        .accessibilityLabel(Text("Move up"))
                    Button { move(index, by: 1) } label: { Image(systemName: "chevron.down") }
                        .disabled(index == slot.groupIDs.count - 1)
                        .accessibilityLabel(Text("Move down"))
                    Button { store.updateSlot(slot.id) { $0.groupIDs.remove(at: index) } } label: { Image(systemName: "minus.circle") }
                        .accessibilityLabel(Text("Remove group from slot"))
                }
                .buttonStyle(.borderless)
            }
            let others = store.library.groups.filter { !slot.groupIDs.contains($0.id) }
            if !others.isEmpty {
                Menu("Show Another Group") {
                    ForEach(others) { g in
                        Button(g.name) { store.updateSlot(slot.id) { $0.groupIDs.append(g.id) } }
                    }
                }
                .fixedSize()
            }
        }
        .padding(.leading, 4)
    }

    private func move(_ index: Int, by delta: Int) {
        store.updateSlot(slot.id) { s in
            let to = index + delta
            guard s.groupIDs.indices.contains(to) else { return }
            s.groupIDs.swapAt(index, to)
        }
    }
}

// MARK: - Spacer row

private struct SpacerRow: View {
    let spacer: CustomSpacer
    private var store: LibraryStore { LibraryStore.shared }
    private var dock: DockManager { DockManager.shared }

    var body: some View {
        let installed = spacer.launcherPath.map { FileManager.default.fileExists(atPath: $0) } ?? false
        let inDock = installed && dock.isInDock(.spacer(spacer.id))
        HStack(spacing: 10) {
            Image(nsImage: LauncherIcon.spacerArt(spacer, size: 64))
                .resizable()
                .frame(width: 32, height: 32)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color(white: 0.3)))
                .accessibilityHidden(true)
            TextField("Text", text: Binding(
                get: { spacer.text },
                set: { t in store.updateSpacer(spacer.id) { $0.text = t; $0.icon.content = .text(t) } }))
                .frame(maxWidth: 180)
                .labelsHidden()
                .accessibilityLabel(Text("Spacer text"))
            ColorPicker("Color", selection: Binding(
                get: { spacer.icon.foreground.color },
                set: { c in store.updateSpacer(spacer.id) { $0.icon.foreground = RGBA(NSColor(c)) } }))
                .labelsHidden()
                .accessibilityLabel(Text("Text color"))
            Button(spacer.imagePath == nil ? "Image…" : "Remove Image") { toggleImage() }
            Spacer()
            if dock.busy.contains(spacer.id) { ProgressView().controlSize(.small) }
            if inDock {
                Button("Remove from Dock") { dock.removeFromDock(.spacer(spacer.id)) }
            } else {
                Button("Add to Dock") { dock.addToDock(.spacer(spacer.id)) }
            }
            Button { delete() } label: { Image(systemName: "trash") }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text("Delete spacer"))
        }
        .padding(.vertical, 2)
    }

    private func toggleImage() {
        if spacer.imagePath != nil {
            store.updateSpacer(spacer.id) { $0.imagePath = nil }
            return
        }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        // Copy into the data folder so the image survives when the original moves.
        let dest = LibraryStore.directory.appendingPathComponent("Spacers", isDirectory: true)
            .appendingPathComponent("\(spacer.id.uuidString).\(url.pathExtension)")
        try? FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: dest)
        let path = (try? FileManager.default.copyItem(at: url, to: dest)) != nil ? dest.path : url.path
        store.updateSpacer(spacer.id) { $0.imagePath = path }
    }

    private func delete() {
        if spacer.launcherPath != nil { dock.removeSpacer(spacer.id) }
        store.deleteSpacer(spacer.id)
    }
}

// MARK: - Failure banner

struct FailureBanner: View {
    let failure: LauncherFailure
    var dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange).accessibilityHidden(true)
            Text(failure.message).frame(maxWidth: .infinity, alignment: .leading)
            Button("Copy Details") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(failure.details, forType: .string)
            }
            Button { dismiss() } label: { Image(systemName: "xmark") }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text("Dismiss"))
        }
        .padding(10)
        .background(.orange.opacity(0.12))
    }
}
