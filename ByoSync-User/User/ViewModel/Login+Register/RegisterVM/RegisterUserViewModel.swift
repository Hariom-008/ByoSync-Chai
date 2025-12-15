import Foundation
import Combine
import UIKit

final class RegisterUserViewModel: ObservableObject {

    // MARK: - Inputs
    @Published var firstName = ""
    @Published var lastName = ""
    @Published var email = ""
    @Published var phoneNumber = ""

    // MARK: - UI State
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var navigateToMainTab = false

    // MARK: - Device Identity
    @Published private(set) var deviceId: String
    @Published private(set) var deviceName: String

    private let repository: RegisterUserRepository

    // MARK: - Init
    init(cryptoService: CryptoService) {
        self.repository = RegisterUserRepository(cryptoService: cryptoService)
        self.deviceId = DeviceIdentity.resolve()
        self.deviceName = UIDevice.current.model
    }

    // MARK: - Validation
    var allFieldsFilled: Bool {
        !firstName.isEmpty &&
        !lastName.isEmpty &&
        !email.isEmpty &&
        !phoneNumber.isEmpty
    }

    var isValidEmail: Bool {
        NSPredicate(
            format: "SELF MATCHES %@",
            "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        ).evaluate(with: email)
    }

    var canSubmit: Bool { allFieldsFilled && isValidEmail }

    // MARK: - Register
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

    // MARK: - Result Handling
    private func handleRegistrationResult(
        _ result: Result<APIResponse<RegisterUserData>, APIError>
    ) {
        switch result {

        case .success(let response):
            guard
                let userData = response.data?.newUser,
                let device = response.data?.newDevice
            else {
                showErrorMessage("Invalid server response.")
                return
            }

            let user = User(
                firstName: firstName,
                lastName: lastName,
                email: email,
                phoneNumber: phoneNumber,
                deviceKey: device.deviceKey,
                deviceName: device.deviceName,
                userId: userData.id,
                userDeviceId: device.id
            )

            UserDefaults.standard.set(device.token, forKey: "token")
            UserDefaults.standard.set("user", forKey: "accountType")

            UserSession.shared.saveUser(user)
            UserSession.shared.setCurrentDeviceID(device.id)
            UserSession.shared.setThisDevicePrimary(device.isPrimary)
            UserSession.shared.setUserWallet(userData.wallet)
            UserSession.shared.setEmailVerified(userData.emailVerified)
            UserSession.shared.setProfilePicture(userData.profilePic ?? "")

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
}
