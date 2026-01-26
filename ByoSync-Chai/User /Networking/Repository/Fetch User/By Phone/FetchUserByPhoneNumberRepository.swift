// FetchUserByPhoneNumberRepository.swift

import Foundation
import Alamofire


protocol FetchUserByPhoneNumberRepositoryProtocol {
    func fetchUserByPhoneNumber(
        phoneNumber: String,
        completion: @escaping (Result<FetchUserByPhoneNumberResponse, APIError>) -> Void
    )

    func fetchUserByPhoneNumber(phoneNumber: String) async throws -> FetchUserByPhoneNumberResponse
}

final class FetchUserByPhoneNumberRepository: FetchUserByPhoneNumberRepositoryProtocol {
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    func fetchUserByPhoneNumber(
        phoneNumber: String,
        completion: @escaping (Result<FetchUserByPhoneNumberResponse, APIError>) -> Void
    ) {
        let endpoint = UserAPIEndpoint.UserData.userByPhoneNumber

        let phoneNumberHash = HMACGenerator.generateHMAC(jsonString: phoneNumber)

        let params: Parameters = [
            "phoneNumberHash": phoneNumberHash
        ]

        client.request(
            endpoint,
            method: .post,        // change to .get/.put if your backend expects it
            parameters: params,
            headers: nil,
            completion: completion
        )
    }

    func fetchUserByPhoneNumber(phoneNumber: String) async throws -> FetchUserByPhoneNumberResponse {
        try await withCheckedThrowingContinuation { cont in
            fetchUserByPhoneNumber(phoneNumber: phoneNumber) { result in
                cont.resume(with: result)
            }
        }
    }
}
