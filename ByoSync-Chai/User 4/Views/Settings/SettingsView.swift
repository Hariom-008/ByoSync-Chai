import SwiftUI

struct SettingsView: View {
    @AppStorage("selectedLanguage") private var selectedLanguage: String = "en"
    @EnvironmentObject private var languageManager: LanguageManager
    @Environment(\.dismiss) private var dismiss

    let languages: [(code: String, name: String)] = [
        ("en", "English"),
        ("hi", "हिन्दी (Hindi)"),
        ("ml", "മലയാളം (Malayalam)"),
        ("ta", "தமிழ் (Tamil)"),
        ("bn", "বাংলা (Bangla)"),
        ("mr", "मराठी (Marathi)")
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(L("App Language"))) {
                    Picker(L("Select Language"), selection: $selectedLanguage) {
                        ForEach(languages, id: \.code) { language in
                            HStack {
                                Text(language.name)
                            }
                            .tag(language.code)
                        }
                    }
                    .pickerStyle(.inline)
                }
                
                Section {
                    Button(L("Apply Language")) {
                        applyLanguageChange()
                    }
                }
            }
            .navigationTitle(L("Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.primary)
                            .padding(10)
                    }
                }
            }
        }
        // 👇 Log language change detection
        .onChange(of: languageManager.currentLanguageCode) { newValue in
            print("🌏 [SettingsView] Detected language change → \(newValue)")
        }
        .environment(\.locale, .init(identifier: languageManager.currentLanguageCode))
    }
    
    private func applyLanguageChange() {
        let language = selectedLanguage
        print("⚙️ [SettingsView] Applying language change → \(language)")
        languageManager.setLanguage(language)
        
        // Sync to AppleLanguages for consistency
        UserDefaults.standard.set([language], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
        
        print("✅ [SettingsView] Language applied and saved: \(language)")
    }
}

#Preview {
    SettingsView()
}
