import Foundation
import Alamofire

protocol ChaiRepositoryProtocol {
    func updateChai(userId: String, completion: @escaping (Result<APIResponse<EmptyData>, APIError>) -> Void)
    func updateChai(userId: String) async throws -> APIResponse<EmptyData>
}

final class ChaiRepository: ChaiRepositoryProtocol {
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    func updateChai(
        userId: String,
        completion: @escaping (Result<APIResponse<EmptyData>, APIError>) -> Void
    ) {
        let endpoint = ChaiEndpoint.createChaiOrder

        // ✅ match Postman exactly
        let params: Parameters = [
            "chaiDeviceId": KeychainHelper.shared.read(forKey: "chaiDeviceId"),
            "userId": userId
        ]

        client.request(
            endpoint,
            method: .post,
            parameters: params,
            headers: nil,
            completion: completion
        )
    }

    func updateChai(userId: String) async throws -> APIResponse<EmptyData> {
        try await withCheckedThrowingContinuation { cont in
            updateChai(userId: userId) { result in
                cont.resume(with: result)
            }
        }
    }
}
