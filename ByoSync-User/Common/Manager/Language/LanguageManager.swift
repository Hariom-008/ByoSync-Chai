import Foundation
import Combine
import SwiftUI

class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    @Published var currentLanguageCode: String = UserDefaults.standard.string(forKey: "AppLanguage") ?? "en"
    private var bundle: Bundle?

    private init() {
        print("🌐 LanguageManager initialized with language: \(currentLanguageCode)")
        setLanguage(currentLanguageCode)
    }

    func setLanguage(_ languageCode: String) {
        print("🗣️ Requested language change to: \(languageCode)")
        currentLanguageCode = languageCode
        UserDefaults.standard.set(languageCode, forKey: "AppLanguage")

        if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj") {
            print("📁 Found .lproj path for \(languageCode): \(path)")
            if let langBundle = Bundle(path: path) {
                bundle = langBundle
                print("✅ Language bundle successfully loaded for: \(languageCode)")
            } else {
                print("⚠️ Failed to initialize bundle for language: \(languageCode)")
                bundle = .main
            }
        } else {
            print("❌ No localization folder found for language: \(languageCode), falling back to main bundle.")
            bundle = .main
        }

        // Notify SwiftUI to update
        objectWillChange.send()
        print("🔁 objectWillChange triggered → SwiftUI views should refresh.")
        print("🌍 Active language is now: \(currentLanguageCode)\n")
    }

    func localizedString(forKey key: String) -> String {
        let localized = bundle?.localizedString(forKey: key, value: nil, table: nil)
        ?? NSLocalizedString(key, comment: "")
        return localized
    }
}

/// Global shortcut function for localized text
func L(_ key: String) -> String {
    LanguageManager.shared.localizedString(forKey: key)
}
