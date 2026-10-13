import AppKit

/// How the symbols of a pack are drawn.
enum SymbolFinish: String, Sendable {
    /// Soft gradient with a drop shadow, looks raised.
    case embossed
    /// One flat color.
    case flat
    /// Two tones of the foreground color.
    case duotone
    /// The symbol's own colors where it has them.
    case multicolor
}

/// A themed set of SF Symbols offered for symbol icons.
struct IconPack: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let finish: SymbolFinish
    let symbols: [String]
}

enum IconPacks {
    static let all: [IconPack] = [
        IconPack(id: "objects", name: "Objects", finish: .embossed, symbols: [
            "heart.fill", "star.fill", "bolt.fill", "flame.fill", "trophy.fill", "camera.fill", "gift.fill", "crown.fill",
            "bell.fill", "bookmark.fill", "lightbulb.fill", "key.fill", "lock.fill", "paperplane.fill", "gamecontroller.fill",
            "headphones", "music.note", "paintbrush.fill", "scissors", "hammer.fill", "wrench.and.screwdriver.fill",
            "puzzlepiece.fill", "cube.fill", "diamond.fill", "balloon.fill", "cup.and.saucer.fill", "fork.knife",
            "birthday.cake.fill", "safari.fill", "globe.americas.fill", "map.fill", "tag.fill", "magnifyingglass",
            "eyeglasses", "umbrella.fill", "sparkles",
        ]),
        IconPack(id: "work", name: "Work", finish: .flat, symbols: [
            "folder.fill", "doc.text.fill", "tray.full.fill", "archivebox.fill", "calendar", "clock.fill", "chart.bar.fill",
            "chart.pie.fill", "briefcase.fill", "envelope.fill", "phone.fill", "person.2.fill", "terminal.fill",
            "chevron.left.forwardslash.chevron.right", "server.rack", "externaldrive.fill", "cpu.fill", "network",
            "keyboard.fill", "printer.fill", "pencil.and.ruler.fill", "list.bullet.rectangle.fill", "checkmark.seal.fill",
            "building.2.fill",
        ]),
        IconPack(id: "nature", name: "Nature", finish: .duotone, symbols: [
            "leaf.fill", "tree.fill", "camera.macro", "sun.max.fill", "moon.stars.fill", "cloud.sun.fill", "cloud.rain.fill",
            "snowflake", "drop.fill", "mountain.2.fill", "water.waves", "tortoise.fill", "hare.fill", "bird.fill", "fish.fill",
            "pawprint.fill", "ladybug.fill", "ant.fill", "carrot.fill", "globe.europe.africa.fill", "wind", "tornado",
            "sparkle", "flame.fill",
        ]),
        IconPack(id: "play", name: "Play", finish: .multicolor, symbols: [
            "gamecontroller.fill", "die.face.5.fill", "suit.heart.fill", "suit.spade.fill", "film.fill", "tv.fill",
            "popcorn.fill", "music.mic", "guitars.fill", "theatermasks.fill", "figure.run", "soccerball", "basketball.fill",
            "tennisball.fill", "football.fill", "bicycle", "car.fill", "airplane", "sailboat.fill", "tent.fill",
            "beach.umbrella.fill", "party.popper.fill", "headphones", "book.fill",
        ]),
    ]

    /// The pack with this id, or the first pack.
    static func pack(id: String?) -> IconPack { all.first { $0.id == id } ?? all[0] }
}
