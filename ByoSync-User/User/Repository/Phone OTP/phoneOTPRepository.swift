import Foundation
import Alamofire


struct PhoneOTPResponse: Codable {
    let success: Bool
    let message: String
    let data: OTPData?
}
struct VerifyOTPResponse: Codable {
    let success: Bool
    let message: String
    let data: VerifyOTPData?
}

// MARK: - OTP Repository
final class OTPRepository {
    static let shared = OTPRepository()
    
    private init() {}
    
    // MARK: - Send Phone OTP
    func sendPhoneOTP(
        phoneNumber: String,
        completion: @escaping (Result<PhoneOTPResponse, APIError>) -> Void
    ) {
        print("📱 Input phone number: '\(phoneNumber)'")
        print("📏 Length: \(phoneNumber.count)")
            
        let payload: Parameters = [
            "number": phoneNumber
        ]
        
        APIClient.shared.requestWithoutResponse(
            UserAPIEndpoint.Auth.phoneOTP,
            method: .post,
            parameters: payload
        ) { result in
            switch result {
            case .success:
                print("✅ OTP sent successfully")
                let response = PhoneOTPResponse(
                    success: true,
                    message: "OTP sent successfully",
                    data: OTPData(
                        phoneNumber: phoneNumber,
                        otpSentAt: nil,
                        expiresIn: 300
                    )
                )
                completion(.success(response))
                
            case .failure(let error):
                print("❌ API Error: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Verify OTP
    func verifyOTP(
        phoneNumber: String,
        otp: String,
        completion: @escaping (Result<VerifyOTPResponse, APIError>) -> Void
    ) {
        let payload: Parameters = [
            "number": phoneNumber,
            "otp": otp
        ]
        
        print("📤 Verifying OTP Request:")
        print("Phone: '\(phoneNumber)'")
        print("OTP: \(otp)")
        
        APIClient.shared.requestWithoutResponse(
            UserAPIEndpoint.Auth.verifyOTP,
            method: .post,
            parameters: payload
        ) { result in
            switch result {
            case .success:
                print("✅ OTP verified successfully")
                let response = VerifyOTPResponse(
                    success: true,
                    message: "OTP verified successfully",
                    data: VerifyOTPData(
                        token: nil,
                        refreshToken: nil,
                        user: nil,
                        isNewUser: true
                    )
                )
                completion(.success(response))
                
            case .failure(let error):
                print("❌ OTP verification failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Resend OTP
    func resendOTP(
        phoneNumber: String,
        completion: @escaping (Result<PhoneOTPResponse, APIError>) -> Void
    ) {
        sendPhoneOTP(phoneNumber: phoneNumber, completion: completion)
    }
}
