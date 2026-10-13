import Foundation
import Testing
@testable import PocketwerkKit

/// Assistant edits from German and English requests: color words, moods, gradients, theme guard.
@Suite struct AppAssistantLanguageTests {
    func group() -> ItemGroup {
        var g = ItemGroup(name: "Work")
        g.style.cornerRadius = 24
        return g
    }

    func run(_ request: String, _ edits: [(String, String)], themes: [Theme] = ThemeLibrary.builtIn) -> AssistantOutcome {
        AssistantInterpreter.apply(edits.map { AssistantEditInput(kind: $0.0, value: $0.1) }, to: group(),
                                   themes: themes, apps: [], request: request)
    }

    func gradientColors(_ out: AssistantOutcome) -> [RGBA]? {
        if case .gradient(let colors, _) = out.group.style.background { return colors }
        return nil
    }

    func isWarm(_ colors: [RGBA]) -> Bool { AssistantVocabulary.colorMoods(colors).contains(.warm) }

    @Test func germanWarmGradientNeverGetsColdTheme() throws {
        // What the model did in the field: a cold look plus a bad border value.
        let out = run("Verwende einen warmen Verlauf und runde Ecken",
                      [("theme", "Northern Veil"), ("border", "red"), ("corners", "rund")])
        #expect(out.group.themeID != "theme.northernveil")
        let colors = try #require(gradientColors(out))
        #expect(isWarm(colors))
        #expect(out.group.style.cornerRadius >= 30)
        #expect(out.group.style.border?.color == AssistantVocabulary.color("red"))
        #expect(out.skipped.isEmpty)
    }

    @Test func warmGradientWithoutAnyEdits() throws {
        let out = run("Verwende einen warmen Verlauf und runde Ecken", [])
        #expect(isWarm(try #require(gradientColors(out))))
        #expect(out.group.style.cornerRadius == 30)
    }

    @Test func englishWarmGradient() throws {
        let out = run("Use a warm gradient and round corners", [("gradient", "warm")])
        #expect(isWarm(try #require(gradientColors(out))))
        #expect(out.group.style.cornerRadius == 30)
    }

    @Test func gradientFromNamedColors() throws {
        let out = run("Farbverlauf von Orange über Koralle zu Rosa", [("gradient", "orange, koralle, rosa")])
        let colors = try #require(gradientColors(out))
        #expect(colors.count == 3)
        #expect(colors[0] == AssistantVocabulary.color("orange"))
        #expect(colors[2] == AssistantVocabulary.color("pink"))
    }

    @Test func singleColorGradientGetsAPartner() throws {
        let out = run("blue gradient", [("gradient", "blue")])
        #expect(try #require(gradientColors(out)).count == 2)
    }

    @Test func matchingWarmThemeIsKept() {
        let hearth = ThemeLibrary.builtIn.first { $0.id == "theme.hearth" }
        if let hearth {
            let out = run("warm animated look", [("theme", hearth.name)])
            #expect(out.group.themeID == hearth.id)
        }
    }

    @Test func colorWordsInBothLanguages() {
        let pairs: [(String, String)] = [("red", "rot"), ("blue", "blau"), ("green", "grün"), ("purple", "lila"),
                                         ("black", "schwarz"), ("white", "weiß"), ("gray", "grau"), ("pink", "rosa"),
                                         ("coral", "koralle"), ("dark blue", "dunkelblau"), ("light green", "hellgrün")]
        for (en, de) in pairs {
            #expect(AssistantVocabulary.color(en) != nil, "\(en)")
            #expect(AssistantVocabulary.color(en) == AssistantVocabulary.color(de), "\(en) / \(de)")
        }
        #expect(AssistantVocabulary.color("orange") != nil && AssistantVocabulary.color("gold") != nil)
        #expect(AssistantVocabulary.color("red.") != nil)
        #expect(AssistantVocabulary.color("„Rot“") != nil)
        #expect(AssistantVocabulary.color("warmes Rot") == AssistantVocabulary.color("red"))
        #expect(AssistantVocabulary.color("dunkelblau")!.b < AssistantVocabulary.color("blau")!.b)
        #expect(AssistantVocabulary.color("plaid") == nil)
    }

    @Test func colorsForFillBorderAndLabels() {
        let out = run("", [("color", "Dunkelblau"), ("border", "weiß"), ("labels", "gold")])
        #expect(out.group.style.background == .solid(AssistantVocabulary.color("dark blue")!))
        #expect(out.group.style.border?.color == AssistantVocabulary.color("white"))
        #expect(out.group.style.labels.colorMode == .custom)
        #expect(out.group.style.labels.color == AssistantVocabulary.color("gold"))
        #expect(out.skipped.isEmpty)
    }

    @Test func germanValueKeywords() {
        let out = run("", [("layout", "Liste"), ("labels", "beim Überfahren"), ("iconSize", "groß"), ("spacing", "luftig"),
                           ("border", "keiner"), ("shadow", "aus"), ("appearance", "dunkel"), ("corners", "eckig")])
        let s = out.group.style
        #expect(s.layout == .list)
        #expect(s.labels.mode == .onHover)
        #expect(s.iconSize == 72)
        #expect(s.spacing == 22)
        #expect(!s.shadow)
        #expect(s.appearance == .dark)
        #expect(s.cornerRadius == 6)
    }

    @Test func themeMoodTags() {
        let warm = Theme(id: "w", name: "W", style: GroupStyle(background: .gradient(colors: [RGBA(hex: "#F28C38"), RGBA(hex: "#E5546E")], angle: 0)))
        let cold = Theme(id: "c", name: "C", style: GroupStyle(background: .gradient(colors: [RGBA(hex: "#2A6FD6"), RGBA(hex: "#36B6D9")], angle: 0)))
        #expect(AssistantVocabulary.tags(for: warm).isSuperset(of: ["warm", "gradient"]))
        #expect(AssistantVocabulary.tags(for: cold).contains("cool"))
        #expect(!AssistantVocabulary.tags(for: cold).contains("warm"))
        if let veil = ThemeLibrary.builtIn.first(where: { $0.id == "theme.northernveil" }) {
            #expect(!AssistantVocabulary.tags(for: veil).contains("warm"))
        }
    }

    @Test func moodsAndIntents() {
        #expect(AssistantVocabulary.moodsIn("einen warmen Verlauf").contains(.warm))
        #expect(AssistantVocabulary.moodsIn("cool ocean look").contains(.cool))
        #expect(AssistantVocabulary.wantsGradient("Verwende einen warmen Verlauf"))
        #expect(AssistantVocabulary.wantsRoundCorners("und runde Ecken"))
        #expect(AssistantVocabulary.wantsRoundCorners("rounded corners"))
        #expect(!AssistantVocabulary.wantsRoundCorners("a round of applause"))
    }

    @Test func offTopicAndInventedRemovals() {
        let weather = run("What is the weather tomorrow?", [("theme", "Night Glass"), ("removeItem", "Music")])
        #expect(weather.changes.isEmpty && weather.removals.isEmpty)
        let wetter = run("Wie wird das Wetter morgen?", [("color", "blue")])
        #expect(wetter.changes.isEmpty)
        var g = group()
        g.items = [DockItem(kind: .link, url: URL(string: "https://example.com")!)]
        let keep = AssistantInterpreter.apply([AssistantEditInput(kind: "removeItem", value: "example.com")], to: g,
                                              themes: [], apps: [], request: "Mach es blau")
        #expect(keep.removals.isEmpty)
        let drop = AssistantInterpreter.apply([AssistantEditInput(kind: "removeItem", value: "example.com")], to: g,
                                              themes: [], apps: [], request: "Entferne example.com")
        #expect(drop.removals.count == 1)
    }

    @Test func replyLanguageFollowsRequest() {
        #expect(AssistantVocabulary.replyLanguage(for: "Verwende einen warmen Verlauf und runde Ecken", fallback: "en") == "German")
        #expect(AssistantVocabulary.replyLanguage(for: "Use a warm gradient and round corners", fallback: "de") == "English")
        #expect(AssistantVocabulary.replyLanguage(for: "Ok", fallback: "de") == "German")
    }
}
