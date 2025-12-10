import Foundation
import SwiftUI
import Combine

@MainActor
final class UpdateProfileViewModel: ObservableObject {
    @Published var firstName: String = ""
    @Published var lastName: String = ""
    @Published var email: String = ""
    @Published var alertTitle: String = ""
    @Published var showAlert: Bool = false
    @Published var alertMessage: String = ""
    @Published var isLoading: Bool = false
    @Published var isSuccess: Bool = false
    
    // Dependencies
    private let repository: ProfileUpdateRepositoryProtocol
    private let userSession: UserSession
    
    // Store original email to detect change
    private var originalEmail: String = ""
    
    // MARK: - Initialization with Dependency Injection
    init(
        repository: ProfileUpdateRepositoryProtocol = ProfileUpdateRepository(),
        userSession: UserSession = .shared
    ) {
        self.repository = repository
        self.userSession = userSession
        self.originalEmail = userSession.currentUser?.email ?? ""
        print("🏗️ [VM] UpdateProfileViewModel initialized")
    }
    
    func updateProfile() {
        print("\n" + String(repeating: "=", count: 50))
        print("🧪 [VM] Starting Updating UserProfile")
        print(String(repeating: "=", count: 50))
        
        guard let token = UserDefaults.standard.string(forKey: "token") else {
            print("❌ [VM] NO TOKEN FOUND - API will fail!")
            alertTitle = "Error"
            alertMessage = "No token found. Please login first."
            showAlert = true
            return
        }
        
        print("✅ [VM] Token found: \(token.prefix(20))...")
        isLoading = true
        
        repository.updateProfile(
            firstName: firstName,
            lastName: lastName,
            email: email
        ) { [weak self] result in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.isLoading = false
                
                switch result {
                case .success(let response):
                    print("✅ [VM] UPDATE SUCCESS!")
                    print("📊 [VM] Status Code: \(response.statusCode)")
                    print("💬 [VM] Message: \(response.message)")
                    print("👤 [VM] User: \(response.data.firstName) \(response.data.lastName)")
                    print("📧 [VM] Email: \(response.data.email)")
                    
                    // Check if email actually changed
                    let oldEmail = self.originalEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    let newEmail = self.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    
                    if oldEmail != newEmail {
                        self.userSession.setEmailVerified(false)
                        print("📧 [VM] Email changed — verification reset to false")
                    }
                    
                    self.alertTitle = "Success ✅"
                    self.alertMessage = """
                       \(response.message)
                       Updated Profile:
                       Name: \(response.data.firstName) \(response.data.lastName)
                       Email: \(response.data.email)
                       """
                    self.showAlert = true
                    self.isSuccess = true
                    
                    // Update user session
                    self.userSession.saveUser(
                        User(
                            firstName: self.firstName,
                            lastName: self.lastName,
                            email: self.email,
                            phoneNumber: self.userSession.currentUser?.phoneNumber,
                            deviceKey: self.userSession.currentUser?.deviceKey,
                            deviceName: self.userSession.currentUser?.deviceName
                        )
                    )
                    print("✅ [VM] Updated the user on backend and UserSession.")
                    
                case .failure(let error):
                    print("❌ [VM] UPDATE FAILED!")
                    print("🔥 [VM] Error: \(error.localizedDescription)")
                    
                    self.alertTitle = "Error ❌"
                    self.alertMessage = error.localizedDescription
                    self.showAlert = true
                }
            }
        }
    }
    
    deinit {
        print("♻️ [VM] UpdateProfileViewModel deallocated")
    }
}
