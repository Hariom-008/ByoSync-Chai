import Foundation
import Combine
import Firebase
import FirebaseAuth
import FirebaseMessaging

enum OTPMethod {
    case firebase
    case backend
}

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
    @Published var currentOTPMethod: OTPMethod = .backend  // Default to backend
    @Published var receivedOTP: String?  // Store OTP from backend for testing
    
    private let repository: OTPRepository
    
    private var cancellables = Set<AnyCancellable>()
    private var resendTimer: Timer?
    
    init(repository: OTPRepository = .shared) {
        self.repository = repository
    }
    
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
    
    // MARK: - Backend OTP Methods
    func sendOTPonBackend() {
        guard isValidPhoneNumber else {
            showErrorMessage("Please enter a valid 10-digit mobile number starting with 6-9")
            return
        }
        
        print("🚀 Sending OTP via Backend for: \(fullPhoneNumber)")
        
        isLoading = true
        errorMessage = nil
        currentOTPMethod = .backend
        
        repository.sendPhoneOTP(phoneNumber: fullPhoneNumber) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                switch result {
                case .success(let response):
                    self.receivedOTP = response.data?.otp
                    self.otpSent = true
                    self.startResendTimer()
                    self.errorMessage = nil
                    
                    print("✅ OTP sent successfully via backend")
                    if let otp = self.receivedOTP {
                        print("🔐 OTP for testing: \(otp)")
                    }
                    
                case .failure(let error):
                    let errorMsg = error.localizedDescription
                    self.showErrorMessage(errorMsg)
                    print("❌ Backend OTP failed: \(errorMsg)")
                }
            }
        }
    }
    
    func verifyOTPonBackend(code: String) {
        guard !code.isEmpty, code.count == 6 else {
            showErrorMessage("Please enter a valid 6-digit OTP")
            return
        }
        
        print("🔐 Verifying OTP via Backend")
        
        isLoading = true
        errorMessage = nil
        verificationCode = code
        
        repository.verifyOTP(phoneNumber: fullPhoneNumber, otp: code) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                switch result {
                case .success(let response):
                    print("✅ OTP verified successfully via backend")
                    
                    // Save tokens if available
                    if let token = response.data?.token {
                        UserDefaults.standard.set(token, forKey: "authToken")
                        print("💾 Auth token saved")
                    }
                    
                    if let refreshToken = response.data?.refreshToken {
                        UserDefaults.standard.set(refreshToken, forKey: "refreshToken")
                        print("💾 Refresh token saved")
                    }
                    
                    // Generate and save FCM Token
                    self.generateAndSaveFCMToken()
                    
                    self.isAuthenticated = true
                    self.errorMessage = nil
                    
                case .failure(let error):
                    let errorMsg =  error.localizedDescription
                    self.showErrorMessage(errorMsg)
                    print("❌ Backend OTP verification failed: \(errorMsg)")
                }
            }
        }
    }
    
    func resendOTPonBackend() {
        guard canResend else { return }
        
        print("🔄 Resending OTP via Backend")
        
        isLoading = true
        errorMessage = nil
        canResend = false
        
        repository.resendOTP(phoneNumber: fullPhoneNumber) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                switch result {
                case .success(let response):
                    self.receivedOTP = response.data?.otp
                    self.startResendTimer()
                    self.errorMessage = nil
                    
                    print("✅ OTP resent successfully via backend")
                    if let otp = self.receivedOTP {
                        print("🔐 New OTP for testing: \(otp)")
                    }
                    
                case .failure(let error):
                    let errorMsg = error.localizedDescription
                    self.showErrorMessage(errorMsg)
                    print("❌ Backend OTP resend failed: \(errorMsg)")
                    self.canResend = true
                }
            }
        }
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
        currentOTPMethod = .firebase
        
        sendVerificationCode()
    }
    
    func resendOTP() {
        guard canResend else { return }
        
        if currentOTPMethod == .backend {
            resendOTPonBackend()
        } else {
            print("🔄 Resending OTP via Firebase")
            
            isLoading = true
            errorMessage = nil
            canResend = false
            
            sendVerificationCode()
        }
    }
    
    func verifyOTP(code: String) {
        guard !code.isEmpty, code.count == 6 else {
            showErrorMessage("Please enter a valid 6-digit OTP")
            return
        }
        
        verificationCode = code
        
        if currentOTPMethod == .backend {
            verifyOTPonBackend(code: code)
        } else {
            isLoading = true
            errorMessage = nil
            verifyCode()
        }
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
