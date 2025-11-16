import Foundation
import SwiftUI
import Alamofire
import CryptoKit

// MARK: - Response Models
struct RegisterUserResponse: Codable {
    let success: Bool
    let message: String
    let data: User?
}

struct RegisterUserRequest: Encodable {
    let firstName: String
    let lastName: String
    let email: String
    let emailHash: String
    let phoneNumber: String
    let phoneNumberHash: String
    let deviceKey: String
    let deviceKeyHash: String
    let deviceName: String
    let fcmToken: String
    let referralCode: String?
}

final class RegisterUserRepository {
    
    // ✅ Remove singleton, use dependency injection instead
    private let cryptoService: any CryptoService
    private let hmacGenerator = HMACGenerator.self
    
    // ✅ Inject dependencies via initializer
    init(cryptoService: any CryptoService) {
        self.cryptoService = cryptoService
    }
    
    func registerUser(
        firstName: String,
        lastName: String,
        email: String,
        phoneNumber: String,
        deviceId: String,
        deviceName: String,
        completion: @escaping (Result<APIResponse<LoginData>, APIError>) -> Void
    ) {
        print("📤 [API] POST \(UserAPIEndpoint.Auth.userRegister)")
        
        var fcmToken = ""
        FCMTokenManager.shared.getFCMToken { token in
            guard let token else { return }
            fcmToken = token
        }
        
        // ✅ Use injected cryptoService instead of @EnvironmentObject
        let user = RegisterUserRequest(
            firstName: cryptoService.encrypt(text: firstName) ?? "",
            lastName: cryptoService.encrypt(text: lastName) ?? "",
            email: cryptoService.encrypt(text: email) ?? "",
            emailHash: hmacGenerator.generateHMAC(jsonString: email),
            phoneNumber: cryptoService.encrypt(text: phoneNumber) ?? "",
            phoneNumberHash: hmacGenerator.generateHMAC(jsonString: phoneNumber),
            deviceKey: deviceId,
            deviceKeyHash: hmacGenerator.generateHMAC(jsonString: deviceId),
            deviceName: deviceName,
            fcmToken: fcmToken,
            referralCode: ""
        )
        
        // Encode User to JSON string with consistent formatting
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        
        guard let jsonData = try? encoder.encode(user),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            print("❌ [API] Failed to encode user data")
            completion(.failure(.failedToGenerateHmac))
            return
        }
        
        print("📦 [API] Request body prepared for: \(email)")
        
        // Use the SAME jsonString for both HMAC and request body
        requestWithJSONString(
            url: UserAPIEndpoint.Auth.userRegister,
            method: .post,
            jsonString: jsonString,
            userData: user
        ) { result in
            switch result {
            case .success(let response):
                print("✅ [API] Registration successful")
                self.handleSuccessfulRegistration(response: response, originalData: user, completion: completion)
                
            case .failure(let error):
                print("❌ [API] Registration failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Handle Successful Registration
    private func handleSuccessfulRegistration(
        response: APIResponse<LoginData>,
        originalData: RegisterUserRequest,
        completion: @escaping (Result<APIResponse<LoginData>, APIError>) -> Void
    ) {
        let userData = response.data?.user
        let deviceData = response.data?.device
        
        // Save token to UserDefaults
        if let token = deviceData?.token, !token.isEmpty {
            UserDefaults.standard.set(token, forKey: "token")
            print("🔐 [SESSION] Token saved")
        } else {
            print("⚠️ [SESSION] No token in response")
        }
        
        // Create registered user
        let registeredUser = User(
            firstName: userData?.firstName ?? originalData.firstName,
            lastName: userData?.lastName ?? originalData.lastName,
            email: userData?.email ?? originalData.email,
            phoneNumber: userData?.phoneNumber ?? originalData.phoneNumber,
            deviceKey: deviceData?.deviceKey ?? originalData.deviceKey,
            deviceName: deviceData?.deviceName ?? originalData.deviceName
        )
        
        // Save to UserSession
        UserSession.shared.saveUser(registeredUser)
        UserSession.shared.setEmailVerified(userData?.emailVerified ?? false)
        UserSession.shared.setProfilePicture(userData?.profilePic ?? "")
        UserSession.shared.setCurrentDeviceID(deviceData?.id ?? "")
        UserSession.shared.setThisDevicePrimary(deviceData?.isPrimary ?? false)
        
        // Log important session data
        print("💾 [SESSION] User saved to session")
        print("📧 [SESSION] Email verified: \(userData?.emailVerified ?? false)")
        print("📱 [SESSION] Primary device: \(deviceData?.isPrimary ?? false)")
        
        if let profilePic = userData?.profilePic, !profilePic.isEmpty {
            print("🖼️ [SESSION] Profile picture URL saved")
        }
        
        completion(.success(response))
    }
    
    // MARK: - Request with JSON String
    private func requestWithJSONString(
        url: String,
        method: HTTPMethod,
        jsonString: String,
        userData: RegisterUserRequest,
        completion: @escaping (Result<APIResponse<LoginData>, APIError>) -> Void
    ) {
        let timestamp = String(Int(Date().timeIntervalSince1970 * 1000))
        let signature = HMACGenerator.generateHMAC(jsonString: jsonString)
        
        // Create headers
        let headers: HTTPHeaders = [
            "Content-Type": "application/json",
            "x-signature": signature,
            "x-timestamp": timestamp,
            "x-nonce": timestamp,
            "x-idempotency-key": timestamp
        ]
        
        print("🔑 [SECURITY] HMAC signature generated")
        print("⏰ [SECURITY] Timestamp: \(timestamp)")
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            print("❌ [API] Failed to convert JSON string to data")
            completion(.failure(.mismatchedHmac))
            return
        }
        
        guard let requestUrl = URL(string: url) else {
            print("❌ [API] Invalid URL: \(url)")
            completion(.failure(.unknown))
            return
        }
        
        var request = URLRequest(url: requestUrl)
        request.httpMethod = method.rawValue
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add all headers to the request
        headers.dictionary.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        print("🌐 [API] Sending request...")
        
        // Use the updated APIClient method that returns LoginData
        APIClient.shared.requestWithCustomBodyAndResponse(request, completion: completion)
    }
}
