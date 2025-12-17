// ChaiRepository.swift

import Foundation
import Alamofire

// MARK: - Repository Protocol

protocol ChaiRepositoryProtocol {
    func updateChai(userId: String, completion: @escaping (Result<APIResponse<EmptyData>, APIError>) -> Void)
    func updateChai(userId: String) async throws -> APIResponse<EmptyData>
}

// MARK: - Repository Implementation

final class ChaiRepository: ChaiRepositoryProtocol {
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    /// Callback style
    func updateChai(
        userId: String,
        completion: @escaping (Result<APIResponse<EmptyData>, APIError>) -> Void
    ) {
        let endpoint = ChaiEndpoint.updateChai

        // Backend spec says: { "userID": String }
        let params: Parameters = [
            "userID": userId
        ]

        // NOTE: Pick the HTTP method your backend expects (.post/.put/.patch).
        client.request(
            endpoint,
            method: .post,
            parameters: params,
            headers: nil,
            completion: completion
        )
    }

    /// async/await style
    func updateChai(userId: String) async throws -> APIResponse<EmptyData> {
        try await withCheckedThrowingContinuation { cont in
            updateChai(userId: userId) { result in
                cont.resume(with: result)
            }
        }
    }
}
