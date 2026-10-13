import AppKit
import SwiftUI

/// Small floating list of the keys that can follow (leader key and key sequences).
/// Never takes focus; disappears when the sequence ends.
final class LeaderHUD {
    static let shared = LeaderHUD()
    private var panel: NSPanel?

    func show(options: [(key: String, title: String)]) {
        guard !options.isEmpty else { hide(); return }
        let view = NSHostingView(rootView: LeaderHUDView(options: options.map { LeaderOption(key: $0.key, title: $0.title) }))
        let size = view.fittingSize
        let p = panel ?? NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        p.isFloatingPanel = true
        p.level = .popUpMenu
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = true
        p.ignoresMouseEvents = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        p.contentView = view
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        if let f = screen?.visibleFrame {
            p.setFrame(NSRect(x: f.midX - size.width / 2, y: f.midY + f.height * 0.15, width: size.width, height: size.height),
                       display: true)
        }
        p.orderFrontRegardless()
        panel = p
        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested,
                             userInfo: [.announcement: options.map { "\($0.key) \($0.title)" }.joined(separator: ", "),
                                        .priority: NSAccessibilityPriorityLevel.high.rawValue])
    }

    func hide() {
        panel?.orderOut(nil)
    }
}

struct LeaderOption: Identifiable {
    let key: String
    let title: String
    var id: String { key + title }
}

struct LeaderHUDView: View {
    let options: [LeaderOption]
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(options.prefix(20)) { o in
                HStack(spacing: 10) {
                    Text(o.key).font(.body.monospaced().weight(.semibold)).frame(minWidth: 28)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))
                    Text(o.title).lineLimit(1)
                }
            }
        }
        .padding(14)
        .background(reduceTransparency ? AnyShapeStyle(Color(nsColor: .windowBackgroundColor)) : AnyShapeStyle(.regularMaterial),
                    in: RoundedRectangle(cornerRadius: 12))
        .fixedSize()
    }
}
