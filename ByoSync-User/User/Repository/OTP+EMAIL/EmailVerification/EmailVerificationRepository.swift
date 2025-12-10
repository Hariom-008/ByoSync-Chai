import Foundation
import Alamofire

// Email Verify and Send Repository
final class EmailVerificationRepository {
    
    static let shared = EmailVerificationRepository()
    private init() {}
    
    // MARK: - Send Email OTP
    func sendEmailOTP(
        completion: @escaping (Result<APIResponse<EmptyData>, APIError>) -> Void
    ) {
        let headers = getHeader.shared.getAuthHeaders()
        
        print("📤 [REPO] Sending Email OTP:")
        print("📍 [REPO] URL: \(UserAPIEndpoint.Auth.sendEmail)")
        
        APIClient.shared.request(
            UserAPIEndpoint.Auth.sendEmail,
            method: .post,
            headers: headers
        ) { (result: Result<APIResponse<EmptyData>, APIError>) in
            switch result {
            case .success(let response):
                if response.success ?? false {
                    print("✅ [REPO] Email OTP sent successfully: \(response.message)")
                    completion(.success(response))
                } else {
                    print("❌ [REPO] Failed to send OTP: \(response.message)")
                    completion(.failure(.custom(response.message)))
                }
            case .failure(let error):
                print("❌ [REPO] API failure sending email OTP: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Verify Email OTP
    func verifyEmailOTP(
        otp: String,
        completion: @escaping (Result<APIResponse<EmptyData>, APIError>) -> Void
    ) {
        let parameters: [String: Any] = ["otp": otp]
        let headers = getHeader.shared.getAuthHeaders()
        
        print("📤 [REPO] Verifying Email OTP:")
        print("📍 [REPO] URL: \(UserAPIEndpoint.Auth.emailOtpVerification)")
        print("🔢 [REPO] OTP: \(otp)")
        
        APIClient.shared.request(
            UserAPIEndpoint.Auth.emailOtpVerification,
            method: .post,
            parameters: parameters,
            headers: headers
        ) { (result: Result<APIResponse<EmptyData>, APIError>) in
            switch result {
            case .success(let response):
                if response.success ?? false {
                    print("✅ [REPO] Email OTP verified successfully: \(response.message)")
                    
                    // Update UserSession
                    if let currentUser = UserSession.shared.currentUser {
                        print("✅ [REPO] Email verified for user: \(currentUser.email)")
                        UserSession.shared.setEmailVerified(true)
                    }
                    
                    completion(.success(response))
                } else {
                    print("❌ [REPO] OTP verification failed: \(response.message)")
                    completion(.failure(.custom(response.message)))
                }
                
            case .failure(let error):
                print("❌ [REPO] Network or decoding error verifying OTP: \(error)")
                completion(.failure(error))
            }
        }
    }
}
