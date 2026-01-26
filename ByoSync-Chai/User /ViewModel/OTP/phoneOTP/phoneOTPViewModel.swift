import Foundation
import FirebaseAuth
import FirebaseMessaging
import Combine

final class PhoneOTPViewModel: ObservableObject {
    @Published var phoneNumber: String = ""           // 10 digits only
    @Published var selectedCountryCode: String = "+91"
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    @Published var otpSent: Bool = false

    @Published var canResend: Bool = false
    @Published var resendCountdown: Int = 30

    @Published var verificationID: String?
    @Published var verificationCode: String = ""
    @Published var isAuthenticated: Bool = false

    private var resendTimer: Timer?

    // MARK: - Computed
    var isValidPhoneNumber: Bool {
        let digits = phoneNumber.filter { $0.isNumber }
        guard digits.count == 10 else { return false }
        guard let first = digits.first else { return false }
        return ["6", "7", "8", "9"].contains(String(first))
    }

    var fullPhoneNumber: String {
        let digits = phoneNumber.filter { $0.isNumber }
        return "\(selectedCountryCode)\(digits)" // +916XXXXXXXXX
    }

    // MARK: - Public API
    func sendOTP() {
        guard isValidPhoneNumber else {
            showErrorMessage("Please enter a valid 10-digit mobile number starting with 6-9")
            Logger.shared.e("OTP", "sendOTP blocked: invalid phone", user: "PRE_AUTH")
            return
        }

        isLoading = true
        errorMessage = nil

        #if DEBUG
        print("📨 [PhoneOTPVM] sendOTP() -> verifyPhoneNumber start for \(fullPhoneNumber)")
        #endif

        Logger.shared.i("OTP", "sendOTP start", user: "PRE_AUTH")
        sendVerificationCode(flow: "send")
    }

    func resendOTP() {
        guard canResend else {
            Logger.shared.d("OTP", "resendOTP blocked: canResend=false", user: "PRE_AUTH")
            return
        }

        isLoading = true
        errorMessage = nil
        canResend = false

        #if DEBUG
        print("🔁 [PhoneOTPVM] resendOTP() -> verifyPhoneNumber start for \(fullPhoneNumber)")
        #endif

        Logger.shared.i("OTP", "resendOTP start", user: "PRE_AUTH")
        sendVerificationCode(flow: "resend")
    }

    func verifyOTP(code: String) {
        guard code.count == 6, code.allSatisfy({ $0.isNumber }) else {
            showErrorMessage("Please enter a valid 6-digit OTP")
            Logger.shared.e("OTP", "verifyOTP blocked: invalid code format", user: "PRE_AUTH")
            return
        }

        verificationCode = code
        isLoading = true
        errorMessage = nil

        #if DEBUG
        print("🔐 [PhoneOTPVM] verifyOTP() -> signIn start (code len=6)")
        #endif

        Logger.shared.i("OTP", "verifyOTP start", user: "PRE_AUTH")
        verifyCode()
    }

    func updatePhoneNumber(_ newValue: String) {
        let digits = newValue.filter { $0.isNumber }
        phoneNumber = String(digits.prefix(10))
        if !phoneNumber.isEmpty { errorMessage = nil }
    }

    // MARK: - Firebase internals
    private func sendVerificationCode(flow: String) {
        let phone = fullPhoneNumber
        let startTime = CFAbsoluteTimeGetCurrent()

        PhoneAuthProvider.provider()
            .verifyPhoneNumber(phone, uiDelegate: nil) { [weak self] verificationID, error in
                guard let self = self else { return }
                let elapsedMs = Int64((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0)

                DispatchQueue.main.async {
                    self.isLoading = false

                    if let error = error {
                        #if DEBUG
                        print("❌ [PhoneOTPVM] verifyPhoneNumber failed (\(flow)): \(error.localizedDescription)")
                        #endif

                        Logger.shared.e(
                            "OTP",
                            "verifyPhoneNumber failed | flow=\(flow) | msg=\(error.localizedDescription)",
                            error: error,
                            timeTakenMs: elapsedMs,
                            user: "PRE_AUTH"
                        )
                        self.handleVerificationError(error)
                        return
                    }

                    guard let verificationID else {
                        #if DEBUG
                        print("❌ [PhoneOTPVM] verifyPhoneNumber returned nil verificationID (\(flow))")
                        #endif

                        Logger.shared.e(
                            "OTP",
                            "verifyPhoneNumber missing verificationID | flow=\(flow)",
                            timeTakenMs: elapsedMs,
                            user: "PRE_AUTH"
                        )
                        self.showErrorMessage("Failed to get verification ID")
                        return
                    }

                    self.verificationID = verificationID
                    self.otpSent = true
                    self.startResendTimer()
                    self.errorMessage = nil

                    #if DEBUG
                    print("✅ [PhoneOTPVM] OTP sent (\(flow)) | verificationID len=\(verificationID.count)")
                    #endif

                    Logger.shared.i(
                        "OTP",
                        "OTP sent | flow=\(flow) | verificationID_len=\(verificationID.count)",
                        timeTakenMs: elapsedMs,
                        user: "PRE_AUTH"
                    )
                }
            }
    }

    private func verifyCode() {
        guard let verificationID else {
            isLoading = false
            showErrorMessage("Verification ID is missing. Please request a new code.")

            Logger.shared.e("OTP", "verifyCode blocked: missing verificationID", user: "PRE_AUTH")
            return
        }

        let startTime = CFAbsoluteTimeGetCurrent()

        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: verificationCode
        )

        Auth.auth().signIn(with: credential) { [weak self] authResult, error in
            guard let self = self else { return }
            let elapsedMs = Int64((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0)

            DispatchQueue.main.async {
                self.isLoading = false

                if let error = error {
                    #if DEBUG
                    print("❌ [PhoneOTPVM] signIn failed: \(error.localizedDescription)")
                    #endif

                    Logger.shared.e(
                        "OTP",
                        "signIn failed | msg=\(error.localizedDescription)",
                        error: error,
                        timeTakenMs: elapsedMs,
                        user: "PRE_AUTH"
                    )
                    self.handleSignInError(error)
                    return
                }

                guard authResult != nil else {
                    #if DEBUG
                    print("❌ [PhoneOTPVM] signIn returned nil authResult")
                    #endif

                    Logger.shared.e(
                        "OTP",
                        "signIn returned nil authResult",
                        timeTakenMs: elapsedMs,
                        user: "PRE_AUTH"
                    )
                    self.showErrorMessage("Authentication failed. Please try again.")
                    return
                }

                self.generateAndSaveFCMToken()
                self.isAuthenticated = true
                self.errorMessage = nil

                #if DEBUG
                print("✅ [PhoneOTPVM] signIn success (Firebase) | isAuthenticated=true")
                #endif

                Logger.shared.i(
                    "OTP",
                    "signIn success (Firebase) | isAuthenticated=true",
                    timeTakenMs: elapsedMs,
                    user: "PRE_AUTH"
                )
            }
        }
    }

    // MARK: - FCM
    private func generateAndSaveFCMToken() {
        Messaging.messaging().token { token, error in
            if let error = error {
                #if DEBUG
                print("❌ [PhoneOTPVM] FCM token fetch failed: \(error.localizedDescription)")
                #endif
                Logger.shared.e("FCM", "token fetch failed", error: error, user: "PRE_AUTH")
                return
            }

            guard let token else {
                #if DEBUG
                print("❌ [PhoneOTPVM] FCM token is nil")
                #endif
                Logger.shared.e("FCM", "token is nil", user: "PRE_AUTH")
                return
            }

            UserDefaults.standard.set(token, forKey: "fcmToken")
            UserDefaults.standard.synchronize()

            #if DEBUG
            print("✅ [PhoneOTPVM] FCM token saved | len=\(token.count)")
            #endif
            Logger.shared.i("FCM", "token saved | len=\(token.count)", user: "PRE_AUTH")
        }
    }

    // MARK: - Errors
    private func handleVerificationError(_ error: Error) {
        let nsError = error as NSError
        if let errorCode = AuthErrorCode(rawValue: nsError.code) {
            switch errorCode {
            case .invalidPhoneNumber:
                showErrorMessage("Invalid phone number format")
            case .missingPhoneNumber:
                showErrorMessage("Phone number is missing")
            case .quotaExceeded:
                showErrorMessage("SMS quota exceeded. Try again later.")
            case .captchaCheckFailed:
                showErrorMessage("reCAPTCHA verification failed")
            case .invalidAppCredential:
                showErrorMessage("Invalid APNs token. Check Firebase configuration.")
            case .missingAppCredential:
                showErrorMessage("Missing APNs configuration")
            case .internalError:
                showErrorMessage("Internal Firebase error. Check your configuration.")
            case .networkError:
                showErrorMessage("Network error. Check your internet connection.")
            default:
                showErrorMessage(error.localizedDescription)
            }
        } else {
            showErrorMessage(error.localizedDescription)
        }

        Logger.shared.e(
            "OTP",
            "verification error mapped | msg=\(errorMessage ?? error.localizedDescription)",
            error: error,
            user: "PRE_AUTH"
        )
    }

    private func handleSignInError(_ error: Error) {
        let nsError = error as NSError
        if let errorCode = AuthErrorCode(rawValue: nsError.code) {
            switch errorCode {
            case .invalidVerificationCode:
                showErrorMessage("Invalid verification code. Please try again.")
            case .sessionExpired:
                showErrorMessage("Verification code expired. Request a new one.")
            case .invalidVerificationID:
                showErrorMessage("Invalid verification ID. Request a new code.")
            case .userDisabled:
                showErrorMessage("This account has been disabled.")
            case .tooManyRequests:
                showErrorMessage("Too many attempts. Try again later.")
            default:
                showErrorMessage(error.localizedDescription)
            }
        } else {
            showErrorMessage(error.localizedDescription)
        }

        Logger.shared.e(
            "OTP",
            "signIn error mapped | msg=\(errorMessage ?? error.localizedDescription)",
            error: error,
            user: "PRE_AUTH"
        )
    }

    // MARK: - Timer
    private func startResendTimer() {
        canResend = false
        resendCountdown = 30

        resendTimer?.invalidate()
        resendTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            if self.resendCountdown > 0 {
                self.resendCountdown -= 1
            } else {
                self.canResend = true
                timer.invalidate()

                #if DEBUG
                print("✅ [PhoneOTPVM] canResend=true")
                #endif
                Logger.shared.i("OTP", "resend unlocked | canResend=true", user: "PRE_AUTH")
            }
        }
    }

    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true

        #if DEBUG
        print("⚠️ [PhoneOTPVM] UI error: \(message)")
        #endif
        Logger.shared.e("OTP", "UI error: \(message)", user: "PRE_AUTH")
    }

    deinit {
        resendTimer?.invalidate()
        #if DEBUG
        print("🍀 [PhoneOTPVM] deinit")
        #endif
        Logger.shared.d("OTP", "deinit", user: "PRE_AUTH")
    }
}
