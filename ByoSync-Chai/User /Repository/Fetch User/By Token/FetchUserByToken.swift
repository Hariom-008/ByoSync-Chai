// FetchUserByPhoneNumberRepository.swift

import Foundation
import Alamofire

// MARK: - Models (as you provided)

struct FetchUserByTokenResponse: Decodable {
    let statusCode: Int
    let data: FetchUserByTokenData
    let message: String
    let success: Bool
}

struct FetchUserByTokenData: Decodable {
    let userId: String
    let salt: String
    let deviceKeyHash: String?
    let faceData: [FaceId] // assumes FaceId: Decodable exists
}

// MARK: - Protocol

protocol FetchUserByTokenRepositoryProtocol {
    func fetchUserByToken(
            token: Int,
        completion: @escaping (Result<FetchUserByTokenResponse, APIError>) -> Void
    )

    func fetchUserByToken(token:Int) async throws -> FetchUserByTokenResponse
}

// MARK: - Repository

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
