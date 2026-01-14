import Foundation
import Combine
import UIKit

final class RegisterUserViewModel: ObservableObject {

    // MARK: - Dependencies
    private let cryptoService: any CryptoService
    private let repository: RegisterUserRepository

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

    // MARK: - Init
    init(cryptoService: any CryptoService) {
        self.cryptoService = cryptoService
        self.repository = RegisterUserRepository(cryptoService: cryptoService)
        self.deviceId = DeviceIdentity.resolve()
        self.deviceName = UIDevice.current.model

        #if DEBUG
        print("🎯 [VM] RegisterUserViewModel initialized with crypto service")
        #endif

        Logger.shared.d(
            "REGISTER",
            "RegisterUserViewModel init | deviceName=\(deviceName) | deviceIdPresent=\(!deviceId.isEmpty)",
            user: UserSession.shared.currentUser?.userId
        )
    }

    // MARK: - Validation
    private var trimmedFirstName: String { firstName.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedLastName: String  { lastName.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedEmail: String     { email.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedPhone: String     { phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines) }

    var allFieldsFilled: Bool {
        !trimmedFirstName.isEmpty &&
        !trimmedLastName.isEmpty &&
        !trimmedEmail.isEmpty &&
        !trimmedPhone.isEmpty
    }

    var isValidEmail: Bool {
        NSPredicate(
            format: "SELF MATCHES %@",
            "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        ).evaluate(with: trimmedEmail)
    }

    var canSubmit: Bool { allFieldsFilled && isValidEmail }

    // MARK: - Register
    func registerUser() {
        // Fail fast if deviceId missing (prevents silent backend weirdness)
        guard !deviceId.isEmpty else {
            showErrorMessage("Device identifier unavailable.")
            Logger.shared.e(
                "REGISTER VM",
                "DeviceIdentity.resolve() returned empty deviceId",
                user: UserSession.shared.currentUser?.userId
            )
            return
        }

        guard canSubmit else {
            showErrorMessage("Please fill all fields correctly.")

            let missing = [
                trimmedFirstName.isEmpty ? "firstName" : nil,
                trimmedLastName.isEmpty ? "lastName" : nil,
                trimmedEmail.isEmpty ? "email" : nil,
                trimmedPhone.isEmpty ? "phoneNumber" : nil
            ].compactMap { $0 }

            Logger.shared.e(
                "REGISTER VM",
                "Validation failed | missing=\(missing) | isValidEmail=\(isValidEmail)",
                user: UserSession.shared.currentUser?.userId
            )
            return
        }

        isLoading = true
        errorMessage = nil
        showError = false

        Logger.shared.i(
            "REGISTER VM",
            "Register start | email=\(trimmedEmail) | deviceName=\(deviceName)",
            user: UserSession.shared.currentUser?.userId
        )

        let startTime = CFAbsoluteTimeGetCurrent()

        repository.registerUser(
            firstName: trimmedFirstName,
            lastName: trimmedLastName,
            email: trimmedEmail,
            phoneNumber: trimmedPhone,
            deviceId: deviceId,
            deviceName: deviceName
        ) { [weak self] result in
            guard let self else { return }

            let elapsedMs = Int64((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0)

            DispatchQueue.main.async {
                self.isLoading = false
                self.handleRegistrationResult(result, timeTakenMs: elapsedMs)
            }
        }
    }

    // MARK: - Result Handling
    private func handleRegistrationResult(
        _ result: Result<APIResponse<RegisterUserData>, APIError>,
        timeTakenMs: Int64
    ) {
        switch result {

        case .success(let response):
            guard
                let userData = response.data?.newUser,
                let device = response.data?.newDevice
            else {
                showErrorMessage("Invalid server response.")
                Logger.shared.e(
                    "REGISTER VM",
                    "Missing newUser/newDevice in response payload | msg=\(response.message)",
                    timeTakenMs: timeTakenMs,
                    user: UserSession.shared.currentUser?.userId
                )
                return
            }

            let user = User(
                firstName: trimmedFirstName,
                lastName: trimmedLastName,
                email: trimmedEmail,
                phoneNumber: trimmedPhone,
                deviceKey: device.deviceKey,
                deviceName: device.deviceName,
                userId: userData.id,
                userDeviceId: device.id
            )

            // Persist
            UserDefaults.standard.set(device.token, forKey: "token")
            UserDefaults.standard.set("user", forKey: "accountType")

            UserSession.shared.saveUser(user)
            UserSession.shared.setCurrentDeviceID(device.id)
            UserSession.shared.setThisDevicePrimary(device.isPrimary)
            UserSession.shared.setUserWallet(userData.wallet)
            UserSession.shared.setProfilePicture(userData.profilePic ?? "")

            Logger.shared.i(
                "REGISTER",
                "Register success | msg=\(response.message) | primary=\(device.isPrimary) | emailVerified=\(userData.emailVerified)",
                timeTakenMs: timeTakenMs,
                user: userData.id
            )

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.navigateToMainTab = true
                Logger.shared.d(
                    "REGISTER",
                    "Navigation triggered: navigateToMainTab=true",
                    user: userData.id
                )
            }

        case .failure(let error):
            showErrorMessage(error.localizedDescription)
            Logger.shared.e(
                "REGISTER VM",
                "Register failed | msg=\(error.localizedDescription)",
                error: error,
                timeTakenMs: timeTakenMs,
                user: UserSession.shared.currentUser?.userId
            )
        }
    }

    // MARK: - Helpers
    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }
}
