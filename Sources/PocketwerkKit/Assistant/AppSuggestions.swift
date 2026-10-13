import AppKit
import FoundationModels
import Observation

/// Offline app suggestions: categories of the apps already in the group, words in the group name
/// and category, and apps that are often used together with the group's apps.
nonisolated enum SuggestionRanker {
    /// Words in a group name or category that point to app categories.
    static let keywords: [(words: [String], categories: [String])] = [
        (["work", "office", "business", "arbeit", "büro"], ["Productivity", "Business"]),
        (["design", "creative", "art", "kreativ", "grafik"], ["Graphics & Design", "Photography"]),
        (["photo", "foto", "picture", "bild"], ["Photography", "Graphics & Design"]),
        (["video", "film", "movie"], ["Video", "Entertainment"]),
        (["music", "audio", "musik", "sound", "podcast"], ["Music"]),
        (["dev", "code", "coding", "develop", "programming", "entwicklung"], ["Developer Tools"]),
        (["game", "games", "spiel", "play"], ["Games"]),
        (["util", "tool", "system", "werkzeug"], ["Utilities"]),
        (["social", "chat", "message", "communication", "kommunikation"], ["Social Networking", "Business"]),
        (["learn", "study", "school", "education", "lernen"], ["Education", "Reference"]),
        (["finance", "money", "finanzen", "geld"], ["Finance"]),
        (["news", "read", "lesen"], ["News", "Reference"]),
        (["health", "fitness", "sport"], ["Health & Fitness", "Sports"]),
        (["travel", "reise"], ["Travel", "Weather"]),
    ]

    static func wantedCategories(name: String, category: String?) -> [String] {
        let text = (name + " " + (category ?? "")).lowercased()
        return keywords.filter { k in k.words.contains { text.contains($0) } }.flatMap(\.categories)
    }

    static func rank(group: ItemGroup, apps: [AppInfo], usage: UsageStats, limit: Int = 8) -> [AppInfo] {
        let inGroup = apps.filter { group.indexOfApp(url: $0.url, bundleID: $0.bundleID) != nil }
        let groupIDs = Set(inGroup.compactMap(\.bundleID) + group.items.compactMap(\.bundleID))
        var categoryWeight: [String: Double] = [:]
        for app in inGroup { if let c = app.category { categoryWeight[c, default: 0] += 1 } }
        for c in wantedCategories(name: group.name, category: group.category) { categoryWeight[c, default: 0] += 2 }

        var scored: [(AppInfo, Double)] = []
        for app in apps where group.indexOfApp(url: app.url, bundleID: app.bundleID) == nil {
            var score = 0.0
            if let c = app.category { score += (categoryWeight[c] ?? 0) * 2 }
            if let bid = app.bundleID, let together = usage.coOccurrence[bid] {
                score += Double(together.filter { groupIDs.contains($0.key) }.values.reduce(0, +)) * 1.5
            }
            guard score > 0 else { continue }
            if let bid = app.bundleID { score += min(3, Double(usage.launches[bid] ?? 0) / 10) }
            scored.append((app, score))
        }
        return Array(scored.sorted { a, b in
            a.1 != b.1 ? a.1 > b.1 : a.0.name.localizedStandardCompare(b.0.name) == .orderedAscending
        }.map(\.0).prefix(limit))
    }
}

/// Groups of apps that are often launched together and are not already one of your groups.
nonisolated enum CoUsage {
    struct Suggestion: Hashable, Sendable {
        var name: String
        var bundleIDs: [String]
    }

    static func suggestions(usage: UsageStats, groups: [ItemGroup], categoryOf: (String) -> String?,
                            minCount: Int = 3, maxSize: Int = 8) -> [Suggestion] {
        // Union of pairs used together at least `minCount` times.
        var parent: [String: String] = [:]
        func find(_ x: String) -> String {
            var r = x
            while let p = parent[r], p != r { r = p }
            return r
        }
        for (a, others) in usage.coOccurrence {
            for (b, n) in others where n >= minCount && a < b {
                if parent[a] == nil { parent[a] = a }
                if parent[b] == nil { parent[b] = b }
                parent[find(a)] = find(b)
            }
        }
        var clusters: [String: [String]] = [:]
        for k in parent.keys { clusters[find(k), default: []].append(k) }
        let existing: [Set<String>] = groups.filter { $0.smart == nil }.map { Set($0.items.compactMap(\.bundleID)) }
        var out: [Suggestion] = []
        for members in clusters.values {
            let sorted = members.sorted { (usage.launches[$0] ?? 0) > (usage.launches[$1] ?? 0) }
            guard sorted.count >= 3 else { continue }
            let ids = Array(sorted.prefix(maxSize))
            // Skip clusters that an existing group already covers for the most part.
            let covered = existing.contains { set in
                Double(Set(ids).intersection(set).count) / Double(ids.count) >= 0.6
            }
            if covered { continue }
            out.append(Suggestion(name: clusterName(ids, categoryOf: categoryOf), bundleIDs: ids))
        }
        return out.sorted { $0.bundleIDs.count > $1.bundleIDs.count }
    }

    /// The category most apps share, or a neutral name.
    static func clusterName(_ ids: [String], categoryOf: (String) -> String?) -> String {
        var counts: [String: Int] = [:]
        for id in ids { if let c = categoryOf(id) { counts[c, default: 0] += 1 } }
        if let top = counts.max(by: { $0.value < $1.value }), top.value * 2 >= ids.count { return top.key }
        return String(localized: "Used Together")
    }
}

/// App suggestions for one group: the on-device model when available, the offline ranking otherwise.
@Observable
final class SuggestionEngine {
    enum Source { case model, offline }

    private(set) var apps: [AppInfo] = []
    private(set) var source: Source = .offline
    private(set) var isWorking = false
    var dismissed = Set<String>()

    var visible: [AppInfo] { apps.filter { !dismissed.contains($0.id) } }

    func generate(for group: ItemGroup, from catalog: [AppInfo], usage: UsageStats) async {
        guard !isWorking, group.smart == nil, !catalog.isEmpty else { return }
        isWorking = true
        defer { isWorking = false }
        let offline = SuggestionRanker.rank(group: group, apps: catalog, usage: usage, limit: 8)
        if AIStatus.current.isAvailable, let picked = await modelPicks(group: group, catalog: catalog, offline: offline),
           !picked.isEmpty {
            apps = picked
            source = .model
        } else {
            apps = offline
            source = .offline
        }
    }

    /// Asks the model to choose from a short candidate list (keeps the prompt well inside 8192 tokens).
    private func modelPicks(group: ItemGroup, catalog: [AppInfo], offline: [AppInfo]) async -> [AppInfo]? {
        let candidates = catalog.filter { group.indexOfApp(url: $0.url, bundleID: $0.bundleID) == nil && !dismissed.contains($0.id) }
        let ordered = offline.filter { o in candidates.contains(o) } + candidates.filter { !offline.contains($0) }
        let list = ordered.prefix(140).map { app in app.category.map { "\(app.name) [\($0)]" } ?? app.name }
        let current = group.items.prefix(20).map(\.displayName).joined(separator: ", ")
        let prompt = """
        Group name: \(group.name)
        Group category: \(group.category ?? "none")
        Already in the group: \(current.isEmpty ? "nothing yet" : current)
        Installed apps to choose from: \(list.joined(separator: "; "))
        Pick up to 8 apps from the installed list that fit this group best and are not in it yet.
        """
        let session = LanguageModelSession(instructions: "You suggest Mac apps for a named group. Only answer with app names from the given list.")
        do {
            let picks = try await session.respond(to: prompt, generating: AppPicks.self,
                                                  options: GenerationOptions(temperature: 0.4)).content
            var seen = Set<String>()
            return picks.apps.compactMap { raw in
                let name = (raw.components(separatedBy: " [").first ?? raw).trimmingCharacters(in: .whitespaces)
                return candidates.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
            }.filter { seen.insert($0.id).inserted }
        } catch {
            Log.app.info("App suggestions fell back to offline: \(error.localizedDescription)")
            return nil
        }
    }
}
