//
//  GetFaceId.swift
//  ByoSync-User
//
//  Created by Hari's Mac on 10.12.2025.
//

import Foundation
import Alamofire

struct FaceId: Codable,Equatable {
    let helper: String
    let k2: String
    let token: String
}

struct GetFaceIdData: Codable,Equatable {
    let salt: String
    let faceData: [FaceId]
}

struct GetFaceIdResponse: Codable {
    let statusCode: Int
    let data: GetFaceIdData
    let message: String
    let success: Bool
}

/// Repository responsible for fetching FaceId from backend
final class FaceIdFetchRepository {
    
    static let shared = FaceIdFetchRepository()
    
    private let hmacGenerator = HMACGenerator.self
    
    /// Fetch FaceId data (salt + faceData) for a device key
    ///
    /// - Parameters:
    ///   - deviceKey: raw device key string
    ///   - completion: returns `GetFaceIdData` on success
    func getFaceIds(
        deviceKeyHash: String,
        completion: @escaping (Result<GetFaceIdData, APIError>) -> Void
    ) {
        // 1. Generate HMAC hash
        let deviceKeyHash = deviceKeyHash
        // 2. Headers (auth + Token etc.)
        let headers: HTTPHeaders = getHeader.shared.getAuthHeaders()
        
        // 3. Body as required by backend
        let body: [String: Any] = [
            "deviceKeyHash": deviceKeyHash
        ]
        
        print("📤 [FaceIdFetchRepository] getFaceIds -> URL: \(UserAPIEndpoint.FaceId.getFaceId)")
        print("📤 [FaceIdFetchRepository] Headers: \(headers)")
        print("📤 [FaceIdFetchRepository] Body: \(body)")
        
        // 4. Fire request
        APIClient.shared.request(
            UserAPIEndpoint.FaceId.getFaceId,
            method: .post,
            parameters: body,
            headers: headers
        ) { (result: Result<GetFaceIdResponse, APIError>) in
            switch result {
            case .success(let response):
                print("✅ [FaceIdFetchRepository] StatusCode: \(response.statusCode) " +
                      "success: \(response.success) message: \(response.message)")
                
                let data = response.data
                print("✅ [FaceIdFetchRepository] Received salt: \(data.salt)")
                print("✅ [FaceIdFetchRepository] Received \(data.faceData.count) FaceId items")
                
                completion(.success(data))
                
            case .failure(let error):
                print("❌ [FaceIdFetchRepository] Failed to fetch faceId: \(error)")
                completion(.failure(error))
            }
        }
    }
}
