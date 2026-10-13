import Foundation

/// Identifiers shared by the main app and the generated Dock launchers.
public enum PWShared {
    public static let mainBundleID = "io.github.digitaliq.pocketwerk"
    /// Each launcher gets `launcherBundleIDPrefix + slotID.uuidString`.
    public static let launcherBundleIDPrefix = "io.github.digitaliq.pocketwerk.slot."
    public static let urlScheme = "pocketwerk"
    /// Distributed notification a launcher posts when its Dock icon is clicked.
    /// `object` is the slot UUID string. userInfo may carry "x"/"y" (mouse location, Cocoa coords).
    public static let openSlotNotification = Notification.Name("io.github.digitaliq.pocketwerk.openSlot")
    /// Main app posts this when a slot's icon changed, `object` = slot UUID string.
    public static let iconChangedNotification = Notification.Name("io.github.digitaliq.pocketwerk.iconChanged")
    /// Info.plist key inside a launcher bundle that holds the slot UUID.
    public static let slotInfoKey = "PWSlotID"
    /// Info.plist key inside a launcher bundle that holds the main app path (fallback for launching it).
    public static let mainAppPathInfoKey = "PWMainAppPath"

    /// `pocketwerk://open?slot=<uuid>`
    public static func openURL(slotID: String) -> URL {
        var c = URLComponents()
        c.scheme = urlScheme
        c.host = "open"
        c.queryItems = [URLQueryItem(name: "slot", value: slotID)]
        return c.url!
    }
}
