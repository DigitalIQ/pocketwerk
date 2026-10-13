import AppKit
import QuickLookUI
import SwiftUI

/// Quick Look preview next to the popup, with Reveal in Finder, Open and Close.
/// An own panel with QLPreviewView: the shared preview panel needs an active app,
/// which a non-activating popup is not.
final class QuickLookPanel {
    static let shared = QuickLookPanel()

    let panel: NSPanel
    private let preview: QLPreviewView
    private let header: NSHostingView<QuickLookHeader>
    private(set) weak var owner: NSWindow?
    private(set) var item: DockItem?

    var isVisible: Bool { panel.isVisible }

    private init() {
        panel = QuickLookWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 440),
                                styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.animationBehavior = .none

        let root = NSVisualEffectView()
        root.material = .popover
        root.state = .active
        root.wantsLayer = true
        root.layer?.cornerRadius = 16
        root.layer?.masksToBounds = true
        preview = QLPreviewView(frame: .zero, style: .normal)!
        preview.autostarts = true
        header = NSHostingView(rootView: QuickLookHeader(title: ""))
        header.sizingOptions = []
        root.addSubview(header)
        root.addSubview(preview)
        header.translatesAutoresizingMaskIntoConstraints = false
        preview.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: root.topAnchor),
            header.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 38),
            preview.topAnchor.constraint(equalTo: header.bottomAnchor),
            preview.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            preview.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            preview.bottomAnchor.constraint(equalTo: root.bottomAnchor),
        ])
        panel.contentView = root
    }

    /// Shows the item, or closes the preview when it already shows this item.
    func toggle(_ item: DockItem, beside window: NSWindow) {
        if isVisible, self.item?.url == item.url { close(); return }
        show(item, beside: window)
    }

    func show(_ item: DockItem, beside window: NSWindow) {
        self.item = item
        owner = window
        preview.previewItem = (item.kind == .app ? ItemOpener.appURL(for: item) : item.url) as NSURL
        header.rootView = QuickLookHeader(title: item.displayName, isLink: item.kind == .link)
        reposition()
        panel.orderFrontRegardless()
    }

    func close() {
        panel.orderOut(nil)
        preview.previewItem = nil
        item = nil
        owner = nil
    }

    /// Next to the popup on the side with more room, aligned with its bottom edge.
    func reposition() {
        guard let owner else { return }
        let screen = (owner.screen ?? NSScreen.main)?.visibleFrame ?? owner.frame
        let size = CGSize(width: min(560, screen.width * 0.45), height: min(460, screen.height * 0.7))
        let o = owner.frame
        let roomRight = screen.maxX - o.maxX, roomLeft = o.minX - screen.minX
        var frame = CGRect(origin: .zero, size: size)
        if roomRight >= size.width + 12 || roomRight >= roomLeft {
            frame.origin = CGPoint(x: o.maxX + 10, y: o.minY)
        } else {
            frame.origin = CGPoint(x: o.minX - 10 - size.width, y: o.minY)
        }
        panel.setFrame(DockGeometry.clamp(frame, into: screen, margin: DockGeometry.margin), display: true)
    }

    fileprivate func reveal() {
        guard let item else { return }
        ItemOpener.revealInFinder([item])
        close()
    }

    fileprivate func openItem() {
        guard let item else { return }
        if item.kind == .app {
            NSWorkspace.shared.openApplication(at: ItemOpener.appURL(for: item), configuration: .init())
        } else {
            NSWorkspace.shared.open(item.url)
        }
        close()
    }
}

/// Never takes key focus, so the popup keeps the keyboard.
private final class QuickLookWindow: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

struct QuickLookHeader: View {
    var title: String
    var isLink = false

    var body: some View {
        HStack(spacing: 8) {
            Text(title).font(.headline).lineLimit(1).truncationMode(.middle)
            Spacer()
            if !isLink {
                Button { QuickLookPanel.shared.reveal() } label: { Image(systemName: "folder") }
                    .help("Show in Finder").accessibilityLabel("Show in Finder")
            }
            Button { QuickLookPanel.shared.openItem() } label: { Image(systemName: "arrow.up.forward.app") }
                .help("Open").accessibilityLabel("Open")
            Button { QuickLookPanel.shared.close() } label: { Image(systemName: "xmark") }
                .help("Close").accessibilityLabel("Close")
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 14)
        .frame(maxHeight: .infinity)
    }
}
