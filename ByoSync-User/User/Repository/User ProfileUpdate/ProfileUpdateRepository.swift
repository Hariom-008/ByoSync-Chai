//
//  ProfileUpdateRepository.swift
//  ByoSync
//
//  Created by Hari's Mac on 22.10.2025.
//

import Foundation
import Alamofire

// For PATCH /change-details (returns user directly in data)
struct MerchantProfileResponse: Codable {
    let statusCode: Int
    let data: MerchantData  // ✅ Direct UserData, not nested
    let message: String
}

// For GET /get-user-data and POST /login (returns user and device nested)
struct ProfileUpdateResponse: Codable {
    let statusCode: Int
    let data: ProfileUpdateData
    let message: String
}

struct MerchantData: Codable {
    let email: String
    let firstName: String
    let lastName: String
    let phoneNumber: String
    let pattern: [String]
    let salt: String
    let faceToken: String
    let role: String
    let merchantName: String
    let gstNumber: String
    let address: Address
    let profilePic: String
    let devices: [String]
    let emailVerified: Bool
    let id: String
    let faceId: [String]
    let createdAt: String
    let updatedAt: String
    let v: Int
    
    enum CodingKeys: String, CodingKey {
        case email
        case firstName
        case lastName
        case phoneNumber
        case pattern
        case salt
        case faceToken
        case role
        case merchantName
        case gstNumber
        case address
        case profilePic
        case devices
        case emailVerified
        case id = "_id"
        case faceId
        case createdAt
        case updatedAt
        case v = "__v"
    }
}

protocol ProfileUpdateRepositoryProtocol {
    func updateProfile(
        firstName: String,
        lastName: String,
        email: String,
        completion: @escaping (Result<MerchantProfileResponse, APIError>) -> Void
    )
    
    func getProfile(completion: @escaping (Result<ProfileUpdateResponse, APIError>) -> Void)
}

final class ProfileUpdateRepository: ProfileUpdateRepositoryProtocol {
    
    // MARK: - Initialization (No Singleton)
    init() {
        print("🏗️ [REPO] ProfileUpdateRepository initialized")
    }

    // MARK: - Profile Update (PATCH) - Returns user directly
    func updateProfile(
        firstName: String,
        lastName: String,
        email: String,
        completion: @escaping (Result<MerchantProfileResponse, APIError>) -> Void
    ) {
        let parameters: [String: Any] = [
            "firstName": firstName,
            "lastName": lastName,
            "email": email
        ]
        
        let headers = getHeader.shared.getAuthHeaders()
        #if DEBUG
        print("\n📤 [REPO] UPDATE PROFILE REQUEST:")
        print("📍 [REPO] URL: \(UserAPIEndpoint.EditProfile.changeDetails)")
        print("📝 [REPO] Method: PATCH")
        print("📦 [REPO] Parameters: \(parameters)")
        #endif
    
        APIClient.shared.request(
            UserAPIEndpoint.EditProfile.changeDetails,
            method: .patch,
            parameters: parameters,
            headers: headers,
            completion: completion
        )
    }
    
    // MARK: - Get Profile (GET) - Returns user and device
    func getProfile(completion: @escaping (Result<ProfileUpdateResponse, APIError>) -> Void) {
        let headers = getHeader.shared.getAuthHeaders()
        
        #if DEBUG
        print("\n📥 [REPO] GET PROFILE REQUEST:")
        print("📍 [REPO] URL: \(UserAPIEndpoint.EditProfile.changeDetails)")
        print("📝 [REPO] Method: GET")
        #endif
        
        APIClient.shared.request(
            UserAPIEndpoint.EditProfile.changeDetails,
            method: .get,
            headers: headers,
            completion: completion
        )
    }
    
    deinit {
        #if DEBUG
        print("♻️ [REPO] ProfileUpdateRepository deallocated")
        #endif
    }
}
