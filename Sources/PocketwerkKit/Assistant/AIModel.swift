import AppKit
import FoundationModels

/// Whether Apple's on-device model can be used, with a plain explanation when not.
enum AIStatus: Equatable {
    case available, deviceNotEligible, notEnabled, notReady, unknown

    static var current: AIStatus {
        switch SystemLanguageModel.default.availability {
        case .available: return .available
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible: return .deviceNotEligible
            case .appleIntelligenceNotEnabled: return .notEnabled
            case .modelNotReady: return .notReady
            @unknown default: return .unknown
            }
        }
    }

    var isAvailable: Bool { self == .available }

    var message: String {
        switch self {
        case .available: String(localized: "Apple Intelligence runs on this Mac. Nothing leaves it.")
        case .deviceNotEligible: String(localized: "This Mac does not support Apple Intelligence.")
        case .notEnabled: String(localized: "Turn on Apple Intelligence in System Settings to use this.")
        case .notReady: String(localized: "Apple Intelligence is still getting ready. Try again in a few minutes.")
        case .unknown: String(localized: "Apple Intelligence is not available right now.")
        }
    }

    static func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Siri-Settings.extension") { NSWorkspace.shared.open(url) }
    }
}

// MARK: - Generation schemas

@Generable(description: "Edits for one group of apps, files and links")
nonisolated struct AssistantPlan {
    @Guide(description: "One short friendly sentence for the user about what you changed, or why nothing changed")
    var reply: String
    @Guide(description: "Edits in order. Empty when the request does not ask for a change.", .maximumCount(10))
    var edits: [AssistantEdit]
}

@Generable
nonisolated struct AssistantEdit {
    @Guide(description: "What to change", .anyOf(AssistantKinds.all))
    var kind: String
    @Guide(description: "The new value in the format listed for this kind")
    var value: String
}

@Generable(description: "Apps that fit a group")
nonisolated struct AppPicks {
    @Guide(description: "App names copied exactly from the list of installed apps", .count(1...8))
    var apps: [String]
}

/// Lets the model look up installed apps instead of receiving the whole list.
nonisolated struct FindAppsTool: Tool {
    let apps: [AppInfo]
    let name = "findApps"
    let description = "Finds installed Mac apps by part of the name or by category (for example Music, Developer Tools, Games). Returns exact app names."

    @Generable
    struct Arguments {
        @Guide(description: "Part of an app name, or a category")
        var query: String
    }

    func call(arguments: Arguments) async throws -> String {
        let hits = Self.search(arguments.query, in: apps)
        Log.app.debug("findApps(\(arguments.query, privacy: .private)) -> \(hits.count)")
        return hits.isEmpty ? "No installed app matches." : hits.map { app in
            app.category.map { "\(app.name) (\($0))" } ?? app.name
        }.joined(separator: ", ")
    }

    static func search(_ query: String, in apps: [AppInfo], limit: Int = 12) -> [AppInfo] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        var hits = apps.filter { $0.name.localizedStandardContains(q) }
        hits += apps.filter { ($0.category ?? "").localizedStandardContains(q) && !hits.contains($0) }
        if hits.isEmpty {
            // "Calendar and Reminders", "music apps": try the single words.
            for word in q.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init) where word.count >= 3 {
                hits += apps.filter { app in
                    !hits.contains(app) && (app.name.localizedStandardContains(word) || (app.category ?? "").localizedStandardContains(word))
                }
            }
        }
        return Array(hits.prefix(limit))
    }

    /// Installed apps for the request: apps named in it, plus apps of categories it mentions
    /// ("my music apps", "developer tools"). Gives the model exact names without a tool round trip.
    static func candidates(for request: String, apps: [AppInfo], limit: Int = 16) -> [AppInfo] {
        let text = request.lowercased()
        // Only when the request is about adding; otherwise "weather tomorrow" would offer the Weather app.
        let addWords = ["add", "put", "include", "insert", "bring", "hinzu", "füge", "rein"]
        let words = Set(text.split(whereSeparator: { !$0.isLetter }).map(String.init))
        guard addWords.contains(where: { words.contains($0) || text.contains($0 + " ") }) else { return [] }
        var out = mentioned(in: request, apps: apps, limit: limit)
        var categories = Set(SuggestionRanker.wantedCategories(name: text, category: nil))
        for c in Set(apps.compactMap(\.category)) where text.contains(c.lowercased()) { categories.insert(c) }
        for app in apps where out.count < limit {
            if let c = app.category, categories.contains(c), !out.contains(app) { out.append(app) }
        }
        return out
    }

    /// Installed apps whose name appears in the request, so the model gets exact names up front.
    static func mentioned(in request: String, apps: [AppInfo], limit: Int = 12) -> [AppInfo] {
        let text = request.lowercased()
        return Array(apps.filter { app in
            let name = app.name.lowercased()
            guard name.count >= 3, let range = text.range(of: name) else { return false }
            // Whole words only: "Notes" must not match inside "footnotes".
            let before = range.lowerBound == text.startIndex ? " " : text[text.index(before: range.lowerBound)]
            let after = range.upperBound == text.endIndex ? " " : text[range.upperBound]
            return !before.isLetter && !after.isLetter
        }.prefix(limit))
    }
}
