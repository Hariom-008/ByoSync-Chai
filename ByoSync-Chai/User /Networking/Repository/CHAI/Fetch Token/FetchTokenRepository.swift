//
//  FetchTokenRepository.swift
//  ByoSync-Chai
//
//  Created by Hari's Mac on 14.01.2026.
//

import Foundation
import Alamofire

// MARK: - DTOs

struct FindUserTokenByPhoneNumberResponse: Decodable {
    let statusCode: Int
    let data: FindUserTokenByPhoneNumberData
    let message: String
    let success: Bool
}

struct FindUserTokenByPhoneNumberData: Decodable {
    let token: Int
}

// MARK: - Protocol

protocol FindUserTokenByPhoneNumberRepositoryProtocol {
    func findUserTokenByPhoneNumber(
        phoneNumber: String,
        completion: @escaping (Result<FindUserTokenByPhoneNumberResponse, APIError>) -> Void
    )

    func findUserTokenByPhoneNumber(phoneNumber: String) async throws -> FindUserTokenByPhoneNumberResponse
}

// MARK: - Repository

final class FindUserTokenByPhoneNumberRepository: FindUserTokenByPhoneNumberRepositoryProtocol {
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    func findUserTokenByPhoneNumber(
        phoneNumber: String,
        completion: @escaping (Result<FindUserTokenByPhoneNumberResponse, APIError>) -> Void
    ) {
        let endpoint = ChaiEndpoints.findUserTokenByPhoneNumber

        let phoneNumberHash = HMACGenerator.generateHMAC(jsonString: phoneNumber)
        let params: Parameters = [
            "phoneNumberHash": phoneNumberHash
        ]

        client.request(
            endpoint,
            method: .post,
            parameters: params,
            headers: nil,
            completion: completion
        )
    }

    func findUserTokenByPhoneNumber(phoneNumber: String) async throws -> FindUserTokenByPhoneNumberResponse {
        try await withCheckedThrowingContinuation { cont in
            findUserTokenByPhoneNumber(phoneNumber: phoneNumber) { result in
                cont.resume(with: result)
            }
        }
    }
}
