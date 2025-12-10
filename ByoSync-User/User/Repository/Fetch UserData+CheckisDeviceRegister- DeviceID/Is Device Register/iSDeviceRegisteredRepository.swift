//
//  iSDeviceRegisteredRepository.swift
//  ByoSync-User
//
//  Created by Hari's Mac on 10.12.2025.
//

import SwiftUI
import Foundation
import Alamofire

struct DeviceRegistrationData: Codable {
    let userId: String
    let hasFaceData: Bool
}

struct DeviceRegistrationResponse: Codable {
    let statusCode: Int
    let data: DeviceRegistrationData
    let message: String
    let success: Bool
}



/// Repository responsible for checking if a device is registered
final class DeviceRegistrationRepository {
    
    static let shared = DeviceRegistrationRepository()
    
    private let hmacGenerator = HMACGenerator.self
    
    /// Check if a device is registered for a given deviceKey
    ///
    /// - Parameters:
    ///   - deviceKey: raw device key string
    ///   - completion: returns full DeviceRegistrationResponse on success
    func isDeviceRegistered(
        deviceKey: String,
        completion: @escaping (Result<DeviceRegistrationResponse, APIError>) -> Void
    ) {
        // 1. Compute HMAC of the device key
        let deviceKeyHash = hmacGenerator.generateHMAC(jsonString: deviceKey)
        
        // 2. Headers (auth, token, etc.)
        let headers: HTTPHeaders = getHeader.shared.getAuthHeaders()
        
        // 3. Body
        let body: [String: Any] = [
            "deviceKeyHash": deviceKeyHash
        ]
        
        print("📤 [DeviceRegistrationRepository] isDeviceRegistered -> URL: \(UserAPIEndpoint.UserDeviceManagement.isDeviceRegistered)")
        print("📤 [DeviceRegistrationRepository] Headers: \(headers)")
        print("📤 [DeviceRegistrationRepository] Body: \(body)")
        
        // 4. POST call using APIClient
        APIClient.shared.request(
            UserAPIEndpoint.UserDeviceManagement.isDeviceRegistered,
            method: .post,
            parameters: body,
            headers: headers
        ) { (result: Result<DeviceRegistrationResponse, APIError>) in
            switch result {
            case .success(let response):
                print("✅ [DeviceRegistrationRepository] statusCode=\(response.statusCode), " +
                      "success=\(response.success), message='\(response.message)'")
                print("✅ [DeviceRegistrationRepository] userId=\(response.data.userId), " +
                      "hasFaceData=\(response.data.hasFaceData)")
                completion(.success(response))
                
            case .failure(let error):
                print("❌ [DeviceRegistrationRepository] Failed to check device registration: \(error)")
                completion(.failure(error))
            }
        }
    }
}
