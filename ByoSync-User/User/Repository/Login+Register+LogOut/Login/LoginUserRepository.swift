//
//  LoginUserRepository.swift
//  ByoSync
//

import Foundation
import Alamofire
import SwiftUI

final class LoginUserRepository {
    
    // MARK: - Properties
    private let cryptoService: any CryptoService
    private let hmacGenerator = HMACGenerator.self
    
    // MARK: - Initialization
    init(cryptoService: any CryptoService) {
        self.cryptoService = cryptoService
    }

    // MARK: - Login Method (Generic)
    func login<T: Codable>(
        name: String,
        deviceKey: String,
        fcmToken: String,
        completion: @escaping (Result<APIResponse<T>, APIError>) -> Void
    ) {
        
        // Generate HMAC
        //let deviceKeyHash = hmacGenerator.generateHMAC(jsonString: deviceKey)
        let deviceKeyHash = deviceKey
        let loginData = LoginRequest(
            name: name,
            deviceKeyHash: deviceKeyHash,
            fcmToken: fcmToken
        )
        // Track API call performance
        let startTime = CFAbsoluteTimeGetCurrent()
        
        APIClient.shared.request(
            UserAPIEndpoint.Auth.logIn,
            method: .post,
            parameters: loginData.asDictionary(),
            headers: ["Content-Type": "application/json"]
        ) { (result: Result<APIResponse<T>, APIError>) in
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            
            switch result {
            case .success(let response):
                #if DEBUG
                print("✅ User is Logged In Successfully")
                #endif
                Logger.shared.log(
                    "Login successful for user: \(name) | Message: \(response.message)",
                    level: .info,
                    type: .apiCall,
                    performanceTime: timeElapsed
                )
                
                Logger.shared.info(
                    "User authenticated successfully",
                    type: .success
                )
                
                completion(.success(response))
            
            case .failure(let error):
                Logger.shared.log(
                    "Login API call failed for user: \(name)",
                    level: .error,
                    type: .badRequest,
                    performanceTime: timeElapsed
                )
                
                Logger.shared.error(
                    "Authentication failed: \(error.localizedDescription)",
                    type: .badRequest,
                    error: error
                )
                
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Convenience Method for User Login
    func loginUser(
        name: String,
        deviceKey: String,
        fcmToken: String,
        completion: @escaping (Result<APIResponse<LoginData>, APIError>) -> Void
    ) {
        login(name: name, deviceKey: deviceKey, fcmToken: fcmToken, completion: completion)
    }
    
    // MARK: - Deinitialization
    deinit {
      print("🍀 Login Repo dealloacted")
    }
}
