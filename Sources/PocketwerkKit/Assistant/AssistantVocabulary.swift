import AppKit
import NaturalLanguage

/// English and German words the assistant understands: colors, moods and value keywords.
/// The model may answer with German values ("rund", "Liste", "dunkelblau"); everything is mapped
/// to the English keywords the interpreter works with.
enum AssistantVocabulary {
    // MARK: Colors

    /// Own palette. Keys are lowercase words in English and German.
    static let colors: [String: RGBA] = {
        let red = RGBA(0.86, 0.22, 0.24), orange = RGBA(0.96, 0.53, 0.18), yellow = RGBA(0.97, 0.80, 0.22)
        let gold = RGBA(0.86, 0.66, 0.26), coral = RGBA(0.98, 0.50, 0.42), pink = RGBA(0.95, 0.42, 0.62)
        let green = RGBA(0.25, 0.68, 0.36), mint = RGBA(0.42, 0.85, 0.72), teal = RGBA(0.16, 0.56, 0.60)
        let cyan = RGBA(0.30, 0.76, 0.90), blue = RGBA(0.20, 0.45, 0.90), navy = RGBA(0.09, 0.15, 0.36)
        let purple = RGBA(0.58, 0.32, 0.80), violet = RGBA(0.52, 0.36, 0.86), magenta = RGBA(0.85, 0.25, 0.70)
        let brown = RGBA(0.52, 0.36, 0.24), beige = RGBA(0.90, 0.84, 0.72), gray = RGBA(0.52, 0.53, 0.56)
        let black = RGBA(0.06, 0.06, 0.07), white = RGBA(0.97, 0.97, 0.96), silver = RGBA(0.76, 0.77, 0.80)
        let lavender = RGBA(0.72, 0.66, 0.92), olive = RGBA(0.45, 0.48, 0.22), turquoise = RGBA(0.22, 0.78, 0.74)
        let indigo = RGBA(0.33, 0.30, 0.78), peach = RGBA(0.99, 0.72, 0.56), crimson = RGBA(0.70, 0.10, 0.22)
        return [
            "red": red, "rot": red, "orange": orange, "yellow": yellow, "gelb": yellow, "gold": gold, "golden": gold,
            "coral": coral, "koralle": coral, "pink": pink, "rosa": pink, "rose": pink, "green": green, "grün": green,
            "gruen": green, "mint": mint, "teal": teal, "petrol": teal, "cyan": cyan, "türkis": turquoise,
            "turquoise": turquoise, "blue": blue, "blau": blue, "navy": navy, "marine": navy, "purple": purple,
            "lila": purple, "violet": violet, "violett": violet, "magenta": magenta, "brown": brown, "braun": brown,
            "beige": beige, "gray": gray, "grey": gray, "grau": gray, "black": black, "schwarz": black,
            "white": white, "weiß": white, "weiss": white, "silver": silver, "silber": silver, "lavender": lavender,
            "lavendel": lavender, "olive": olive, "oliv": olive, "indigo": indigo, "peach": peach, "pfirsich": peach,
            "crimson": crimson, "karmin": crimson, "bordeaux": crimson,
        ]
    }()

    static let darker: Set<String> = ["dark", "deep", "dunkel", "tief", "dunkle", "dunkler", "dunkles"]
    static let lighter: Set<String> = ["light", "pale", "pastel", "hell", "helle", "heller", "helles", "blass", "zart"]

    /// Words of a phrase, lowercased, punctuation removed, German compounds split
    /// ("Dunkelblau" -> "dunkel", "blau"; "hellgrünen" -> "hell", "grün").
    static func words(_ text: String) -> [String] {
        let cleaned = text.lowercased().map { $0.isLetter || $0.isNumber || $0 == "#" ? $0 : " " }
        var out: [String] = []
        for raw in String(cleaned).split(separator: " ").map(String.init) {
            var w = raw
            var prefix: String?
            for p in ["dunkel", "hell", "tief", "zart"] where w.hasPrefix(p) && w.count > p.count {
                prefix = p
                w = String(w.dropFirst(p.count))
            }
            if let prefix { out.append(prefix) }
            out.append(stem(w))
        }
        return out
    }

    /// German adjective endings: "roten" -> "rot", "warmer" -> "warm", "blaue" -> "blau".
    static func stem(_ w: String) -> String {
        if colors[w] != nil || moods.contains(where: { $0.words.contains(w) }) { return w }
        for suffix in ["en", "er", "es", "em", "e"] where w.hasSuffix(suffix) {
            let base = String(w.dropLast(suffix.count))
            if colors[base] != nil || moods.contains(where: { $0.words.contains(base) }) { return base }
        }
        return w
    }

    /// One color from a phrase: "#3366FF", "dark blue", "Dunkelblau", "red.", "warmes Rot".
    static func color(_ text: String) -> RGBA? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let hex = t.hasPrefix("#") ? String(t.dropFirst()) : t
        if (hex.count == 6 || hex.count == 8), hex.allSatisfy(\.isHexDigit) { return RGBA(hex: hex) }
        let ws = words(t)
        if let h = ws.first(where: { $0.hasPrefix("#") }), h.count >= 7, h.dropFirst().allSatisfy(\.isHexDigit) {
            return RGBA(hex: h)
        }
        guard let base = ws.last(where: { colors[$0] != nil }).flatMap({ colors[$0] }) else { return nil }
        return shade(base, ws)
    }

    /// Every color in a phrase, in order ("orange, coral and pink", "von Rot nach Gold").
    static func allColors(_ text: String) -> [RGBA] {
        var out: [RGBA] = []
        var modifiers: [String] = []
        for w in words(text) {
            if darker.contains(w) || lighter.contains(w) { modifiers.append(w); continue }
            if w.hasPrefix("#"), w.count >= 7, w.dropFirst().allSatisfy(\.isHexDigit) { out.append(RGBA(hex: w)); continue }
            if let c = colors[w] { out.append(shade(c, modifiers)); modifiers = [] }
        }
        return out
    }

    private static func shade(_ c: RGBA, _ ws: [String]) -> RGBA {
        if ws.contains(where: darker.contains) { return RGBA(c.r * 0.55, c.g * 0.55, c.b * 0.55) }
        if ws.contains(where: lighter.contains) {
            return RGBA(c.r + (1 - c.r) * 0.55, c.g + (1 - c.g) * 0.55, c.b + (1 - c.b) * 0.55)
        }
        return c
    }

    // MARK: Moods

    enum Mood: String, CaseIterable { case warm, cool, dark, light, pastel, nature }

    static let moods: [(mood: Mood, words: [String], colors: [RGBA])] = [
        (.warm, ["warm", "sunset", "sunrise", "autumn", "fire", "cozy", "sonnenuntergang", "abendrot", "herbst",
                 "feuer", "gemütlich", "glut"],
         [RGBA(0.98, 0.62, 0.24), RGBA(0.98, 0.45, 0.40), RGBA(0.90, 0.32, 0.52)]),
        (.cool, ["cool", "cold", "ocean", "sea", "ice", "water", "frost", "kühl", "kuehl", "kalt", "meer", "ozean",
                 "eis", "wasser"],
         [RGBA(0.22, 0.72, 0.84), RGBA(0.16, 0.32, 0.72)]),
        (.dark, ["night", "midnight", "space", "galaxy", "nacht", "mitternacht", "weltall"],
         [RGBA(0.10, 0.10, 0.28), RGBA(0.36, 0.20, 0.56)]),
        (.pastel, ["pastel", "candy", "sweet", "soft", "bonbon", "sanft", "süß"],
         [RGBA(0.98, 0.74, 0.84), RGBA(0.72, 0.80, 0.98)]),
        (.nature, ["forest", "nature", "leaf", "spring", "wald", "natur", "blatt", "frühling"],
         [RGBA(0.42, 0.72, 0.36), RGBA(0.12, 0.42, 0.30)]),
        (.light, ["bright", "airy", "clean", "freundlich", "luftig", "sauber"],
         [RGBA(0.98, 0.97, 0.94), RGBA(0.86, 0.90, 0.96)]),
    ]

    /// Moods named in a phrase. "dark"/"dunkel" alone counts as dark, "hell"/"light" as light.
    static func moodsIn(_ text: String) -> Set<Mood> {
        let ws = Set(words(text))
        var out = Set(moods.filter { m in m.words.contains(where: ws.contains) }.map(\.mood))
        if ws.contains("dark") || ws.contains("dunkel") { out.insert(.dark) }
        if (ws.contains("light") || ws.contains("hell")) && !ws.contains(where: colors.keys.contains) { out.insert(.light) }
        return out
    }

    /// Colors for a phrase: named colors first ("orange to pink"), otherwise the colors of its mood.
    static func moodColors(_ text: String) -> [RGBA]? {
        let named = allColors(text)
        if !named.isEmpty { return Array(named.prefix(4)) }
        let ws = Set(words(text))
        return moods.first { m in m.words.contains(where: ws.contains) }?.colors
    }

    /// True when the text asks for a color gradient.
    static func wantsGradient(_ text: String) -> Bool {
        let t = text.lowercased()
        return ["gradient", "verlauf", "farbverlauf", "fade", "übergang"].contains { t.contains($0) }
    }

    /// True when the text asks for rounder corners.
    static func wantsRoundCorners(_ text: String) -> Bool {
        let ws = Set(words(text))
        let round = ["round", "rounded", "rund", "runde", "abgerundet", "abgerundete", "weich", "soft"]
        let corner = ["corner", "corners", "ecke", "ecken", "eck"]
        return ws.contains(where: round.contains) && (ws.contains(where: corner.contains) || ws.contains("abgerundet"))
    }

    // MARK: Themes

    /// Short tags for a built-in or custom look, e.g. "warm gradient", "cool animated", "dark texture".
    static func tags(for theme: Theme) -> Set<String> {
        var tags = Set<String>()
        let colors: [RGBA]
        switch theme.style.background {
        case .solid(let c): colors = [c]; tags.insert("solid")
        case .gradient(let cs, _): colors = cs; tags.insert("gradient")
        case .mesh(let cs): colors = cs; tags.insert("gradient")
        case .glass(let tint, _): colors = [RGBA(tint.r, tint.g, tint.b, 1)]; tags.insert("glass")
        case .fx(let p): colors = p.palette; tags.insert("animated")
        case .texture(_, let tint): colors = [tint]; tags.insert("texture")
        case .image: colors = []; tags.insert("photo")
        case .wallpaper: colors = []; tags.insert("glass")
        }
        for m in colorMoods(colors) { tags.insert(m.rawValue) }
        return tags
    }

    /// Moods of a set of colors from their average hue, saturation and brightness.
    static func colorMoods(_ colors: [RGBA]) -> Set<Mood> {
        guard !colors.isEmpty else { return [] }
        var out = Set<Mood>()
        var warm = 0, cool = 0, nature = 0
        var bright = 0.0, sat = 0.0
        for c in colors {
            let ns = NSColor(srgbRed: c.r, green: c.g, blue: c.b, alpha: 1)
            let h = Double(ns.hueComponent), s = Double(ns.saturationComponent), b = Double(ns.brightnessComponent)
            bright += b
            sat += s
            guard s > 0.18, b > 0.15 else { continue }
            if h < 0.13 || h > 0.88 { warm += 1 } else if h < 0.20 { warm += 1 } else if h < 0.42 { nature += 1 } else if h < 0.78 { cool += 1 }
        }
        let n = Double(colors.count)
        bright /= n
        sat /= n
        if warm * 2 > colors.count { out.insert(.warm) }
        if cool * 2 > colors.count { out.insert(.cool) }
        if nature * 2 > colors.count { out.insert(.nature) }
        if bright < 0.35 { out.insert(.dark) }
        if bright > 0.82 { out.insert(.light) }
        if bright > 0.75 && sat > 0.1 && sat < 0.5 { out.insert(.pastel) }
        return out
    }

    // MARK: Value keywords

    /// German (and loose English) values mapped to the English keywords.
    static let keywords: [String: String] = [
        // labels
        "immer": "always", "beim überfahren": "hover", "überfahren": "hover", "hover": "hover", "aus": "off",
        "keine": "off", "ausblenden": "off", "an": "on", "ein": "on",
        // layout
        "raster": "grid", "gitter": "grid", "liste": "list", "kacheln": "tiles", "kachel": "tiles",
        // sizes
        "klein": "small", "kleiner": "small", "mittel": "medium", "groß": "large", "gross": "large",
        "größer": "large", "riesig": "huge",
        // corners
        "eckig": "square", "rund": "round", "runde": "round", "abgerundet": "round", "sehr rund": "very round",
        // spacing
        "eng": "tight", "kompakt": "tight", "luftig": "airy", "weit": "airy",
        // border
        "kein": "none", "ohne": "none", "dünn": "thin", "duenn": "thin", "dick": "thick",
        // appearance
        "hell": "light", "dunkel": "dark",
        // sort
        "manuell": "manual", "art": "kind", "hinzugefügt": "added", "geöffnet": "opened", "benutzt": "used",
        "meistbenutzt": "used", "alphabetisch": "name",
        // dock icon
        "stapel": "stack", "symbol": "symbol", "buchstaben": "monogram",
    ]

    static func keyword(_ value: String) -> String {
        let t = value.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)).lowercased()
        return keywords[t] ?? t
    }

    // MARK: Intent

    static let editWords: Set<String> = [
        // English
        "make", "use", "change", "set", "add", "put", "include", "remove", "delete", "rename", "call", "name", "sort",
        "look", "theme", "style", "color", "colour", "fill", "gradient", "glass", "border", "frame", "label", "labels",
        "layout", "list", "grid", "tiles", "column", "columns", "icon", "icons", "bigger", "smaller", "size", "corner",
        "corners", "round", "square", "spacing", "shadow", "emoji", "dock", "appearance", "dark", "light", "hover",
        "app", "apps", "transparent", "background",
        // German
        "mach", "mache", "verwende", "nimm", "nutze", "ändere", "setze", "füge", "hinzu", "entferne", "lösche",
        "nenne", "benenne", "heißen", "sortiere", "aussehen", "thema", "stil", "farbe", "füllung", "verlauf",
        "farbverlauf", "glas", "rahmen", "beschriftung", "beschriftungen", "namen", "liste", "raster", "kacheln",
        "spalte", "spalten", "symbol", "symbole", "größer", "kleiner", "größe", "ecke", "ecken", "rund", "runde",
        "eckig", "abstand", "schatten", "hintergrund", "dunkel", "hell", "durchsichtig",
    ]

    static let removeWords: Set<String> = ["remove", "delete", "drop", "entferne", "entfernen", "lösche", "löschen", "raus", "weg"]

    /// True when the request asks to change the group (not a general question like the weather).
    static func isEditRequest(_ request: String) -> Bool {
        let ws = words(request)
        if ws.contains(where: editWords.contains) { return true }
        if ws.contains(where: { colors[$0] != nil }) { return true }
        return !moodsIn(request).isEmpty
    }

    /// True when the request asks to remove something. Removals the model invents otherwise are dropped.
    static func asksToRemove(_ request: String) -> Bool {
        words(request).contains(where: removeWords.contains) || request.lowercased().contains("take out")
    }

    // MARK: Reply language

    /// Language the reply should use: the language of the request, else the app's localization.
    static func replyLanguage(for request: String, fallback: String? = Bundle.main.preferredLocalizations.first) -> String {
        let recognizer = NLLanguageRecognizer()
        recognizer.languageConstraints = [.german, .english, .french, .spanish, .italian, .dutch]
        recognizer.processString(request)
        let code: String?
        if let (lang, p) = recognizer.languageHypotheses(withMaximum: 1).first, p > 0.6, request.split(separator: " ").count >= 2 {
            code = lang.rawValue
        } else {
            code = fallback ?? Locale.current.language.languageCode?.identifier
        }
        return Locale(identifier: "en").localizedString(forLanguageCode: code ?? "en") ?? "English"
    }
}
