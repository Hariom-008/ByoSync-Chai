import Foundation
import Alamofire

// MARK: - DTOs (registerFromChaiApp)

// Request body:
// {
//   "firstName": "...",
//   "lastName": "...",
//   "email": "...",
//   "emailHash": "...",
//   "phoneNumber": "...",
//   "phoneNumberHash": "...",
//   "deviceId": "..."
// }
struct RegisterFromChaiAppRequest: Encodable {
    let firstName: String
    let lastName: String
    let email: String
    let emailHash: String
    let phoneNumber: String
    let phoneNumberHash: String
    let deviceId: String
}

struct RegisterFromChaiAppResponse: Decodable {
    let statusCode: Int
    let data: RegisterFromChaiAppData
    let message: String
    let success: Bool
}

struct RegisterFromChaiAppData: Decodable {
    let newUser: RegisterFromChaiAppUser
}

/// Full-ish user payload as per your sample.
/// Anything you don’t need right now can stay optional to avoid decode breaks.
struct RegisterFromChaiAppUser: Decodable, Identifiable,Equatable {
    let id: String

    let email: String
    let emailHash: String
    let firstName: String
    let lastName: String
    let phoneNumber: String
    let phoneNumberHash: String

    let salt: String
    let faceToken: String?
    let token: Int

    let wallet: Double?
    let todayChaiCount: Int?
    let todayChaiDate: String?     // backend sends null; keep String? unless you want Date parsing
    let chai: Int?

    let referralCode: String?
    let transactionCoins: Int?
    let noOfTransactions: Int?
    let noOfTransactionsReceived: Int?

    let profilePic: String?
    let devices: [String]?

    let emailVerified: Bool?
    let isDeleted: Bool?
    let deletedAt: String?

    let faceDistance: [Double]?    // sample shows []
    let faceId: [FaceId]?          // sample shows [], assumes FaceId: Decodable exists

    let createdAt: String?
    let updatedAt: String?
    let v: Int?

    enum CodingKeys: String, CodingKey {
        case id = "_id"

        case email, emailHash, firstName, lastName, phoneNumber, phoneNumberHash
        case salt, faceToken, token
        case wallet, todayChaiCount, todayChaiDate, chai
        case referralCode, transactionCoins, noOfTransactions, noOfTransactionsReceived
        case profilePic, devices, emailVerified, isDeleted, deletedAt
        case faceDistance, faceId
        case createdAt, updatedAt
        case v = "__v"
    }
}

// MARK: - Protocol

protocol RegisterFromChaiAppRepositoryProtocol {
    func registerFromChaiApp(
        req: RegisterFromChaiAppRequest,
        completion: @escaping (Result<RegisterFromChaiAppResponse, APIError>) -> Void
    )

    func registerFromChaiApp(req: RegisterFromChaiAppRequest) async throws -> RegisterFromChaiAppResponse
}

// MARK: - Repository

final class RegisterFromChaiAppRepository: RegisterFromChaiAppRepositoryProtocol {
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    func registerFromChaiApp(
        req: RegisterFromChaiAppRequest,
        completion: @escaping (Result<RegisterFromChaiAppResponse, APIError>) -> Void
    ) {
        let endpoint = ChaiEndpoints.registerFromChaiApp

        // APIClient in your project style typically accepts Alamofire Parameters.
        // If your APIClient supports Encodable directly, you can swap this for that.
        let params: Parameters = [
            "firstName": req.firstName,
            "lastName": req.lastName,
            "email": req.email,
            "emailHash": req.emailHash,
            "phoneNumber": req.phoneNumber,
            "phoneNumberHash": req.phoneNumberHash,
            "deviceId": req.deviceId
        ]

        client.request(
            endpoint,
            method: .post,
            parameters: params,
            headers: nil,
            completion: completion
        )
    }

    func registerFromChaiApp(req: RegisterFromChaiAppRequest) async throws -> RegisterFromChaiAppResponse {
        try await withCheckedThrowingContinuation { cont in
            registerFromChaiApp(req: req) { result in
                cont.resume(with: result)
            }
        }
    }
}
