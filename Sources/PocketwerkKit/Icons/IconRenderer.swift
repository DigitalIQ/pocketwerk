import AppKit

// OWNER: dock agent. Placeholder with the final API.

enum IconRenderer {
    /// Icon of a single item (app icon, file icon, folder icon, favicon for links).
    static func icon(for item: DockItem, size: CGFloat) -> NSImage {
        let img: NSImage
        switch item.kind {
        case .link:
            img = NSImage(systemSymbolName: "globe", accessibilityDescription: nil) ?? NSImage()
        default:
            img = NSWorkspace.shared.icon(forFile: item.url.path)
        }
        img.size = NSSize(width: size, height: size)
        return img
    }

    /// Dock icon / folder icon for a group, drawn from its IconSpec and style.
    static func groupIcon(_ group: ItemGroup, size: CGFloat) -> NSImage {
        render(spec: group.icon, style: group.style, name: group.name, items: group.items, size: size)
    }

    /// Dock icon for a slot: slot.icon if set, else the first group's icon.
    static func slotIcon(_ slot: DockSlot, library: Library, size: CGFloat) -> NSImage {
        let groups = slot.groupIDs.compactMap { library.group($0) }
        let first = groups.first ?? ItemGroup(name: slot.name)
        let spec = slot.icon ?? first.icon
        return render(spec: spec, style: first.style, name: slot.name, items: groups.flatMap(\.items), size: size)
    }

    static func render(spec: IconSpec, style: GroupStyle, name: String, items: [DockItem], size: CGFloat) -> NSImage {
        NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            NSColor.darkGray.setFill()
            NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.1, dy: size * 0.1), xRadius: size * 0.2, yRadius: size * 0.2).fill()
            return true
        }
    }
}
