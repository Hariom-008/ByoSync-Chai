import Foundation
import Alamofire

final class OTPRepository {
    static let shared = OTPRepository()
    
    private init() {}
    
    // MARK: - Send Phone OTP
    func sendPhoneOTP(
        phoneNumber: String,
        completion: @escaping (Result<PhoneOTPResponse, APIError>) -> Void
    ) {
        #if DEBUG
        print("📤 SENDING OTP REQUEST (BACKEND)")
        print("📱 Phone Number: '\(phoneNumber)'")
        print("📏 Length: \(phoneNumber.count)")
        print("🌐 Endpoint: \(UserAPIEndpoint.Auth.phoneOTP)")
        #endif
        
        let payload: Parameters = [
            "number": phoneNumber
        ]
        #if DEBUG
        print("📦 Payload: \(payload)")
        #endif
        
        APIClient.shared.request(
            UserAPIEndpoint.Auth.phoneOTP,
            method: .post,
            parameters: payload
        ) { (result: Result<PhoneOTPResponse, APIError>) in
            switch result {
            case .success(let response):
                #if DEBUG
                print("✅ OTP SENT SUCCESSFULLY (BACKEND)")
                print("📥 RESPONSE RECEIVED:")
                
                
                // Print the complete response structure
                print("📊 statusCode: \(response.statusCode ?? 0)")
                print("✔️  success: \(response.success)")
                print("💬 message: \"\(response.message)\"")
                #endif
                
                if let data = response.data {
                    #if DEBUG
                    print("📦 data: {")
                    #endif
                    if let otp = data.otp {
                        #if DEBUG
                        print("    🔐 otp: \"\(otp)\"")
                        #endif
                    }
                    if let phoneNumber = data.phoneNumber {
                        print("    📱 phoneNumber: \"\(phoneNumber)\"")
                    }
                    if let otpSentAt = data.otpSentAt {
                        print(" 🕐 otpSentAt: \"\(otpSentAt)\"")
                    }
                    if let expiresIn = data.expiresIn {
                        print("    ⏰ expiresIn: \(expiresIn) seconds")
                    }
                    #if DEBUG
                    print("}")
                    #endif
                } else {
                    #if DEBUG
                    print("📦 data: null")
                    #endif
                }
                #if DEBUG
                print("🎯 FORMATTED RESPONSE:")
                #endif
                self.printFormattedJSON(response)
                completion(.success(response))
                
            case .failure(let error):
                #if DEBUG
                print("❌ OTP SEND FAILED (BACKEND)")
                print("🔴 Error: \(error.localizedDescription)")
                
            
                print("💬 Error Message: \(error.localizedDescription)")
                #endif
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
        #if DEBUG
        print("📤 VERIFYING OTP REQUEST (BACKEND)")
        print("📱 Phone Number: '\(phoneNumber)'")
        print("🔐 OTP: \(otp)")
        print("🌐 Endpoint: \(UserAPIEndpoint.Auth.verifyOTP)")
        
        #endif
        
        let payload: Parameters = [
            "number": phoneNumber,
            "otp": otp
        ]
        #if DEBUG
        print("📦 Payload: \(payload)")
        #endif
        
        APIClient.shared.request(
            UserAPIEndpoint.Auth.verifyOTP,
            method: .post,
            parameters: payload
        ) { (result: Result<VerifyOTPResponse, APIError>) in
            switch result {
            case .success(let response):
                #if DEBUG
                print("✅ OTP VERIFIED SUCCESSFULLY (BACKEND)")
                print("📥 RESPONSE RECEIVED:")
                
                // Print the complete response structure
                print("📊 statusCode: \(response.statusCode ?? 0)")
                print("✔️  success: \(response.success)")
                print("💬 message: \"\(response.message)\"")
                #endif
                
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
                #if DEBUG
                print("🎯 FORMATTED RESPONSE:")
                self.printFormattedJSON(response)
                #endif
                
                completion(.success(response))
                
            case .failure(let error):
                #if DEBUG
                print("❌ OTP VERIFICATION FAILED (BACKEND)")
                print("🔴 Error: \(error.localizedDescription)")
                
                print("💬 Error Message: \(error.localizedDescription)")
                
                #endif
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Resend OTP (Backend)
    func resendOTP(
        phoneNumber: String,
        completion: @escaping (Result<PhoneOTPResponse, APIError>) -> Void
    ) {
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
            #if DEBUG
            print("Unable to format JSON")
            #endif
        }
    }
}
