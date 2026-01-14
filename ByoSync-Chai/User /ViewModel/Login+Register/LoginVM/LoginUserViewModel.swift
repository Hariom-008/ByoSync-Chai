import Foundation
import SwiftUI
import Combine

final class LoginViewModel: ObservableObject {

    // ✅ Inject crypto service instead of creating instance
    private let cryptoService: any CryptoService
    private let repository: LoginUserRepository

    @Published var name: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""
    @Published var showError: Bool = false
    @Published var loginSuccess: Bool = false
    @Published var role: String = ""
    @Published var wallet: Int?
    @Published var fcmToken: String = ""

    private let deviceKey = DeviceIdentity.resolve()

    // ✅ Dependency injection via initializer
    init(cryptoService: any CryptoService) {
        self.cryptoService = cryptoService
        self.repository = LoginUserRepository(cryptoService: cryptoService)

        #if DEBUG
        print("🎯 [VM] LoginViewModel initialized with crypto service")
        #endif

        Logger.shared.d("LOGIN VM", "LoginViewModel init", user: UserSession.shared.currentUser?.userId)
    }

    func login() async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            await MainActor.run {
                errorMessage = "Please enter your name"
                showError = true
            }
            Logger.shared.e("LOGIN VM", "Validation failed: empty name", user: UserSession.shared.currentUser?.userId)
            return
        }

        // If deviceKey is missing, fail fast (prevents silent backend weirdness)
        guard !deviceKey.isEmpty else {
            await MainActor.run {
                errorMessage = "Device identifier unavailable."
                showError = true
            }
            Logger.shared.e("LOGIN VM", "DeviceIdentity.resolve() returned empty deviceKey", user: UserSession.shared.currentUser?.userId)
            return
        }

        await MainActor.run {
            isLoading = true
            errorMessage = ""
            showError = false
        }

        #if DEBUG
        print("🚀 [VM] Starting login for: \(trimmed)")
        #endif
        Logger.shared.i("LOGIN VM", "Login start", user: UserSession.shared.currentUser?.userId)

        let startTime = CFAbsoluteTimeGetCurrent()

        repository.loginUser(
            name: trimmed,
            deviceKey: deviceKey,
            fcmToken: fcmToken
        ) { [weak self] result in
            guard let self else { return }

            let elapsedMs = Int64((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0)

            DispatchQueue.main.async {
                self.isLoading = false

                switch result {
                case .success(let response):
                    #if DEBUG
                    print("✅ [VM] Login successful: \(response.message)")
                    #endif

                    self.updateUserSession(response: response)

                    self.loginSuccess = true

                    SocketIOManager.shared.connect()

                    #if DEBUG
                    print("✅ [VM] Socket is Connected")
                    #endif

                    let token = response.data?.device.token ?? ""
                    UserDefaults.standard.set(token, forKey: "token")

                    #if DEBUG
                    print("✅ [VM] Token Saved in UserDefaults: \(token)")
                    #endif

                    Logger.shared.i(
                        "LOGIN VM",
                        "Login success | msg=\(response.message) | primary=\(response.data?.device.isPrimary ?? false)",
                        timeTakenMs: elapsedMs,
                        user: response.data?.user.id
                    )

                case .failure(let error):
                    #if DEBUG
                    print("❌ [VM] Login failed: \(error.localizedDescription)")
                    #endif

                    self.errorMessage = error.localizedDescription
                    self.showError = true

                    Logger.shared.e(
                        "AUTH_LOGIN",
                        "Login failed | msg=\(error.localizedDescription)",
                        error: error,
                        timeTakenMs: elapsedMs,
                        user: UserSession.shared.currentUser?.userId
                    )
                }
            }
        }
    }

    private func updateUserSession(response: APIResponse<LoginData>) {
        guard let userData = response.data?.user,
              let deviceData = response.data?.device else {
            #if DEBUG
            print("⚠️ [VM] No data found in response")
            #endif
            Logger.shared.e("LOGIN VM", "Missing user/device in response payload", user: UserSession.shared.currentUser?.userId)
            return
        }

        #if DEBUG
        print("🔓 [VM] Decrypting user data...")
        #endif
        Logger.shared.d("LOGIN VM", "Decrypting user payload", user: userData.id)

        // ✅ Use injected crypto service for decryption
        let user = User(
            firstName: cryptoService.decrypt(encryptedData: userData.firstName) ?? "nil",
            lastName: cryptoService.decrypt(encryptedData: userData.lastName) ?? "nil",
            email: cryptoService.decrypt(encryptedData: userData.email) ?? "nil",
            phoneNumber: cryptoService.decrypt(encryptedData: userData.phoneNumber) ?? "nil",
            deviceKey: deviceData.deviceKey,
            deviceName: deviceData.deviceName,
            refferalCode: userData.referralCode,
            userId: userData.id,
            userDeviceId: deviceData.id
        )

        #if DEBUG
        print("✅ [VM] User data decrypted successfully")
        print("✅ [VM] Saved user with userId: \(deviceData.user)")
        #endif

        // Save to session
        UserSession.shared.saveUser(user)
        UserSession.shared.setEmailVerified(userData.emailVerified)
        UserSession.shared.setProfilePicture(userData.profilePic ?? "")
        UserSession.shared.setCurrentDeviceID(deviceData.id)
        UserSession.shared.setThisDevicePrimary(deviceData.isPrimary)
        UserSession.shared.setUserWallet(userData.wallet)

        // Save Account type
        UserDefaults.standard.set("user", forKey: "accountType")

        Logger.shared.i(
            "LOGIN",
            "User session updated | device=\(deviceData.deviceName) | primary=\(deviceData.isPrimary)",
            user: userData.id
        )

        #if DEBUG
        print("""
              ✅ [VM] User Login Complete:
              Name: \(user.firstName) \(user.lastName)
              Email: \(user.email)
              Device: \(deviceData.deviceName)
              Primary: \(deviceData.isPrimary)
              """)
        #endif
    }
}
