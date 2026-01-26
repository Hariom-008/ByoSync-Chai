//
//  AdminDeleteFaceIdRepository.swift
//  ByoSync-User (or your target)
//

import Foundation
import Alamofire

// MARK: - DTOs (keep at top)

// Request body
struct AdminDeleteFaceIdRequest: Encodable {
    let phoneNumberHash: String
}

// Response wrapper
struct AdminDeleteFaceIdResponse: Decodable {
    let statusCode: Int
    let data: EmptyDataDTO?
    let message: String?
    let success: Bool
}

// Empty `data: {}`
struct EmptyDataDTO: Decodable {}

// MARK: - Repository

protocol AdminDeleteFaceIdRepositoryProtocol {
    func deleteFaceId(
        phoneNumberHash: String,
        completion: @escaping (Result<AdminDeleteFaceIdResponse, APIError>) -> Void
    )
}

final class AdminDeleteFaceIdRepository: AdminDeleteFaceIdRepositoryProtocol {

    private let api: APIClient

    init(api: APIClient = .shared) {
        self.api = api
    }

    func deleteFaceId(
        phoneNumberHash: String,
        completion: @escaping (Result<AdminDeleteFaceIdResponse, APIError>) -> Void
    ) {
        let endpoint = AdminEndpoints.Delete.deleteFaceID

        let params: Parameters = [
            "phoneNumberHash": phoneNumberHash
        ]

        // ✅ No Authorization/Cookie headers here.
        // Cookies will be attached automatically.
        // If Bearer is required, interceptor injects it from cookie.
        api.request(
            endpoint,
            method: .post,
            parameters: params,
            headers: nil,
            completion: completion
        )
    }
}

