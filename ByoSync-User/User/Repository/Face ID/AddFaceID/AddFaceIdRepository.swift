//
//  AddFaceIdRepository.swift
//  ByoSync-User
//
//  Created by Hari's Mac on 10.12.2025.
//

import Foundation
import Foundation
import Alamofire

/// Repository responsible for uploading FaceId to backend
final class FaceIdRepository {
    
    static let shared = FaceIdRepository()
    private init() {}
    
    /// Upload a single FaceId record
    ///
    /// - Parameters:
    ///   - token: auth/session token that must also go in body under "token"
    ///   - salt: salt string for this face
    ///   - faceId: FaceIdItem containing ecc/helper/hash/etc.
    ///   - completion: Result<Void, APIError> (no payload expected on success)
    func addFaceId(
        token: String,
        salt: String,
        faceId: FaceIdItem,
        completion: @escaping (Result<Void, APIError>) -> Void
    ) {
        // 1. Headers from your existing header helper
        let headers: HTTPHeaders = getHeader.shared.getAuthHeaders()
        
        // 2. Build faceId dictionary (skip nils)
        var faceIdDict: [String: Any] = [:]
        
        if let ecc = faceId.ecc {
            faceIdDict["ecc"] = ecc
        }
        if let helper = faceId.helper {
            faceIdDict["helper"] = helper
        }
        if let hashHex = faceId.hashHex {
            faceIdDict["hashHex"] = hashHex
        }
        if let r = faceId.r {
            faceIdDict["r"] = r
        }
        if let hashBits = faceId.hashBits {
            faceIdDict["hashBits"] = hashBits
        }
        if let id = faceId._id {
            faceIdDict["_id"] = id
        }
        
        // 3. Final body
        //    If backend expects key "Token" instead of "token", change it here.
        let body: [String: Any] = [
            "salt": salt,
            "token": token,
            "faceId": faceIdDict
        ]
        
        print("📤 [FaceIdRepository] addFaceId -> URL: \(UserAPIEndpoint.FaceId.addFaceId)")
        print("📤 [FaceIdRepository] Headers: \(headers)")
        print("📤 [FaceIdRepository] Body: \(body)")
        
        // 4. Fire request (no payload expected; only success flag / message)
        APIClient.shared.requestWithoutResponse(
            UserAPIEndpoint.FaceId.addFaceId,
            method: .post,
            parameters: body,
            headers: headers
        ) { result in
            switch result {
            case .success:
                print("✅ [FaceIdRepository] Successfully added faceId")
                completion(.success(()))
            case .failure(let error):
                print("❌ [FaceIdRepository] Failed to add faceId: \(error)")
                completion(.failure(error))
            }
        }
    }
}
