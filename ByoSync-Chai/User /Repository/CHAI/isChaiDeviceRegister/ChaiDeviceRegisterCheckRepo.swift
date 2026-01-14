//
//  iSDeviceRegisteredRepository.swift
//  ByoSync-User
//
//  Created by Hari's Mac on 10.12.2025.
//

import SwiftUI
import Foundation
import Alamofire

struct ChaiDeviceRegistrationData: Codable {
        let id: String
        let deviceKey: String
        let deviceKeyHash: String
        let deviceName: String
        let deviceData: ChaiDeviceData
        let createdAt: String
        let updatedAt: String
        let v: Int

        enum CodingKeys: String, CodingKey {
            case id = "_id"
            case deviceKey, deviceKeyHash, deviceName, deviceData, createdAt, updatedAt
            case v = "__v"
        }
}
struct ChaiDeviceData: Codable {
    let model: String
    let platform: String
    let systemVersion: String
}


struct ChaiDeviceRegistrationResponse: Codable {
    let statusCode: Int
      let message: String
      let data: ChaiDeviceRegistrationData
      let success: Bool
      let demoMode: Bool
}

/// Repository responsible for checking if a device is registered
final class ChaiDeviceRegisterCheckRepo {
    
    static let shared = ChaiDeviceRegisterCheckRepo()
    
    private let hmacGenerator = HMACGenerator.self
    
    /// Check if a device is registered for a given deviceKey
    ///
    /// - Parameters:
    ///   - deviceKey: raw device key string
    ///   - completion: returns full DeviceRegistrationResponse on success
    func isDeviceRegistered(
        deviceKey: String,
        completion: @escaping (Result<ChaiDeviceRegistrationResponse, APIError>) -> Void
    ) {
        // 1. Compute HMAC of the device key
        let deviceKeyHash = hmacGenerator.generateHMAC(jsonString: deviceKey)
       // let deviceKeyHash = deviceKey
        // 2. Headers (auth, token, etc.)
        let headers: HTTPHeaders = getHeader.shared.getAuthHeaders()
        var fcmToken = ""
        FCMTokenManager.shared.getFCMToken { token in fcmToken = token ?? "" }
        
        // 3. Body
        let body: [String: Any] = [
            "deviceKeyHash": deviceKeyHash,
            "fcmToken": fcmToken
        ]
        #if DEBUG
        print("📤 [DeviceRegistrationRepository] isDeviceRegistered -> URL: \(ChaiEndpoints.isChaiDeviceRegister)")
        print("📤 [DeviceRegistrationRepository] Headers: \(headers)")
        print("📤 [DeviceRegistrationRepository] Body: \(body)")
        #endif
        // 4. POST call using APIClient
        APIClient.shared.request(
            ChaiEndpoints.isChaiDeviceRegister,
            method: .post,
            parameters: body,
            headers: headers
        ) { (result: Result<ChaiDeviceRegistrationResponse, APIError>) in
            switch result {
            case .success(let response):
                print("✅ [DeviceRegistrationRepository] statusCode=\(response.statusCode), " +
                      "success=\(response.success), message='\(response.message)'")
                
                completion(.success(response))
                
            case .failure(let error):
                print("❌ [DeviceRegistrationRepository] Failed to check device registration: \(error)")
                completion(.failure(error))
            }
        }
    }
}
