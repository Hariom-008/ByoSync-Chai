//
//  EmailVerificationViewModel.swift
//  ByoSync
//
//  Updated by Hari's Mac on 22.10.2025.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class EmailVerificationViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var email: String = ""
    @Published var otp: String = ""
    
    @Published var isLoading: Bool = false
    @Published var isSendingOTP: Bool = false
    @Published var isVerifyingOTP: Bool = false
    
    @Published var showAlert: Bool = false
    @Published var alertMessage: String = ""
    @Published var alertTitle: String = ""
    @Published var alertType: AlertType = .info
    
    @Published var otpSent: Bool = false
    @Published var emailVerified: Bool = false
    
    // Timer for resend OTP
    @Published var canResendOTP: Bool = true
    @Published var resendTimer: Int = 0
    private var timer: Timer?
    
    // MARK: - Alert Type
    enum AlertType {
        case success
        case error
        case info
    }
    
    // MARK: - Private Properties
    private let repository = EmailVerificationRepository.shared
    private let userSession = UserSession.shared
    
    // MARK: - Initialization
    init() {
        // Load email from UserSession if available
        if let currentUser = userSession.currentUser {
            self.email = currentUser.email
            print("✅ [VM] Loaded email from UserSession: \(currentUser.email)")
        }
    }
    
    // MARK: - Validation
    var isEmailValid: Bool {
        !email.isEmpty && isValidEmail(email)
    }
    
    var isOTPValid: Bool {
        !otp.isEmpty && otp.count == 6  // 6-digit OTP
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    // MARK: - Send Email OTP
    func sendOTP() {
        print("📤 [VM] sendOTP called")
        
        // Validate email
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty else {
            showAlertMessage(title: "Invalid Input", message: "Please enter your email", type: .error)
            return
        }
        
        guard isValidEmail(email) else {
            showAlertMessage(title: "Invalid Email", message: "Please enter a valid email address", type: .error)
            return
        }
        
        isSendingOTP = true
        isLoading = true
        
        print("⏳ [VM] Sending OTP to: \(email)")
        
        repository.sendEmailOTP() { [weak self] result in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.isSendingOTP = false
                self.isLoading = false
                
                switch result {
                case .success(let response):
                    self.otpSent = true
                    self.startResendTimer()
                    print("✅ [VM] OTP sent successfully: \(response.message)")
                    // Show success feedback
                    self.showAlertMessage(
                        title: "OTP Sent",
                        message: "Please check your email for the verification code",
                        type: .success
                    )
                    
                case .failure(let error):
                    self.otpSent = false
                    print("❌ [VM] Failed to send OTP: \(error)")
                    self.handleError(error, errorTitle: "Failed to Send OTP")
                }
            }
        }
    }
    
    // MARK: - Verify Email OTP
    func verifyOTP() {
        print("🔍 [VM] verifyOTP called")
        
        // Validate OTP
        guard !otp.trimmingCharacters(in: .whitespaces).isEmpty else {
            showAlertMessage(title: "Invalid Input", message: "Please enter the OTP", type: .error)
            return
        }
        
        guard otp.count == 6 else {
            showAlertMessage(title: "Invalid OTP", message: "OTP must be 6 digits", type: .error)
            return
        }
        
        isVerifyingOTP = true
        isLoading = true
        
        print("⏳ [VM] Verifying OTP: \(otp)")
        
        // Only send OTP, not email (matching Android implementation)
        repository.verifyEmailOTP(
            otp: otp.trimmingCharacters(in: .whitespaces)
        ) { [weak self] result in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.isVerifyingOTP = false
                self.isLoading = false
                
                switch result {
                case .success(let response):
                    print("✅ [VM] Email verified successfully: \(response.message)")
                    self.emailVerified = true
                    self.stopResendTimer()
                    
                    // Update email verification status in UserSession
                    self.userSession.setEmailVerified(true)
                    
                    self.showAlertMessage(
                        title: "Email Verified",
                        message: response.message,
                        type: .success
                    )
                    
                case .failure(let error):
                    print("❌ [VM] Email verification failed: \(error)")
                    self.emailVerified = false
                    self.handleError(error, errorTitle: "Verification Failed")
                }
            }
        }
    }
    
    // MARK: - Resend OTP
    func resendOTP() {
        print("🔄 [VM] resendOTP called")
        guard canResendOTP else {
            print("⚠️ [VM] Cannot resend OTP yet, timer active")
            return
        }
        otp = "" // Clear previous OTP
        sendOTP()
    }
    // MARK: - Helper Methods
    private func handleError(_ error: APIError, errorTitle: String) {
        var message = "Something went wrong"
        
        switch error {
        case .custom(let customMessage):
            message = customMessage
        case .networkError(let networkError):
            message = networkError
        case .decodingError:
            message = "Failed to process server response"
        case .unauthorized:
            message = "Unauthorized access"
        case .serverError(let statusCode):
            message = "Server error (Code: \(statusCode))"
        default:
            message = "An unexpected error occurred"
        }
        
        showAlertMessage(title: errorTitle, message: message, type: .error)
        print("❌ [VM] Error: \(message)")
    }
    
    private func showAlertMessage(title: String, message: String, type: AlertType) {
        alertTitle = title
        alertMessage = message
        alertType = type
        showAlert = true
    }
    
    // MARK: - Reset
    func reset() {
        print("🔄 [VM] Resetting view model")
        email = ""
        otp = ""
        otpSent = false
        emailVerified = false
        alertMessage = ""
        alertTitle = ""
        showAlert = false
        stopResendTimer()
    }
    
    // MARK: - Timer Management
    private func startResendTimer() {
        print("⏱️ [VM] Starting resend timer (60s)")
        canResendOTP = false
        resendTimer = 60 // 60 seconds
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            Task { @MainActor in
                if self.resendTimer > 0 {
                    self.resendTimer -= 1
                } else {
                    self.stopResendTimer()
                }
            }
        }
    }

    private func stopResendTimer() {
        print("⏱️ [VM] Stopping resend timer")
        timer?.invalidate()
        timer = nil
        canResendOTP = true
        resendTimer = 0
    }

    // ✅ Fixed deinit - no MainActor isolation needed
    nonisolated deinit {
        print("♻️ [VM] EmailVerificationViewModel deallocated")
        // Direct timer cleanup without calling MainActor-isolated method
        timer?.invalidate()
    }
}
