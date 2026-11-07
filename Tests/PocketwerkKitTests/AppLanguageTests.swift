import Foundation
import Testing
@testable import PocketwerkKit

@Suite(.serialized) struct AppLanguageTests {
    @Test func storesChoiceInOwnDefaults() {
        let before = CFPreferencesCopyValue(AppLanguage.defaultsKey as CFString, kCFPreferencesCurrentApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        defer {
            if let before { UserDefaults.standard.set(before, forKey: AppLanguage.defaultsKey) }
            else { UserDefaults.standard.removeObject(forKey: AppLanguage.defaultsKey) }
        }
        AppLanguage.store(.german)
        #expect(AppLanguage.current == .german)
        #expect(UserDefaults.standard.stringArray(forKey: AppLanguage.defaultsKey) == ["de"])
        AppLanguage.store(.english)
        #expect(AppLanguage.current == .english)
        AppLanguage.store(.system)
        #expect(AppLanguage.current == .system)
    }

    @Test func everyLanguageHasACatalogEntry() throws {
        // The app ships English and German; the picker must offer exactly those plus the system choice.
        #expect(AppLanguage.allCases.map(\.rawValue) == ["system", "en", "de"])
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("Resources/Localization/Localizable.xcstrings"))
        let catalog = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try #require(catalog["strings"] as? [String: [String: Any]])
        let missing = strings.filter { key, value in
            (value["shouldTranslate"] as? Bool ?? true) && !key.isEmpty
                && (value["localizations"] as? [String: Any])?["de"] == nil
        }.map(\.key)
        #expect(missing.isEmpty, "Strings without German: \(missing.prefix(5))")
    }
}
