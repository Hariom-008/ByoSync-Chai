import Foundation
import Alamofire

struct ChangeProfilePicRequest: Codable {
    let profilePicUrl: String
}

struct ChangeProfilePicResponse: Codable {
    let message: String?
}

protocol ProfilePictureRepositoryProtocol {
    func changeProfilePicture(imageUrl: String) async throws -> String
}

final class ProfilePictureRepository: ProfilePictureRepositoryProtocol {
    private let apiClient = APIClient.shared
    
    init() {
        print("🏗️ [REPO] ProfilePictureRepository initialized")
    }

    func changeProfilePicture(imageUrl: String) async throws -> String {
        let endpoint = UserAPIEndpoint.EditProfile.changeProfilePic
        let request = ChangeProfilePicRequest(profilePicUrl: imageUrl)
        let headers: HTTPHeaders = getHeader.shared.getAuthHeaders()
        
        print("📤 [REPO] PATCH request to: \(endpoint)")
        print("📦 [REPO] Body: \(request.profilePicUrl)")
        
        return try await withCheckedThrowingContinuation { continuation in
            apiClient.request(
                endpoint,
                method: .patch,
                parameters: try? request.asDictionary(),
                headers: headers
            ) { (result: Result<ChangeProfilePicResponse, APIError>) in
                switch result {
                case .success(let response):
                    let message = response.message ?? "Profile picture updated successfully!"
                    print("✅ [REPO] Backend response: \(message)")
                    continuation.resume(returning: message)
                case .failure(let error):
                    print("❌ [REPO] API Error: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    deinit {
        print("♻️ [REPO] ProfilePictureRepository deallocated")
    }
}

extension Encodable {
    func asDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        return json as? [String: Any] ?? [:]
    }
}
