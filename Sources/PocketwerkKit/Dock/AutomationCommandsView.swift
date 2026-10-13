import AppKit
import SwiftUI

/// Every way to drive Pocketwerk from outside: Siri and Shortcuts phrases, URLs and the command line,
/// each with a Copy button.
struct AutomationCommandsView: View {
    @Environment(\.dismiss) private var dismiss
    private var store: LibraryStore { LibraryStore.shared }

    struct Command: Identifiable {
        var id: String { text }
        var text: String
        var meaning: String
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Commands").font(.title2.weight(.semibold))
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            .padding(16)
            Divider()
            List {
                section("Siri and Shortcuts", siri,
                        footer: String(localized: "Shortcuts lists these actions under Pocketwerk when the app was built with App Intents metadata. The URLs below always work with the “Open URL” action."))
                section("URLs", urls, footer: nil)
                section("Command Line", cli, footer: String(localized: "Run scripts/pocketwerk, or Pocketwerk.app/Contents/MacOS/Pocketwerk --cli."))
            }
        }
        .frame(width: 620, height: 560)
    }

    private func section(_ title: LocalizedStringKey, _ commands: [Command], footer: String?) -> some View {
        Section {
            ForEach(commands) { c in
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(c.text).font(.body.monospaced()).textSelection(.enabled)
                        Text(c.meaning).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(c.text, forType: .string)
                    }
                    .accessibilityLabel(Text("Copy \(c.text)"))
                }
            }
        } header: {
            Text(title)
        } footer: {
            if let footer { Text(footer).foregroundStyle(.secondary) }
        }
    }

    private var exampleGroup: String { store.library.orderedGroups.first?.name ?? String(localized: "Work") }
    private var exampleProfile: String { store.library.profiles.first?.name ?? String(localized: "Home") }

    private var siri: [Command] {
        AutomationPhrases.all.map { Command(text: $0.example(group: exampleGroup, profile: exampleProfile), meaning: $0.meaning) }
    }

    private var urls: [Command] {
        let g = exampleGroup.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? exampleGroup
        let p = exampleProfile.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? exampleProfile
        return [
            Command(text: "pocketwerk://open?group=\(g)", meaning: String(localized: "Show a group")),
            Command(text: "pocketwerk://open", meaning: String(localized: "Show all groups")),
            Command(text: "pocketwerk://group?action=openAll&name=\(g)", meaning: String(localized: "Open every item of a group")),
            Command(text: "pocketwerk://group?action=hideAll&name=\(g)", meaning: String(localized: "Hide a group's apps")),
            Command(text: "pocketwerk://group?action=quitAll&name=\(g)", meaning: String(localized: "Quit a group's apps")),
            Command(text: "pocketwerk://profile?name=\(p)", meaning: String(localized: "Apply a Dock profile")),
            Command(text: "pocketwerk://profile?action=next", meaning: String(localized: "Apply the next profile")),
            Command(text: "pocketwerk://profile?action=save", meaning: String(localized: "Save the Dock into the active profile")),
            Command(text: "pocketwerk://profile?action=capture&name=\(p)", meaning: String(localized: "Save the Dock as a new profile")),
            Command(text: "pocketwerk://settings", meaning: String(localized: "Open the main window")),
        ]
    }

    private var cli: [Command] {
        [
            Command(text: "pocketwerk profiles list", meaning: String(localized: "List profiles")),
            Command(text: "pocketwerk profiles apply \"\(exampleProfile)\" --skip-if-active", meaning: String(localized: "Apply a profile")),
            Command(text: "pocketwerk profiles next", meaning: String(localized: "Apply the next profile")),
            Command(text: "pocketwerk profiles capture \"\(exampleProfile)\"", meaning: String(localized: "Save the Dock as a new profile")),
            Command(text: "pocketwerk open \"\(exampleGroup)\"", meaning: String(localized: "Show a group")),
            Command(text: "pocketwerk dock", meaning: String(localized: "List the current Dock tiles")),
            Command(text: "pocketwerk spaces", meaning: String(localized: "Show the current Space and display ids")),
        ]
    }
}

/// The spoken phrases the App Shortcuts declare, mirrored here for the command list.
/// Keep in step with `Sources/Pocketwerk/Intents.swift`.
enum AutomationPhrases {
    struct Phrase {
        var template: String
        var meaning: String

        func example(group: String, profile: String) -> String {
            template.replacingOccurrences(of: "<group>", with: group).replacingOccurrences(of: "<profile>", with: profile)
        }
    }

    static let all: [Phrase] = [
        Phrase(template: "Show <group> in Pocketwerk", meaning: String(localized: "Show a group's popup")),
        Phrase(template: "Open all of <group> in Pocketwerk", meaning: String(localized: "Open every item of a group")),
        Phrase(template: "Quit <group> in Pocketwerk", meaning: String(localized: "Quit a group's apps")),
        Phrase(template: "Switch Pocketwerk to <profile>", meaning: String(localized: "Apply a Dock profile")),
        Phrase(template: "Next Dock profile in Pocketwerk", meaning: String(localized: "Apply the next profile")),
    ]
}
