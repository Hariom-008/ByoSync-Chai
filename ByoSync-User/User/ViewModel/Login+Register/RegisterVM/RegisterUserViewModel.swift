import Foundation
import Combine
import UIKit

final class RegisterUserViewModel: ObservableObject {
    @Published var firstName: String = ""
    @Published var lastName: String = ""
    @Published var email: String = ""
    @Published var phoneNumber: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    @Published var navigateToMainTab: Bool = false
    @Published var deviceId: String = "1234abcde"
    @Published var deviceName: String = "iPhone 11"
    
    private let repository: RegisterUserRepository
    
    init(cryptoService: CryptoService) {
        self.repository = RegisterUserRepository(cryptoService: cryptoService)
    }
    
    // MARK: - Validation
    var allFieldsFilled: Bool {
        !firstName.isEmpty &&
        !lastName.isEmpty &&
        !email.isEmpty &&
        !phoneNumber.isEmpty
    }
    
    var isValidEmail: Bool {
        let regex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        return NSPredicate(format:"SELF MATCHES %@", regex).evaluate(with: email)
    }
    
    var canSubmit: Bool { allFieldsFilled && isValidEmail }
    
    // MARK: - Register User
    func registerUser() {
        guard canSubmit else {
            showErrorMessage("Please fill all fields correctly.")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        repository.registerUser(
            firstName: firstName,
            lastName: lastName,
            email: email,
            phoneNumber: phoneNumber,
            deviceId: deviceId,
            deviceName: deviceName
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                self?.handleRegistrationResult(result)
            }
        }
    }
    
    // MARK: - Handle Result
    private func handleRegistrationResult(
        _ result: Result<APIResponse<RegisterUserData>, APIError>
    ) {
        switch result {
        case .success(let response):
            guard
                let userData = response.data?.newUser,
                let device = response.data?.newDevice
            else {
                showErrorMessage("Unexpected error: missing user/device data.")
                return
            }
            
            print("✅ Registration successful")

            // 1️⃣ Save user from backend (better than using plaintext inputs)
            let registeredUser = User(
                firstName: firstName,         // or decrypt(userData.firstName) if you later add decryption
                lastName: lastName,
                email: email,
                phoneNumber: phoneNumber,
                deviceKey: device.deviceKey,
                deviceName: device.deviceName,
                userId: userData.id,
                userDeviceId: device.id
            )
            
            UserDefaults.standard.set(device.token, forKey: "token")
            print("✅ Token Saved in UserDefaults")
            KeychainHelper.shared.save("deviceKey", forKey: device.deviceKey)
            print("🔐 Saved deviceKey to Keychain with key: \(device.deviceKey)")
            
            UserSession.shared.saveUser(registeredUser)
            UserSession.shared.setCurrentDeviceID(device.id)
            UserSession.shared.setThisDevicePrimary(device.isPrimary)
            UserSession.shared.setUserWallet(userData.wallet)
            UserSession.shared.setEmailVerified(userData.emailVerified)
            UserSession.shared.setProfilePicture(userData.profilePic ?? "")
            UserSession.shared.setDeviceKey(device.deviceKey)

            if !device.token.isEmpty {
                UserDefaults.standard.set(device.token, forKey: "token")
            }

            // 2️⃣ Mark this account as a "user" so RootView nextStep() passes the first guard
            UserDefaults.standard.set("user", forKey: "accountType")

            print("💾 User + Device saved to session successfully")

            // 3️⃣ You don't actually need navigateToMainTab for RootView,
            //    RootView will react when currentUser changes and accountType is set.
            //    But if you still use it for local Router-based transitions, keep it:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.navigateToMainTab = true
            }

        case .failure(let error):
            showErrorMessage(error.localizedDescription)
        }
    }
    
    // MARK: - Helpers
    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }
    
    func clearForm() {
        firstName = ""
        lastName = ""
        email = ""
        phoneNumber = ""
        errorMessage = nil
        showError = false
        navigateToMainTab = false
    }
}
