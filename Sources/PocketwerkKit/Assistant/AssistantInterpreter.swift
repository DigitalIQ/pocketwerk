import AppKit

/// One edit the language model asked for, in plain strings.
nonisolated struct AssistantEditInput: Hashable, Sendable {
    var kind: String
    var value: String
}

/// Result of applying edits to a copy of a group. Nothing is stored yet.
struct AssistantOutcome {
    var group: ItemGroup
    /// Readable list of what changed.
    var changes: [String] = []
    /// Items the model wants to remove. They are only removed after the user confirms.
    var removals: [DockItem] = []
    /// Edits that could not be done, with the reason.
    var skipped: [String] = []
}

/// Allowed edit kinds. Shared with the generation schema.
nonisolated enum AssistantKinds {
    static let all = ["rename", "emoji", "category", "theme", "color", "gradient", "glass", "border", "labels",
                      "layout", "columns", "iconSize", "corners", "spacing", "dockIcon", "addApp", "removeItem",
                      "sort", "appearance", "shadow"]

    /// Value formats, explained to the model once in the instructions.
    static let help = """
    rename: new name | emoji: one emoji | category: one or two words | theme: a theme name from the list | \
    color: color name or #RRGGBB (solid fill) | gradient: two or three colors separated by commas | \
    glass: a tint color or clear | border: none, thin, thick or a color | labels: always, hover, off or a color | \
    layout: grid, list or tiles | columns: a number or auto | iconSize: small, medium, large or points | \
    corners: square, round or points | spacing: tight, normal or airy | \
    dockIcon: grid, stack, emoji, monogram, text:WORD or symbol:SF_SYMBOL_NAME | \
    addApp: exact app name returned by findApps | removeItem: name of an item in the group | \
    sort: manual, name, kind, added, opened or used | appearance: light, dark or system | shadow: on or off
    """
}

/// Applies model edits to a group. Pure apart from theme and symbol lookups, so it is testable.
enum AssistantInterpreter {
    /// `request` is the user's own text. It guards against looks that do not match what was asked
    /// (a cold theme for "warm gradient") and fills in a gradient or round corners the model left out.
    static func apply(_ edits: [AssistantEditInput], to original: ItemGroup, themes: [Theme], apps: [AppInfo],
                      defaultStyle: GroupStyle = GroupStyle(), request: String = "") -> AssistantOutcome {
        var out = AssistantOutcome(group: original)
        var g = original
        // A question that is not about the group ("what is the weather?") changes nothing.
        let edits = request.isEmpty || AssistantVocabulary.isEditRequest(request) ? edits : []
        // Look edits on a group that follows the default look would be invisible: give it its own copy.
        func ownLook() {
            if g.usesDefaultStyle {
                g.usesDefaultStyle = false
                g.style = defaultStyle
                out.changes.append(String(localized: "Uses its own look now"))
            }
        }
        for edit in edits {
            let snapshot = g
            let changeCount = out.changes.count
            defer {
                // An edit that only restates the current state is not a change.
                if g == snapshot && out.changes.count > changeCount { out.changes.removeSubrange(changeCount...) }
            }
            let kind = edit.kind.trimmingCharacters(in: .whitespaces)
            let value = edit.value.trimmingCharacters(in: .whitespacesAndNewlines)
            let lower = AssistantVocabulary.keyword(value)
            func skip(_ why: String) { out.skipped.append(why) }

            switch kind {
            case "rename":
                guard !value.isEmpty, value != g.name else { continue }
                g.name = String(value.prefix(60))
                out.changes.append(String(localized: "Renamed to “\(g.name)”"))

            case "emoji":
                guard let first = value.first, first.isEmoji else { skip(String(localized: "“\(value)” is not an emoji")); continue }
                g.emoji = String(first)
                out.changes.append(String(localized: "Emoji \(String(first))"))

            case "category":
                g.category = value.isEmpty ? nil : String(value.prefix(40))
                out.changes.append(value.isEmpty ? String(localized: "Category cleared") : String(localized: "Category “\(value)”"))

            case "theme":
                // A look only counts when it fits the mood that was asked for ("warm" never gets a cold look).
                let wanted = AssistantVocabulary.moodsIn(request + " " + value)
                    .intersection([.warm, .cool, .dark, .light, .pastel, .nature])
                let fits: (Theme) -> Bool = { t in
                    let tags = AssistantVocabulary.tags(for: t)
                    if !wanted.allSatisfy({ tags.contains($0.rawValue) }) { return false }
                    return !AssistantVocabulary.wantsGradient(request) || tags.contains("gradient") || tags.contains("animated")
                }
                guard let theme = matchTheme(value, in: themes).flatMap({ fits($0) ? $0 : nil }) else {
                    // "warm sunset", "dark blue": describe a look instead of naming one.
                    if let colors = moodColors(value) ?? moodColors(request) {
                        ownLook()
                        g.style.background = colors.count == 1 ? .solid(colors[0]) : .gradient(colors: colors, angle: 135)
                        g.themeID = nil
                        out.changes.append(colors.count == 1 ? String(localized: "Fill \(colors[0].hex)")
                                           : String(localized: "Gradient \(colors.map(\.hex).joined(separator: " → "))"))
                    } else {
                        skip(String(localized: "No look named “\(value)”"))
                    }
                    continue
                }
                ownLook()
                g.style = ThemeLibrary.apply(theme, to: g.style)
                if let icon = theme.icon { g.icon = ThemeLibrary.apply(icon, to: g.icon) }
                g.themeID = theme.id
                out.changes.append(String(localized: "Look “\(theme.name)”"))

            case "color":
                guard let c = color(value) else { skip(String(localized: "Unknown color “\(value)”")); continue }
                ownLook()
                g.style.background = .solid(c)
                g.themeID = nil
                out.changes.append(String(localized: "Fill \(c.hex)"))

            case "gradient":
                var colors = AssistantVocabulary.allColors(value)
                if colors.count < 2, let mood = moodColors(value) ?? moodColors(request), mood.count >= 2 { colors = mood }
                if colors.count == 1 { colors.append(partner(for: colors[0])) }
                guard colors.count >= 2 else { skip(String(localized: "A gradient needs two colors")); continue }
                ownLook()
                g.style.background = .gradient(colors: Array(colors.prefix(4)), angle: 135)
                g.themeID = nil
                out.changes.append(String(localized: "Gradient \(colors.prefix(4).map(\.hex).joined(separator: " → "))"))

            case "glass":
                let tint = ["", "clear", "none"].contains(lower) ? RGBA(0.1, 0.1, 0.12, 0.25) : color(value).map { RGBA($0.r, $0.g, $0.b, 0.35) }
                guard let tint else { skip(String(localized: "Unknown color “\(value)”")); continue }
                ownLook()
                g.style.background = .glass(tint: tint, intensity: 1)
                g.themeID = nil
                out.changes.append(String(localized: "Glass fill"))

            case "border":
                ownLook()
                switch lower {
                case "none", "off", "no", "false", "nein", "aus", "kein", "keiner":
                    g.style.border = nil
                    out.changes.append(String(localized: "No border"))
                case "yes", "on", "true", "ja", "an":
                    // The model sometimes answers a yes/no question instead of naming a border.
                    if g.style.border == nil {
                        g.style.border = BorderStyle()
                        out.changes.append(String(localized: "Thin border"))
                    }
                case "thin":
                    var b = g.style.border ?? BorderStyle(); b.width = 1; g.style.border = b
                    out.changes.append(String(localized: "Thin border"))
                case "thick":
                    var b = g.style.border ?? BorderStyle(); b.width = 3; g.style.border = b
                    out.changes.append(String(localized: "Thick border"))
                default:
                    guard let c = color(value) else { skip(String(localized: "Unknown border “\(value)”")); continue }
                    var b = g.style.border ?? BorderStyle(); b.color = c; b.gradient = nil; g.style.border = b
                    out.changes.append(String(localized: "Border \(c.hex)"))
                }

            case "labels":
                let mode: LabelMode? = lower.contains("hover") ? .onHover
                    : ["off", "none", "hidden", "hide", "no"].contains(lower) ? .off
                    : ["always", "on", "show", "yes"].contains(lower) ? .always : nil
                if mode == nil, let c = color(value) {
                    ownLook()
                    g.style.labels.colorMode = .custom
                    g.style.labels.color = c
                    out.changes.append(String(localized: "Label color \(c.hex)"))
                    continue
                }
                guard let mode else { skip(String(localized: "Labels can be always, hover or off")); continue }
                ownLook()
                g.style.labels.mode = mode
                out.changes.append(String(localized: "Labels: \(mode.rawValue)"))

            case "layout":
                guard let layout = LayoutKind(rawValue: lower) ?? (lower.contains("list") ? .list : nil) else {
                    skip(String(localized: "Layout can be grid, list or tiles")); continue
                }
                ownLook()
                g.style.layout = layout
                out.changes.append(String(localized: "Layout: \(layout.rawValue)"))

            case "columns":
                let n = lower == "auto" ? 0 : Int(lower.filter(\.isNumber)) ?? -1
                guard (0...12).contains(n) else { skip(String(localized: "Columns must be 1 to 12 or auto")); continue }
                ownLook()
                g.style.columns = n
                out.changes.append(n == 0 ? String(localized: "Columns: automatic") : String(localized: "Columns: \(n)"))

            case "iconSize":
                let size: Double? = switch lower {
                case "small", "smaller": 40
                case "medium", "normal": 56
                case "large", "bigger", "big": 72
                case "huge": 96
                default: Double(lower.filter { $0.isNumber || $0 == "." }).map { min(128, max(24, $0)) }
                }
                guard let size else { skip(String(localized: "Unknown icon size “\(value)”")); continue }
                ownLook()
                g.style.iconSize = size
                out.changes.append(String(localized: "Icon size \(Int(size)) pt"))

            case "corners":
                let r: Double? = switch lower {
                case "square", "sharp": 6
                case "round", "rounded": 30
                case "very round", "pill": 40
                default: Double(lower.filter { $0.isNumber || $0 == "." }).map { min(48, max(0, $0)) }
                }
                guard let r else { skip(String(localized: "Unknown corner radius “\(value)”")); continue }
                ownLook()
                g.style.cornerRadius = r
                out.changes.append(String(localized: "Corner radius \(Int(r)) pt"))

            case "spacing":
                let sp: Double? = switch lower { case "tight", "compact": 8; case "normal": 14; case "airy", "wide", "loose": 22; default: nil }
                guard let sp else { skip(String(localized: "Spacing can be tight, normal or airy")); continue }
                ownLook()
                g.style.spacing = sp
                out.changes.append(String(localized: "Spacing \(Int(sp)) pt"))

            case "shadow":
                ownLook()
                g.style.shadow = !["off", "none", "no"].contains(lower)
                out.changes.append(g.style.shadow ? String(localized: "Shadow on") : String(localized: "Shadow off"))

            case "appearance":
                guard let a = AppearanceChoice(rawValue: lower) else { skip(String(localized: "Appearance can be light, dark or system")); continue }
                ownLook()
                g.style.appearance = a
                out.changes.append(String(localized: "Appearance: \(a.rawValue)"))

            case "dockIcon":
                guard let content = iconContent(value, group: g) else { skip(String(localized: "Unknown Dock icon “\(value)”")); continue }
                g.icon.content = content
                out.changes.append(String(localized: "Dock icon: \(value)"))

            case "sort":
                let map: [String: SortOrder] = ["manual": .manual, "name": .name, "alphabetical": .name, "kind": .kind,
                                                "added": .dateAdded, "date added": .dateAdded, "opened": .lastOpened,
                                                "last opened": .lastOpened, "recent": .lastOpened, "used": .mostOpened,
                                                "most used": .mostOpened, "most opened": .mostOpened]
                guard let order = map[lower] ?? SortOrder(rawValue: value) else { skip(String(localized: "Unknown sort order “\(value)”")); continue }
                g.sortOrder = order
                out.changes.append(String(localized: "Sorted by \(SortOrderName.title(order))"))

            case "addApp":
                guard g.smart == nil else { skip(String(localized: "Smart groups fill themselves")); continue }
                guard let app = matchApp(value, in: apps) else { skip(String(localized: "“\(value)” is not installed")); continue }
                guard g.indexOfApp(url: app.url, bundleID: app.bundleID) == nil else { continue }
                var item = DockItem(kind: .app, url: app.url)
                if item.bundleID == nil { item.bundleID = app.bundleID }
                g.items.append(item)
                out.changes.append(String(localized: "Added \(app.name)"))

            case "removeItem":
                guard request.isEmpty || AssistantVocabulary.asksToRemove(request) else { continue }
                guard let item = matchItem(value, in: g.items) else { skip(String(localized: "No item “\(value)” in this group")); continue }
                if !out.removals.contains(where: { $0.id == item.id }) { out.removals.append(item) }

            default:
                skip(String(localized: "Cannot do “\(kind)” yet"))
            }
        }
        // The request asked for a gradient or round corners and the edits did not deliver: add them.
        if !request.isEmpty && AssistantVocabulary.wantsGradient(request) {
            let isGradient: Bool = switch g.style.background { case .gradient, .mesh: true; default: false }
            var colors = moodColors(request) ?? []
            if colors.count == 1 { colors.append(partner(for: colors[0])) }
            if !isGradient, colors.count >= 2 {
                ownLook()
                g.style.background = .gradient(colors: colors, angle: 135)
                g.themeID = nil
                out.changes.append(String(localized: "Gradient \(colors.map(\.hex).joined(separator: " → "))"))
            }
        }
        if !request.isEmpty && AssistantVocabulary.wantsRoundCorners(request) && g.style.cornerRadius < 30 {
            ownLook()
            g.style.cornerRadius = 30
            out.changes.append(String(localized: "Corner radius 30 pt"))
        }
        out.group = g
        return out
    }

    /// Second gradient color for a single one: a neighbour hue, a bit darker.
    static func partner(for c: RGBA) -> RGBA {
        let ns = NSColor(srgbRed: c.r, green: c.g, blue: c.b, alpha: 1)
        let h = (ns.hueComponent + 0.07).truncatingRemainder(dividingBy: 1)
        return RGBA(NSColor(hue: h, saturation: min(1, ns.saturationComponent + 0.05),
                            brightness: max(0.15, ns.brightnessComponent * 0.8), alpha: 1))
    }

    // MARK: Matching

    static func splitList(_ text: String) -> [String] {
        text.replacingOccurrences(of: " and ", with: ",").replacingOccurrences(of: " to ", with: ",")
            .split(whereSeparator: { $0 == "," || $0 == ";" || $0 == "/" })
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// "#3366FF", "3366ff" or a color phrase in English or German ("dark blue", "Dunkelblau", "red.").
    static func color(_ text: String) -> RGBA? { AssistantVocabulary.color(text) }

    /// Colors for a phrase: named colors, or the colors of a mood ("warm", "Sonnenuntergang", "ocean").
    static func moodColors(_ text: String) -> [RGBA]? { AssistantVocabulary.moodColors(text) }

    static func matchTheme(_ name: String, in themes: [Theme]) -> Theme? {
        let n = name.lowercased().trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return nil }
        return themes.first { $0.name.lowercased() == n || $0.id.lowercased() == n }
            ?? themes.first { $0.name.lowercased().hasPrefix(n) }
            ?? themes.first { $0.name.lowercased().contains(n) || n.contains($0.name.lowercased()) }
    }

    static func matchApp(_ name: String, in apps: [AppInfo]) -> AppInfo? {
        let n = name.lowercased().replacingOccurrences(of: ".app", with: "").trimmingCharacters(in: .whitespaces)
        guard n.count >= 2 else { return nil }
        return apps.first { $0.name.lowercased() == n || $0.bundleID?.lowercased() == n }
            ?? apps.first { $0.name.lowercased().hasPrefix(n) }
            ?? apps.first { $0.name.lowercased().contains(n) }
    }

    static func matchItem(_ name: String, in items: [DockItem]) -> DockItem? {
        let n = name.lowercased().replacingOccurrences(of: ".app", with: "").trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return nil }
        return items.first { $0.displayName.lowercased() == n }
            ?? items.first { $0.displayName.lowercased().hasPrefix(n) }
            ?? items.first { $0.displayName.lowercased().contains(n) }
    }

    static func iconContent(_ value: String, group: ItemGroup) -> IconContent? {
        let lower = value.lowercased()
        if lower.hasPrefix("text:") { return .text(String(value.dropFirst(5).prefix(4))) }
        if lower.hasPrefix("symbol:") {
            let name = String(value.dropFirst(7)).trimmingCharacters(in: .whitespaces)
            return NSImage(systemSymbolName: name, accessibilityDescription: nil) == nil ? nil : .symbol(name: name)
        }
        switch lower {
        case "grid", "items", "icons": return .itemGrid(count: 0)
        case "stack": return .itemStack
        case "monogram", "letters", "initials": return .monogram
        case "emoji": return .emoji(group.emoji ?? "📁")
        default:
            if let first = value.first, first.isEmoji, value.count <= 2 { return .emoji(String(first)) }
            return nil
        }
    }
}

nonisolated extension Character {
    /// True for pictographic emoji (not plain digits or "#").
    var isEmoji: Bool {
        unicodeScalars.contains { $0.properties.isEmojiPresentation || ($0.properties.isEmoji && $0.value > 0x238C) }
    }
}
