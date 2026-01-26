//
//  AddFaceIdRepository.swift
//  ByoSync-User
//

import Foundation
import Alamofire

final class FaceIdRepository {
    
    static let shared = FaceIdRepository()
    private init() {}
    
    /// Upload multiple FaceId items (backend expects array)
    func addFaceIds(
        userId:String,
        salt: String,
        records: [AddFaceIdRequestBody],
        completion: @escaping (Result<Void, APIError>) -> Void
    ) {
        let headers = getHeader.shared.getAuthHeaders()
        
        // Convert `[AddFaceIdRequestBody]` → `[[String: Any]]`
        let faceIdArray: [[String: Any]]
        do {
            let jsonData = try JSONEncoder().encode(records)
            faceIdArray = (try JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]]) ?? []
        } catch {
            completion(.failure(.custom("Encoding error: \(error.localizedDescription)")))
            return
        }

        let body: [String: Any] = [
            "userId": userId,
            "salt": salt,
            "faceId": faceIdArray
        ]

        #if DEBUG
        do {
            // Serialize body -> JSON data
            let data = try JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys])

            // Print byte size (super useful for 413 debugging)
            print("\n📤 [FaceIdRepository] addFaceIds → URL: \(UserAPIEndpoint.FaceId.addFaceId)")
            print("📤 Headers: \(headers)")
            print("📦 Body bytes: \(data.count) (~\(String(format: "%.2f", Double(data.count)/1024.0)) KB)")

            // Print JSON as String
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📤 Body JSON:\n\(jsonString)\n")
            } else {
                print("⚠️ Could not convert JSON data to UTF-8 string\n")
            }
        } catch {
            print("❌ [FaceIdRepository] JSON print failed: \(error)\n")
        }
        #endif

        APIClient.shared.requestWithoutResponse(
            UserAPIEndpoint.FaceId.addFaceId,
            method: .post,
            parameters: body,
            headers: headers
        ) { result in
            switch result {
            case .success:
                #if DEBUG
                print("✅ Successfully uploaded faceId list")
                #endif
                completion(.success(()))
            case .failure(let error):
                #if DEBUG
                print("❌ Failed: \(error)")
                #endif
                completion(.failure(error))
            }
        }
    }

    
    /// Upload **one** record
    func addFaceId(
        userId:String,
        salt: String,
        helper: String,
        k2: String,
        token: String,
        iod: String,
        completion: @escaping (Result<Void, APIError>) -> Void
    ) {
        let item = AddFaceIdRequestBody(helper: helper, k2: k2, token: token,iod: iod)
        addFaceIds(userId: userId,salt: salt, records: [item], completion: completion)
    }
}
