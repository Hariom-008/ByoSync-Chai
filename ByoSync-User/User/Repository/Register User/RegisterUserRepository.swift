import Foundation
import SwiftUI
import Alamofire
import AVFoundation
import UIKit
import CryptoKit

// MARK: - Response Models
struct RegisterUserResponse: Codable {
    let success: Bool
    let message: String
    let data: RegisterUserData?
}

struct RegisterUserData: Codable {
    let user: UserData
    let device: DeviceData
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
    let deviceData: String  // Device data should be a string
}

// MARK: - DeviceDetails Models
struct DeviceDetails: Encodable {
    let manufacturer: String
    let model: String
    let brand: String
    let deviceName: String
    let sdkInt: Int
    let iosVersion: String
    let supportedAbis: [String]

    let cpuCoreCount: Int
    let cpuMaxFreqHz: Int?           // best-effort (may be null)

    let totalRamBytes: Int
    let totalStorageBytes: Int
    let freeStorageBytes: Int

    let frontCamera: FrontCameraDetails?
}

struct FrontCameraDetails: Encodable {
    let cameraId: String
    let focalLengthMm: Float?
    let sensorWidthMm: Float?
    let sensorHeightMm: Float?

    let pixelArrayWidth: Int?
    let pixelArrayHeight: Int?

    let horizontalFovDegrees: Double?
    let verticalFovDegrees: Double?
}

func fetchDeviceDetails() -> DeviceDetails {
    let device = UIDevice.current
    let manufacturer = "Apple"  // Static for iOS
    let model = device.model
    let brand = "Apple"         // Static for iOS
    let deviceName = device.name
    let sdkInt = Int(device.systemVersion.split(separator: ".")[0]) ?? 0
    let iosVersion = device.systemVersion
    let supportedAbis = ["arm64"]  // iOS typically supports arm64

    let cpuCoreCount = ProcessInfo.processInfo.processorCount
    let totalRamBytes = ProcessInfo.processInfo.physicalMemory
    let totalStorageBytes = FileManager.default.totalDiskSpace
    let freeStorageBytes = FileManager.default.freeDiskSpace
    
    let frontCameraDetails = fetchFrontCameraDetails()

    return DeviceDetails(
        manufacturer: manufacturer,
        model: model,
        brand: brand,
        deviceName: deviceName,
        sdkInt: sdkInt,
        iosVersion: iosVersion,
        supportedAbis: supportedAbis,
        cpuCoreCount: cpuCoreCount,
        cpuMaxFreqHz: nil,  // iOS doesn't expose this directly
        totalRamBytes: Int(totalRamBytes),
        totalStorageBytes: totalStorageBytes,
        freeStorageBytes: freeStorageBytes,
        frontCamera: frontCameraDetails
    )
}

func fetchFrontCameraDetails() -> FrontCameraDetails? {
    guard let device = AVCaptureDevice.default(for: .video) else { return nil }
    guard device.position == .front else { return nil }

    let cameraId = device.uniqueID
    let focalLengthMm = device.lensPosition // Approximation
    let sensorWidthMm: Float? = nil  // iOS does not provide this directly
    let sensorHeightMm: Float? = nil // iOS does not provide this directly

    let pixelArrayWidth: Int? = nil  // iOS does not provide this directly
    let pixelArrayHeight: Int? = nil // iOS does not provide this directly

    let horizontalFovDegrees = 70.0  // Approximation for iPhone front cameras
    let verticalFovDegrees = 55.0    // Approximation for iPhone front cameras

    return FrontCameraDetails(
        cameraId: cameraId,
        focalLengthMm: focalLengthMm,
        sensorWidthMm: sensorWidthMm,
        sensorHeightMm: sensorHeightMm,
        pixelArrayWidth: pixelArrayWidth,
        pixelArrayHeight: pixelArrayHeight,
        horizontalFovDegrees: horizontalFovDegrees,
        verticalFovDegrees: verticalFovDegrees
    )
}

extension FileManager {
    var totalDiskSpace: Int {
        if let attributes = try? self.attributesOfFileSystem(forPath: NSHomeDirectory()),
           let space = attributes[.systemSize] as? NSNumber {
            return space.intValue
        }
        return 0
    }

    var freeDiskSpace: Int {
        if let attributes = try? self.attributesOfFileSystem(forPath: NSHomeDirectory()),
           let freeSpace = attributes[.systemFreeSize] as? NSNumber {
            return freeSpace.intValue
        }
        return 0
    }
}

// MARK: Register User Repository
final class RegisterUserRepository {

    private let cryptoService: any CryptoService
    private let hmacGenerator = HMACGenerator.self
    
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
        
        let deviceDetails = fetchDeviceDetails()  // Fetch device details

        // Convert DeviceDetails into JSON string to match Android format
        let encoder = JSONEncoder()
        guard let deviceDataJson = try? encoder.encode(deviceDetails),
              let deviceDataString = String(data: deviceDataJson, encoding: .utf8) else {
            print("❌ [API] Failed to encode device data")
            completion(.failure(.failedToGenerateHmac))
            return
        }

        // Create RegisterUserRequest
        let user = RegisterUserRequest(
            firstName: cryptoService.encrypt(text: firstName) ?? "",
            lastName: cryptoService.encrypt(text: lastName) ?? "",
            email: cryptoService.encrypt(text: email) ?? "",
            emailHash: hmacGenerator.generateHMAC(jsonString: email),
            phoneNumber: cryptoService.encrypt(text: phoneNumber) ?? "",
            phoneNumberHash: hmacGenerator.generateHMAC(jsonString: phoneNumber),
            deviceKey: deviceId,
            deviceKeyHash: deviceId.isEmpty ? "" : hmacGenerator.generateHMAC(jsonString: deviceId),
            deviceName: deviceName,
            fcmToken: fcmToken,
            referralCode: nil,
            deviceData: deviceDataString  // Use serialized device data string
        )
        
        // Encode User to JSON string with consistent formatting
        let encoder2 = JSONEncoder()
        encoder2.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        
        guard let jsonData = try? encoder2.encode(user),
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
