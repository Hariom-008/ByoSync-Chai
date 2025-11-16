import Foundation
import Combine
import Firebase
import FirebaseAuth
import FirebaseMessaging

final class PhoneOTPViewModel: ObservableObject {
    @Published var phoneNumber: String = ""
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
    
    private var cancellables = Set<AnyCancellable>()
    private var resendTimer: Timer?
    
    // MARK: - Computed Properties
    var isValidPhoneNumber: Bool {
        let digits = phoneNumber.filter { $0.isNumber }
        
        // Must be exactly 10 digits
        guard digits.count == 10 else { return false }
        
        // First digit must be 6, 7, 8, or 9
        guard let firstDigit = digits.first,
              ["6", "7", "8", "9"].contains(String(firstDigit)) else {
            return false
        }
        
        return true
    }
    
    var fullPhoneNumber: String {
        // Returns format: +916XXXXXXXXX
        let digits = phoneNumber.filter { $0.isNumber }
        return "\(selectedCountryCode)\(digits)"
    }
    
    // MARK: - Firebase Phone Authentication
    func sendOTP() {
        guard isValidPhoneNumber else {
            showErrorMessage("Please enter a valid 10-digit mobile number starting with 6-9")
            return
        }
        
        print("🚀 Sending OTP via Firebase for: \(fullPhoneNumber)")
        
        isLoading = true
        errorMessage = nil
        
        sendVerificationCode()
    }
    
    func resendOTP() {
        guard canResend else { return }
        
        print("🔄 Resending OTP via Firebase")
        
        isLoading = true
        errorMessage = nil
        canResend = false
        
        sendVerificationCode()
    }
    
    func verifyOTP(code: String) {
        guard !code.isEmpty, code.count == 6 else {
            showErrorMessage("Please enter a valid 6-digit OTP")
            return
        }
        
        verificationCode = code
        isLoading = true
        errorMessage = nil
        
        verifyCode()
    }
    
    func updatePhoneNumber(_ newValue: String) {
        // Only keep digits and limit to 10
        let digits = newValue.filter { $0.isNumber }
        phoneNumber = String(digits.prefix(10))
        
        // Clear error when user starts typing
        if !phoneNumber.isEmpty {
            errorMessage = nil
        }
    }
    
    // MARK: - Private Firebase Methods
    private func sendVerificationCode() {
        let phoneNumberWithCountryCode = fullPhoneNumber
        
        print("📱 Attempting to send verification code to: \(phoneNumberWithCountryCode)")
        
        PhoneAuthProvider.provider()
            .verifyPhoneNumber(phoneNumberWithCountryCode, uiDelegate: nil) { [weak self] (verificationID, error) in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    if let error = error {
                        self.handleVerificationError(error)
                        return
                    }
                    
                    guard let verificationID = verificationID else {
                        self.showErrorMessage("Failed to get verification ID")
                        return
                    }
                    
                    print("✅ Verification code sent successfully")
                    print("Verification ID: \(verificationID)")
                    
                    self.verificationID = verificationID
                    self.otpSent = true
                    self.startResendTimer()
                    self.errorMessage = nil
                }
            }
    }
    
    private func verifyCode() {
        guard let verificationID = self.verificationID else {
            self.isLoading = false
            self.showErrorMessage("Verification ID is missing. Please request a new code.")
            print("❌ Verification ID is missing")
            return
        }
        
        print("🔐 Attempting to verify code: \(verificationCode)")
        
        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: verificationCode
        )
        
        Auth.auth().signIn(with: credential) { [weak self] (authResult, error) in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.handleSignInError(error)
                    return
                }
                
                guard let authResult = authResult else {
                    self.showErrorMessage("Authentication failed. Please try again.")
                    return
                }
                
                print("✅ User signed in successfully")
                print("User ID: \(authResult.user.uid)")
                print("Phone Number: \(authResult.user.phoneNumber ?? "N/A")")
                
                // Generate and save FCM Token after successful authentication
                self.generateAndSaveFCMToken()
                
                self.isAuthenticated = true
                self.errorMessage = nil
            }
        }
    }
    
    // MARK: - Generate and Save FCM Token
    private func generateAndSaveFCMToken() {
        print("🔑 Generating FCM Token...")
        
        Messaging.messaging().token { token, error in
            if let error = error {
                print("❌ Error fetching FCM token: \(error.localizedDescription)")
                return
            }
            
            guard let fcmToken = token else {
                print("❌ FCM Token is nil")
                return
            }
            
            print("✅ FCM Token generated: \(fcmToken)")
            
            // Save to UserDefaults
            UserDefaults.standard.set(fcmToken, forKey: "fcmToken")
            UserDefaults.standard.synchronize()
            
            print("💾 FCM Token saved to UserDefaults")
            
            // Optional: Send FCM token to your backend
            // self.sendFCMTokenToBackend(fcmToken)
        }
    }
    
    // MARK: - Error Handling
    private func handleVerificationError(_ error: Error) {
        let nsError = error as NSError
        
        print("❌ ERROR SENDING VERIFICATION CODE")
        print("Error Code: \(nsError.code)")
        print("Error Domain: \(nsError.domain)")
        print("Error Description: \(error.localizedDescription)")
        
        if let errorCode = AuthErrorCode(rawValue: nsError.code) {
            print("Firebase Auth Error Code: \(errorCode)")
            
            switch errorCode {
            case .invalidPhoneNumber:
                self.showErrorMessage("Invalid phone number format")
            case .missingPhoneNumber:
                self.showErrorMessage("Phone number is missing")
            case .quotaExceeded:
                self.showErrorMessage("SMS quota exceeded. Try again later.")
            case .captchaCheckFailed:
                self.showErrorMessage("reCAPTCHA verification failed")
            case .invalidAppCredential:
                self.showErrorMessage("Invalid APNs token. Check Firebase configuration.")
            case .missingAppCredential:
                self.showErrorMessage("Missing APNs configuration")
            case .internalError:
                self.showErrorMessage("Internal Firebase error. Check your configuration.")
            case .networkError:
                self.showErrorMessage("Network error. Check your internet connection.")
            default:
                self.showErrorMessage(error.localizedDescription)
            }
        } else {
            self.showErrorMessage(error.localizedDescription)
        }
    }
    
    private func handleSignInError(_ error: Error) {
        let nsError = error as NSError
        
        print("❌ ERROR VERIFYING CODE")
        print("Error Code: \(nsError.code)")
        print("Error Domain: \(nsError.domain)")
        print("Error Description: \(error.localizedDescription)")
        
        if let errorCode = AuthErrorCode(rawValue: nsError.code) {
            print("Firebase Auth Error Code: \(errorCode)")
            
            switch errorCode {
            case .invalidVerificationCode:
                self.showErrorMessage("Invalid verification code. Please try again.")
            case .sessionExpired:
                self.showErrorMessage("Verification code expired. Request a new one.")
            case .invalidVerificationID:
                self.showErrorMessage("Invalid verification ID. Request a new code.")
            case .userDisabled:
                self.showErrorMessage("This account has been disabled.")
            case .tooManyRequests:
                self.showErrorMessage("Too many attempts. Try again later.")
            default:
                self.showErrorMessage(error.localizedDescription)
            }
        } else {
            self.showErrorMessage(error.localizedDescription)
        }
    }
    
    // MARK: - Helper Methods
    private func startResendTimer() {
        canResend = false
        resendCountdown = 30
        
        resendTimer?.invalidate()
        resendTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            if self.resendCountdown > 0 {
                self.resendCountdown -= 1
            } else {
                self.canResend = true
                timer.invalidate()
            }
        }
    }
    
    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }
    
    deinit {
        resendTimer?.invalidate()
    }
}
