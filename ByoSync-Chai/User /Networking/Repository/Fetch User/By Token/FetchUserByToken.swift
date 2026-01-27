// FetchUserByPhoneNumberRepository.swift

import Foundation

protocol FetchUserByTokenRepositoryProtocol {
    func fetchUserByToken(
            token: Int,
        completion: @escaping (Result<FetchUserByTokenResponse, APIError>) -> Void
    )

    func fetchUserByToken(token:Int) async throws -> FetchUserByTokenResponse
}

final class FetchUserByTokenRepository: FetchUserByTokenRepositoryProtocol {
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    func fetchUserByToken(
        token: Int,
        completion: @escaping (Result<FetchUserByTokenResponse, APIError>) -> Void
    ) {
        let endpoint = ChaiEndpoints.fetchUserByToken


        let params: Parameters = [
            "token": token
        ]

        client.request(
            endpoint,
            method: .post,        // change to .get/.put if your backend expects it
            parameters: params,
            headers: nil,
            completion: completion
        )
    }

    func fetchUserByToken(token: Int) async throws -> FetchUserByTokenResponse {
        try await withCheckedThrowingContinuation { cont in
            fetchUserByToken(token: token) { result in
                cont.resume(with: result)
            }
        }
    }
}
