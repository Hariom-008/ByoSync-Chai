import Foundation
import Alamofire

final class UserDevicesRepository {
    
    // MARK: - Initialization (No Singleton)
    init() {
        print("🏗️ [REPO] UserDevicesRepository initialized")
    }

    // MARK: - Get Linked Devices
    func getUserDevices(completion: @escaping (Result<[GetDeviceData], APIError>) -> Void) {
        let endpoint = UserAPIEndpoint.UserDeviceManagement.getLinkedDevices
        let headers = getHeader.shared.getAuthHeaders()
        
        print("📤 [REPO] Fetching user devices")
        print("📍 [REPO] URL: \(endpoint)")
        
        APIClient.shared.request(
            endpoint,
            method: .get,
            headers: headers
        ) { (result: Result<APIResponse<[GetDeviceData]>, APIError>) in
            switch result {
            case .success(let response):
                if response.success ?? false, let devices = response.data {
                    print("✅ [REPO] Fetched \(devices.count) devices successfully")
                    completion(.success(devices))
                } else {
                    print("❌ [REPO] Failed to fetch devices: \(response.message)")
                    completion(.failure(.custom(response.message)))
                }
            case .failure(let error):
                print("❌ [REPO] API failure fetching devices: \(error)")
                completion(.failure(error))
            }
        }
    }

    // MARK: - Change Primary Device
    func changePrimaryDevice(deviceId: String, completion: @escaping (Result<String, APIError>) -> Void) {
        let endpoint = UserAPIEndpoint.UserDeviceManagement.changePrimaryDevice
        let headers = getHeader.shared.getAuthHeaders()
        let params: [String: Any] = ["deviceId": deviceId]

        print("📤 [REPO] Changing primary device")
        print("📍 [REPO] Device ID: \(deviceId)")
        
        APIClient.shared.requestWithoutValidation(
            endpoint,
            method: .patch,
            parameters: params,
            headers: headers,
            skipValidation: true
        ) { (result: Result<APIResponse<EmptyData>, APIError>) in
            switch result {
            case .success(let response):
                if response.success ?? false {
                    print("✅ [REPO] Primary device changed successfully: \(response.message)")
                    completion(.success(response.message))
                } else {
                    print("❌ [REPO] Failed to change primary device: \(response.message)")
                    completion(.failure(.custom(response.message)))
                }
            case .failure(let error):
                print("❌ [REPO] API failure changing primary device: \(error)")
                completion(.failure(error))
            }
        }
    }

    // MARK: - Unlink Other Devices
    func unlinkOtherDevices(completion: @escaping (Result<String, APIError>) -> Void) {
        let endpoint = UserAPIEndpoint.UserDeviceManagement.unLinkOtherDevices
        let headers = getHeader.shared.getAuthHeaders()
        let currentDeviceId = UserSession.shared.currentUserDeviceID
        
        guard !currentDeviceId.isEmpty else {
            print("❌ [REPO] No device ID found")
            completion(.failure(.custom("No device ID found.")))
            return
        }

        let params: [String: Any] = ["deviceId": currentDeviceId]
        
        print("📤 [REPO] Unlinking other devices")
        print("📍 [REPO] Current Device ID: \(currentDeviceId)")
        
        APIClient.shared.request(
            endpoint,
            method: .post,
            parameters: params,
            headers: headers
        ) { (result: Result<APIResponse<EmptyData>, APIError>) in
            switch result {
            case .success(let response):
                if response.success ?? false {
                    print("✅ [REPO] Other devices unlinked successfully: \(response.message)")
                    completion(.success(response.message))
                } else {
                    print("❌ [REPO] Failed to unlink other devices: \(response.message)")
                    completion(.failure(.custom(response.message)))
                }
            case .failure(let error):
                print("❌ [REPO] API failure unlinking other devices: \(error)")
                completion(.failure(error))
            }
        }
    }

    // MARK: - Unlink This Device (for non-primary devices)
    func unlinkThisDevice(deviceId: String, completion: @escaping (Result<String, APIError>) -> Void) {
        let endpoint = UserAPIEndpoint.UserDeviceManagement.unLinkOtherDevices
        let headers = getHeader.shared.getAuthHeaders()
        let params: [String: Any] = ["deviceId": deviceId]
        
        print("📤 [REPO] Unlinking device")
        print("📍 [REPO] Device ID: \(deviceId)")
        
        APIClient.shared.request(
            endpoint,
            method: .post,
            parameters: params,
            headers: headers
        ) { (result: Result<APIResponse<EmptyData>, APIError>) in
            switch result {
            case .success(let response):
                if response.success ?? false {
                    print("✅ [REPO] Device unlinked successfully: \(response.message)")
                    completion(.success(response.message))
                } else {
                    print("❌ [REPO] Failed to unlink device: \(response.message)")
                    completion(.failure(.custom(response.message)))
                }
            case .failure(let error):
                print("❌ [REPO] API failure unlinking device: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    deinit {
        print("♻️ [REPO] UserDevicesRepository deallocated")
    }
}
