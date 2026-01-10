import Foundation
import Alamofire

// MARK: - Endpoint
// Assumption: you already have AdminEndpoint.login defined as a full absolute URL String,
// e.g. "\(APIConfig.baseURL.absoluteString)/admin/login"

// MARK: - Request
struct AdminLoginRequestBody: Codable {
    let email: String
    let password: String
}

// MARK: - Response
struct AdminLoginResponse: Codable {
    let statusCode: Int
    let data: AdminUser?
    let message: String
    let success: Bool
}

struct AdminUser: Codable {
    let id: String
    let email: String
    let password: String?     // returned by backend, but you should NOT use/store it
    let createdAt: String?
    let updatedAt: String?
    let v: Int?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case email, password, createdAt, updatedAt
        case v = "__v"
    }
}

// MARK: - Repository
final class AdminLoginRepository {
    static let shared = AdminLoginRepository()
    private init() {}

    func login(
        email: String,
        password: String,
        completion: @escaping (Result<AdminLoginResponse, APIError>) -> Void
    ) {
        let body = AdminLoginRequestBody(email: email, password: password)

        APIClient.shared.request(
            AdminEndpoints.login,
            method: .post,
            parameters: body.toParameters(),
            headers: HTTPHeaders([
                .contentType("application/json")
            ]),
            completion: completion
        )
    }

    // Optional: async/await convenience wrapper
    func login(email: String, password: String) async throws -> AdminLoginResponse {
        try await withCheckedThrowingContinuation { cont in
            login(email: email, password: password) { result in
                cont.resume(with: result)
            }
        }
    }
}

// MARK: - Codable -> Alamofire Parameters helper
private extension Encodable {
    func toParameters() -> Parameters? {
        do {
            let data = try JSONEncoder().encode(self)
            let obj = try JSONSerialization.jsonObject(with: data, options: [])
            return obj as? Parameters
        } catch {
            print("❌ Failed to encode request body:", error)
            return nil
        }
    }
}
