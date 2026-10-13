import AppKit
import PocketwerkShared

// OWNER: dock agent. Minimal working launcher: forwards the click to the main app and quits.

let info = Bundle.main.infoDictionary ?? [:]
let slotID = info[PWShared.slotInfoKey] as? String ?? ""

if NSRunningApplication.runningApplications(withBundleIdentifier: PWShared.mainBundleID).isEmpty {
    NSWorkspace.shared.open(PWShared.openURL(slotID: slotID))
} else {
    DistributedNotificationCenter.default().postNotificationName(
        PWShared.openSlotNotification, object: slotID, userInfo: nil, deliverImmediately: true)
}
exit(0)
