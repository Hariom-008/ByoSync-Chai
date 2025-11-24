import Foundation
import Alamofire

// MARK: - Send OTP Response Data
struct OTPData: Codable {
    let otp: String?  // Added otp field as per new response structure
    let phoneNumber: String?
    let otpSentAt: String?
    let expiresIn: Int?
}

// MARK: - Phone OTP Response
struct PhoneOTPResponse: Codable {
    let success: Bool
    let message: String
    let statusCode: Int?
    let data: OTPData?
}

// MARK: - Verify OTP Response
struct VerifyOTPResponse: Codable {
    let success: Bool
    let message: String
    let statusCode: Int?
    let data: VerifyOTPData?
}

// MARK: - OTP Repository
final class OTPRepository {
    static let shared = OTPRepository()
    
    private init() {}
    
    // MARK: - Send Phone OTP (Backend)
    func sendPhoneOTP(
        phoneNumber: String,
        completion: @escaping (Result<PhoneOTPResponse, APIError>) -> Void
    ) {
        print("═══════════════════════════════════════")
        print("📤 SENDING OTP REQUEST (BACKEND)")
        print("═══════════════════════════════════════")
        print("📱 Phone Number: '\(phoneNumber)'")
        print("📏 Length: \(phoneNumber.count)")
        print("🌐 Endpoint: \(UserAPIEndpoint.Auth.phoneOTP)")
        
        let payload: Parameters = [
            "number": phoneNumber
        ]
        
        print("📦 Payload: \(payload)")
        print("───────────────────────────────────────")
        
        APIClient.shared.request(
            UserAPIEndpoint.Auth.phoneOTP,
            method: .post,
            parameters: payload
        ) { (result: Result<PhoneOTPResponse, APIError>) in
            switch result {
            case .success(let response):
                print("═══════════════════════════════════════")
                print("✅ OTP SENT SUCCESSFULLY (BACKEND)")
                print("═══════════════════════════════════════")
                print("📥 RESPONSE RECEIVED:")
                print("───────────────────────────────────────")
                
                // Print the complete response structure
                print("📊 statusCode: \(response.statusCode ?? 0)")
                print("✔️  success: \(response.success)")
                print("💬 message: \"\(response.message)\"")
                
                if let data = response.data {
                    print("📦 data: {")
                    if let otp = data.otp {
                        print("    🔐 otp: \"\(otp)\"")
                    }
                    if let phoneNumber = data.phoneNumber {
                        print("    📱 phoneNumber: \"\(phoneNumber)\"")
                    }
                    if let otpSentAt = data.otpSentAt {
                        print("    🕐 otpSentAt: \"\(otpSentAt)\"")
                    }
                    if let expiresIn = data.expiresIn {
                        print("    ⏰ expiresIn: \(expiresIn) seconds")
                    }
                    print("}")
                } else {
                    print("📦 data: null")
                }
                
                print("───────────────────────────────────────")
                print("🎯 FORMATTED RESPONSE:")
                self.printFormattedJSON(response)
                print("═══════════════════════════════════════")
                
                completion(.success(response))
                
            case .failure(let error):
                print("═══════════════════════════════════════")
                print("❌ OTP SEND FAILED (BACKEND)")
                print("═══════════════════════════════════════")
                print("🔴 Error: \(error.localizedDescription)")
                
            
                print("💬 Error Message: \(error.localizedDescription)")
                
                print("═══════════════════════════════════════")
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Verify OTP (Backend)
    func verifyOTP(
        phoneNumber: String,
        otp: String,
        completion: @escaping (Result<VerifyOTPResponse, APIError>) -> Void
    ) {
        print("═══════════════════════════════════════")
        print("📤 VERIFYING OTP REQUEST (BACKEND)")
        print("═══════════════════════════════════════")
        print("📱 Phone Number: '\(phoneNumber)'")
        print("🔐 OTP: \(otp)")
        print("🌐 Endpoint: \(UserAPIEndpoint.Auth.verifyOTP)")
        
        let payload: Parameters = [
            "number": phoneNumber,
            "otp": otp
        ]
        
        print("📦 Payload: \(payload)")
        print("───────────────────────────────────────")
        
        APIClient.shared.request(
            UserAPIEndpoint.Auth.verifyOTP,
            method: .post,
            parameters: payload
        ) { (result: Result<VerifyOTPResponse, APIError>) in
            switch result {
            case .success(let response):
                print("═══════════════════════════════════════")
                print("✅ OTP VERIFIED SUCCESSFULLY (BACKEND)")
                print("═══════════════════════════════════════")
                print("📥 RESPONSE RECEIVED:")
                print("───────────────────────────────────────")
                
                // Print the complete response structure
                print("📊 statusCode: \(response.statusCode ?? 0)")
                print("✔️  success: \(response.success)")
                print("💬 message: \"\(response.message)\"")
                
                if let data = response.data {
                    print("📦 data: {")
                    if let token = data.token {
                        print("    🎫 token: \"\(token.prefix(20))...\" (truncated)")
                    }
                    if let refreshToken = data.refreshToken {
                        print("    🔄 refreshToken: \"\(refreshToken.prefix(20))...\" (truncated)")
                    }
                    if let isNewUser = data.isNewUser {
                        print("    👤 isNewUser: \(isNewUser)")
                    }
                    print("}")
                } else {
                    print("📦 data: null")
                }
                
                print("───────────────────────────────────────")
                print("🎯 FORMATTED RESPONSE:")
                self.printFormattedJSON(response)
                print("═══════════════════════════════════════")
                
                completion(.success(response))
                
            case .failure(let error):
                print("═══════════════════════════════════════")
                print("❌ OTP VERIFICATION FAILED (BACKEND)")
                print("═══════════════════════════════════════")
                print("🔴 Error: \(error.localizedDescription)")
                
                print("💬 Error Message: \(error.localizedDescription)")
                
                print("═══════════════════════════════════════")
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Resend OTP (Backend)
    func resendOTP(
        phoneNumber: String,
        completion: @escaping (Result<PhoneOTPResponse, APIError>) -> Void
    ) {
        print("🔄 RESENDING OTP (BACKEND)")
        sendPhoneOTP(phoneNumber: phoneNumber, completion: completion)
    }
    
    // MARK: - Helper Methods
    private func printFormattedJSON<T: Encodable>(_ object: T) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        if let jsonData = try? encoder.encode(object),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        } else {
            print("Unable to format JSON")
        }
    }
}
