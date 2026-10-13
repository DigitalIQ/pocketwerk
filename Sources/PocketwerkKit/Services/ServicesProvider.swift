import AppKit

// OWNER: app agent. Placeholder with the final API.

/// macOS Services menu entry "Zu Pocketwerk hinzufügen" for URLs, text with URLs, and files.
final class ServicesProvider: NSObject {
    static let shared = ServicesProvider()

    func register() {
        NSApp.servicesProvider = self
    }
}
