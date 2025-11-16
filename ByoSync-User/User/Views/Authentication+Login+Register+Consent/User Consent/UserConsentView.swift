import SwiftUI

struct UserConsentView: View {
    var onComplete: () -> Void
    
    @State private var isConsentGiven = false
    @State private var isTermsAccepted = false
    @State private var showAlert = false

    @ObservedObject private var langManager = LanguageManager.shared

    let languageMap: [String: String] = [
        "English": "en",
        "हिन्दी": "hi",
        "Bengali": "bn",
        "Tamil": "ta",
        "Marathi": "mr",
        "Malayalam": "ml"
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                
                // Header
                Text(L("welcome_title")).font(.title2).bold()
                Text(L("welcome_subtitle")).font(.headline)
                Text(L("welcome_tagline"))

                // Language picker
                Picker(L("language_label"), selection: Binding(
                    get: { languageName(for: langManager.currentLanguageCode) },
                    set: { newName in
                        if let code = languageMap[newName] {
                            langManager.setLanguage(code)
                        }
                    }
                )) {
                    ForEach(languageMap.keys.sorted(), id: \.self) { lang in
                        Text(lang)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .padding(.vertical, 5)

                Divider()

                // Consent sections
                Group {
                    sectionHeader(L("before_you_begin"))
                    sectionText(L("before_you_begin_text"))
                    
                    sectionHeader(L("eligibility"))
                    sectionText(L("eligibility_text"))
                    
                    sectionHeader(L("what_you_agree_to"))
                    sectionText(L("what_you_agree_to_text"))
                    
                    sectionHeader(L("identity_verification"))
                    sectionText(L("identity_verification_text"))
                    
                    sectionHeader(L("what_we_need"))
                    sectionText(L("what_we_need_text"))

                    Toggle(isOn: $isConsentGiven) {
                        Text(L("consent_checkbox")).font(.subheadline)
                    }

                    sectionHeader(L("your_rights"))
                    sectionText(L("your_rights_text"))
                    
                    sectionHeader(L("security_notice"))
                    sectionText(L("security_notice_text"))
                    
                    sectionHeader(L("data_localization"))
                    sectionText(L("data_localization_text"))
                    
                    sectionHeader(L("roles_contacts"))
                    sectionText(L("roles_contacts_text"))
                    
                    sectionHeader(L("quick_summary"))
                    sectionText(L("quick_summary_text"))

                    Toggle(isOn: $isTermsAccepted) {
                        Text(L("terms_checkbox")).font(.subheadline)
                    }
                }

                // Action buttons
                HStack {
                    Button(L("decline_button")) {
                        showAlert = true
                    }
                    .foregroundColor(.red)

                    Spacer()

                    Button(L("accept_button")) {
                        if isConsentGiven && isTermsAccepted {
                            // Call the completion handler to navigate to MainTabView
                            onComplete()
                        } else {
                            showAlert = true
                        }
                    }
                    .disabled(!isConsentGiven || !isTermsAccepted)
                    .buttonStyle(.borderedProminent)
                }
                .padding(.vertical)
            }
            .padding()
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(L("alert_title")),
                message: Text(L("alert_message")),
                dismissButton: .default(Text(L("alert_ok")))
            )
        }
    }

    // MARK: - Helpers
    private func sectionHeader(_ text: String) -> some View {
        Text(text).font(.headline).padding(.top, 4)
    }

    private func sectionText(_ text: String) -> some View {
        Text(text).fixedSize(horizontal: false, vertical: true)
    }

    private func languageName(for code: String) -> String {
        languageMap.first(where: { $0.value == code })?.key ?? "English"
    }
}

#Preview {
    UserConsentView(onComplete: {})
}
