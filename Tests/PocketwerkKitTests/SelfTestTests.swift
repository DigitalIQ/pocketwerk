import Foundation
import Testing
@testable import PocketwerkKit

@Suite struct SelfTestTests {
    let home = FileManager.default.homeDirectoryForCurrentUser.path

    func env(data: String = "/repo/.tmp/selftest/data", dock: String = "/repo/.tmp/selftest/dock.plist",
             launchers: String = "/repo/.tmp/selftest/launchers") -> [String: String] {
        ["POCKETWERK_DATA_DIR": data, "POCKETWERK_DOCK_PLIST": dock, "POCKETWERK_LAUNCHER_DIR": launchers]
    }

    @Test func acceptsTestFolders() {
        #expect(SelfTest.unsafeEnvironment(env()) == nil)
    }

    @Test func refusesMissingOrRealLocations() {
        var missing = env()
        missing["POCKETWERK_DOCK_PLIST"] = nil
        #expect(SelfTest.unsafeEnvironment(missing) != nil)
        #expect(SelfTest.unsafeEnvironment(env(launchers: home + "/Applications/Pocketwerk")) != nil)
        #expect(SelfTest.unsafeEnvironment(env(data: home + "/Library/Application Support/Pocketwerk")) != nil)
        #expect(SelfTest.unsafeEnvironment(env(dock: home + "/Library/Preferences/com.apple.dock.plist")) != nil)
        #expect(SelfTest.unsafeEnvironment(env(data: "/repo/data")) != nil)
        #expect(SelfTest.unsafeEnvironment(env(data: "relative/.tmp/data")) != nil)
    }
}
