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
        return hits.isEmpty ? "No installed app matches." : hits.map { app in
            app.category.map { "\(app.name) (\($0))" } ?? app.name
        }.joined(separator: ", ")
    }

    static func search(_ query: String, in apps: [AppInfo], limit: Int = 12) -> [AppInfo] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        let byName = apps.filter { $0.name.localizedStandardContains(q) }
        let byCategory = apps.filter { ($0.category ?? "").localizedStandardContains(q) && !byName.contains($0) }
        return Array((byName + byCategory).prefix(limit))
    }
}
