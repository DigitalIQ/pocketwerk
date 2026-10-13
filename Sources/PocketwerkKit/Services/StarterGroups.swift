import AppKit

/// Ready-made groups offered once on first launch, filled with apps that are installed.
nonisolated struct StarterGroup: Identifiable, Hashable, Sendable {
    var id: String { name }
    var name: String
    var emoji: String
    var apps: [URL]
}

nonisolated enum StarterGroups {
    static let catalog: [(name: String, emoji: String, bundleIDs: [String])] = [
        ("Work", "💼", ["com.apple.mail", "com.apple.iCal", "com.apple.Notes", "com.apple.reminders",
                        "com.apple.iWork.Pages", "com.apple.iWork.Numbers", "com.apple.iWork.Keynote",
                        "com.microsoft.Word", "com.microsoft.Excel", "com.microsoft.Powerpoint",
                        "com.microsoft.Outlook", "com.microsoft.teams2", "com.tinyspeck.slackmacgap",
                        "us.zoom.xos", "notion.id", "com.apple.Safari"]),
        ("Creative", "🎨", ["com.apple.Photos", "com.apple.Preview", "com.apple.garageband10", "com.apple.iMovieApp",
                            "com.apple.FinalCut", "com.apple.logic10", "com.pixelmatorteam.pixelmator.x",
                            "com.seriflabs.affinityphoto2", "com.seriflabs.affinitydesigner2", "com.figma.Desktop",
                            "com.adobe.Photoshop", "com.adobe.illustrator", "com.blackmagic-design.DaVinciResolve",
                            "com.apple.freeform", "org.blenderfoundation.blender"]),
        ("Utilities", "🧰", ["com.apple.systempreferences", "com.apple.ActivityMonitor", "com.apple.Terminal",
                             "com.apple.DiskUtility", "com.apple.calculator", "com.apple.TextEdit",
                             "com.apple.screenshot.launcher", "com.apple.Console", "com.apple.Passwords",
                             "com.apple.keychainaccess", "com.apple.ScreenSharing"]),
    ]

    /// Starter groups with installed apps only (at most 12 each). Groups without any app are left out.
    static func build(locate: (String) -> URL?) -> [StarterGroup] {
        catalog.compactMap { entry in
            let apps = Array(entry.bundleIDs.compactMap(locate).prefix(12))
            return apps.isEmpty ? nil : StarterGroup(name: entry.name, emoji: entry.emoji, apps: apps)
        }
    }
}

extension LibraryStore {
    /// Adds the chosen starter groups (and optionally a Most Used group) in one undo step.
    func addStarterGroups(_ starters: [StarterGroup], includeMostUsed: Bool) {
        mutate { lib in
            for s in starters where !lib.groups.contains(where: { $0.name == s.name }) {
                var g = ItemGroup(name: s.name)
                g.emoji = s.emoji
                g.style = lib.settings.defaultStyle
                g.items = s.apps.map { DockItem(kind: .app, url: $0) }
                lib.groups.append(g)
                lib.slots.append(DockSlot(name: g.name, groupIDs: [g.id]))
            }
            if includeMostUsed && !lib.groups.contains(where: { $0.smart == .mostUsed }) {
                var g = ItemGroup(name: SmartGroups.title(.mostUsed))
                g.smart = .mostUsed
                g.smartLimit = 10
                lib.groups.append(g)
            }
        }
    }
}
