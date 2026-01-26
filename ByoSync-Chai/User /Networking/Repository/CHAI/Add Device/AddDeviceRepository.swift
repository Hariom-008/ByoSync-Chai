//
//  AddDeviceRepository.swift
//

import Foundation
import Alamofire

// MARK: - DTOs
struct AddDeviceRequestBody: Encodable {
    let deviceKey: String
    let deviceKeyHash: String
    let deviceName: String
    let deviceData: [String: AnyEncodable]   // allows {} / arbitrary json
}

struct AddDeviceData: Decodable {
    let _id: String
}
struct AddDeviceResponse: Decodable {
    let statusCode: Int?
    let message: String?
    let data: AddDeviceData
    let success: Bool?
}

// MARK: - Repo
protocol AddDeviceRepositoryProtocol {
    func addDevice(
        body: AddDeviceRequestBody,
        completion: @escaping (Result<AddDeviceResponse, APIError>) -> Void
    )
}

final class AddDeviceRepository: AddDeviceRepositoryProtocol {

    static let shared = AddDeviceRepository()
    private init() {}

    func addDevice(
        body: AddDeviceRequestBody,
        completion: @escaping (Result<AddDeviceResponse, APIError>) -> Void
    ) {
        APIClient.shared.request(
            ChaiEndpoints.addDevice,
            method: .post,
            parameters: body.toParameters(),
          //  headers: HTTPHeaders([.contentType("application/json")]),
            completion: completion
        )
    }
}

// MARK: - Encodable -> Alamofire Parameters

private extension Encodable {
    func toParameters() -> Parameters? {
        do {
            let data = try JSONEncoder().encode(self)
            let obj = try JSONSerialization.jsonObject(with: data, options: [])
            return obj as? Parameters
        } catch {
            #if DEBUG
            print("❌ Failed to encode request body:", error)
            #endif
            return nil
        }
    }
}

// MARK: - AnyEncodable (encode arbitrary JSON values)

struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void

    init<T: Encodable>(_ wrapped: T) {
        self._encode = wrapped.encode
    }

    func encode(to encoder: Encoder) throws { try _encode(encoder) }
}
