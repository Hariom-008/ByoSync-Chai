//
//  GetFaceId.swift
//  ByoSync-User
//
//  Created by Hari's Mac on 10.12.2025.
//

import Foundation

struct GetFaceIdData: Codable {
    let faceData: [FaceIdItem]
}

struct GetFaceIdResponse: Codable {
    let statusCode: Int
    let data: GetFaceIdData
    let message: String
    let success: Bool
}
import Foundation
import Alamofire

/// Repository responsible for fetching FaceId from backend
final class FaceIdFetchRepository {
    
    static let shared = FaceIdFetchRepository()
    
    private let hmacGenerator = HMACGenerator.self
    
    /// Fetch all FaceId items for a device key
    ///
    /// - Parameters:
    ///   - deviceKey: raw device key string
    ///   - completion: returns array of FaceIdItem on success
    func getFaceIds(
        deviceKey: String,
        completion: @escaping (Result<[FaceIdItem], APIError>) -> Void
    ) {
        // 1. Generate HMAC hash
        let deviceKeyHash = hmacGenerator.generateHMAC(jsonString: deviceKey)
        
        // 2. Headers (auth + Token etc.)
        let headers: HTTPHeaders = getHeader.shared.getAuthHeaders()
        
        // 3. Body as required by backend
        let body: [String: Any] = [
            "deviceKeyHash": deviceKeyHash
        ]
        
        print("📤 [FaceIdFetchRepository] getFaceIds -> URL: \(UserAPIEndpoint.FaceId.getFaceId)")
        print("📤 [FaceIdFetchRepository] Headers: \(headers)")
        print("📤 [FaceIdFetchRepository] Body: \(body)")
        
        // 4. Fire request (GET with JSON body; backend expects body)
        APIClient.shared.request(
            UserAPIEndpoint.FaceId.getFaceId,
            method: .get,
            parameters: body,
            headers: headers
        ) { (result: Result<GetFaceIdResponse, APIError>) in
            switch result {
            case .success(let response):
                print("✅ [FaceIdFetchRepository] StatusCode: \(response.statusCode) " +
                      "success: \(response.success) message: \(response.message)")
                let items = response.data.faceData
                print("✅ [FaceIdFetchRepository] Received \(items.count) faceId items")
                completion(.success(items))
                
            case .failure(let error):
                print("❌ [FaceIdFetchRepository] Failed to fetch faceId: \(error)")
                completion(.failure(error))
            }
        }
    }
}
