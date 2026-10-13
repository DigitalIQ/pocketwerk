import AppKit
import SwiftUI

/// App drawer: live search, categories, sort and filter. Clicking an app adds it to the group or removes it.
struct AppDrawerView: View {
    let groupID: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var categories = Set<String>()
    @State private var sort: AppSort = .name
    @State private var filter: AppFilter = .all
    private var catalog: AppCatalog { AppCatalog.shared }
    private var store: LibraryStore { LibraryStore.shared }

    var body: some View {
        let lib = store.library
        let group = lib.group(groupID)
        let shown = AppQuery.apply(catalog.apps, search: search, categories: categories, filter: filter, sort: sort,
                                   inGroup: { app in group?.indexOfApp(url: app.url, bundleID: app.bundleID) != nil },
                                   inAnyGroup: { app in lib.anyGroupContains(appURL: app.url, bundleID: app.bundleID) })
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                TextField("Search apps", text: $search)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 180)
                    .accessibilityLabel(Text("Search apps"))
                categoryMenu
                Picker("Filter", selection: $filter) {
                    Text("All Apps").tag(AppFilter.all)
                    Text("In This Group").tag(AppFilter.inThisGroup)
                    Text("Not in Any Group").tag(AppFilter.notInAnyGroup)
                    Text("Recently Installed").tag(AppFilter.recentlyInstalled)
                }
                .fixedSize()
                Picker("Sort", selection: $sort) {
                    Text("Name").tag(AppSort.name)
                    Text("Recently Installed").tag(AppSort.recentlyInstalled)
                    Text("Category").tag(AppSort.category)
                }
                .fixedSize()
            }
            .padding(12)
            Divider()
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 92, maximum: 120), spacing: 8)], spacing: 10) {
                    ForEach(shown) { app in
                        AppTile(app: app, selected: group?.indexOfApp(url: app.url, bundleID: app.bundleID) != nil) {
                            store.toggleApp(url: app.url, bundleID: app.bundleID, in: groupID)
                        }
                    }
                }
                .padding(12)
            }
            .overlay {
                if catalog.isLoading && catalog.apps.isEmpty {
                    ProgressView("Looking for apps…")
                } else if shown.isEmpty {
                    ContentUnavailableView.search
                }
            }
            Divider()
            HStack {
                Text("\(shown.count) apps").foregroundStyle(.secondary).monospacedDigit()
                Spacer()
                Text("\(group?.items.count ?? 0) items in “\(group?.name ?? "")”").foregroundStyle(.secondary)
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            .padding(12)
        }
        .frame(minWidth: 640, idealWidth: 760, minHeight: 480, idealHeight: 560)
        .task { await catalog.loadIfNeeded() }
    }

    private var categoryMenu: some View {
        Menu {
            Button("All Categories") { categories.removeAll() }
            Divider()
            ForEach(AppQuery.categories(catalog.apps), id: \.self) { name in
                Toggle(name, isOn: Binding(get: { categories.contains(name) },
                                           set: { on in if on { categories.insert(name) } else { categories.remove(name) } }))
            }
        } label: {
            Text(categories.isEmpty ? String(localized: "All Categories")
                 : categories.count == 1 ? categories.first! : String(localized: "\(categories.count) Categories"))
        }
        .fixedSize()
        .accessibilityLabel(Text("Categories"))
    }
}

/// One app in the drawer. A check mark shows it is in the group.
struct AppTile: View {
    let app: AppInfo
    let selected: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            VStack(spacing: 4) {
                Image(nsImage: AppIconCache.icon(for: app.url))
                    .resizable().frame(width: 48, height: 48)
                    .overlay(alignment: .topTrailing) {
                        if selected {
                            Image(systemName: "checkmark.circle.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, Color.accentColor)
                                .font(.system(size: 16))
                                .offset(x: 4, y: -4)
                        }
                    }
                Text(app.name).font(.caption).lineLimit(2).multilineTextAlignment(.center)
                    .frame(height: 28, alignment: .top)
            }
            .padding(6)
            .frame(maxWidth: .infinity)
            .background(selected ? Color.accentColor.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(app.category.map { "\(app.name), \($0)" } ?? app.name)
        .accessibilityLabel(Text(app.name))
        .accessibilityValue(Text(selected ? String(localized: "In group") : String(localized: "Not in group")))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// App icons for the drawer, cached for the session.
enum AppIconCache {
    private static var cache: [String: NSImage] = [:]

    static func icon(for url: URL) -> NSImage {
        if let hit = cache[url.path] { return hit }
        let img = NSWorkspace.shared.icon(forFile: url.resolvingSymlinksInPath().path)
        img.size = NSSize(width: 64, height: 64)
        cache[url.path] = img
        return img
    }
}

/// Paste a link or take the front tab of a running browser.
struct AddLinkSheet: View {
    let groupID: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var name = ""
    @State private var error: String?
    private var store: LibraryStore { LibraryStore.shared }

    var body: some View {
        let url = GroupOrdering.normalizedLink(text)
        VStack(alignment: .leading, spacing: 14) {
            Text("Add Link").font(.headline)
            Form {
                TextField("Address", text: $text, prompt: Text("https://example.com"))
                TextField("Name", text: $name, prompt: Text("Optional"))
            }
            HStack {
                let browsers = BrowserTab.running
                Menu("Add Current Browser Tab") {
                    ForEach(browsers, id: \.self) { b in
                        Button(b.name) { take(from: b) }
                    }
                }
                .fixedSize()
                .disabled(browsers.isEmpty)
                .help(browsers.isEmpty ? "Open Safari, Chrome, Arc or Brave first" : "Use the front tab of a browser")
                Spacer()
            }
            if let error {
                Text(error).font(.caption).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Add") {
                    if let url { store.addLink(url, name: name, to: groupID) }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(url == nil)
            }
        }
        .padding(20)
        .frame(width: 440)
        .onAppear {
            if let s = NSPasteboard.general.string(forType: .string), GroupOrdering.normalizedLink(s) != nil, s.contains(".") {
                text = s.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
    }

    private func take(from browser: BrowserTab.Browser) {
        switch BrowserTab.currentTab(of: browser) {
        case .success(let tab):
            text = tab.url.absoluteString
            if name.isEmpty { name = tab.title }
            error = nil
        case .failure(.denied(let message)):
            error = String(localized: "\(browser.name) did not answer: \(message) Allow Pocketwerk under System Settings > Privacy & Security > Automation.")
        case .failure:
            error = String(localized: "\(browser.name) has no open tab.")
        }
    }
}
