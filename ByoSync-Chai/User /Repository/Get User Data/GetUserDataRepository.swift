//
//  GetUserDataRepository.swift
//  ByoSync
//
//  Created by Hari's Mac on 18.10.2025.
//

import Foundation
import Alamofire
import SwiftUI

// MARK: - Protocol for Testability
protocol GetUserDataRepositoryProtocol {
    func getUserData(
        completion: @escaping (Result<APIResponse<LoginData>, APIError>) -> Void
    )
}

final class GetUserDataRepository: GetUserDataRepositoryProtocol {
    
    // MARK: - Initialization (No Singleton)
    init() {
        #if DEBUG
        print("🏗️ [REPO] GetUserDataRepository initialized")
        #endif
    }
    
    func getUserData(
        completion: @escaping (Result<APIResponse<LoginData>, APIError>) -> Void
    ) {
        #if DEBUG
        print("📤 [REPO] Fetching User Data")
        print("📍 [REPO] URL: \(UserAPIEndpoint.UserData.getUserData)")
        #endif
        
        APIClient.shared.request(
            UserAPIEndpoint.UserData.getUserData,
            method: .post
        ) { (result: Result<APIResponse<LoginData>, APIError>) in
            switch result {
            case .success(let response):
                #if DEBUG
                print("✅ [REPO] User fetched successfully")
                print("💬 [REPO] Response: \(response.message)")
                #endif
                
                // Extract user and device data from response
                guard let userData = response.data?.user,
                      let deviceData = response.data?.device else {
                    #if DEBUG
                    print("❌ [REPO] Invalid response data structure")
                    #endif
                    completion(.failure(.custom("Invalid response data")))
                    return
                }
                
                // Convert to User model
                let user = User(
                    firstName: userData.firstName,
                    lastName: userData.lastName,
                    email: userData.email,
                    phoneNumber: userData.phoneNumber,
                    deviceKey: deviceData.deviceKey,
                    deviceName: deviceData.deviceName
                )
                
                // Save to session
                UserSession.shared.saveUser(user)
                
                  // Save device information
                 let deviceId = deviceData.deviceKey
                    UserSession.shared.setCurrentDeviceID(deviceId)
                
                // Update email verification status
                UserSession.shared.setEmailVerified(userData.emailVerified)
                
                // Update profile picture
                if ((userData.profilePic?.isEmpty) == nil) {
                    UserSession.shared.setProfilePicture(userData.profilePic ?? "")
                    print("✅ [REPO] Profile picture URL saved")
                }
                
                // Update device primary status
                UserSession.shared.setThisDevicePrimary(deviceData.isPrimary)
                
                // Save device token if available
                let token = deviceData.token
                UserDefaults.standard.set(token, forKey: "deviceToken")

                #if DEBUG
                print("""
                      ✅ [REPO] User Details Updated:
                      Name: \(user.firstName) \(user.lastName)
                      Email: \(user.email)
                      Phone: \(user.phoneNumber ?? "N/A")
                      Device ID: \(deviceData.deviceKey)
                      Device Name: \(user.deviceName ?? "N/A")
                      Email Verified: \(userData.emailVerified)
                      Is Primary: \(deviceData.isPrimary)
                      """)
                #endif
                completion(.success(response))
                
            case .failure(let error):
                #if DEBUG
                print("❌ [REPO] User Fetch failed: \(error.localizedDescription)")
                #endif
                completion(.failure(error))
            }
        }
    }
    
    deinit {
        #if DEBUG
        print("♻️ [REPO] GetUserDataRepository deallocated")
        #endif
    }
}
