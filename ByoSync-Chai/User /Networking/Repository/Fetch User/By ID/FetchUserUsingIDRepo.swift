import Foundation
import Alamofire

protocol UserDataByIdRepositoryProtocol {
    func fetchUserDataById(
        userId: String,
        deviceKeyHash: String,
        completion: @escaping (Result<UserDataByIdResponse, APIError>) -> Void
    )
}
final class UserDataByIdRepository: UserDataByIdRepositoryProtocol {
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    func fetchUserDataById(
        userId: String,
        deviceKeyHash: String,
        completion: @escaping (Result<UserDataByIdResponse, APIError>) -> Void
    ) {
        let endpoint = UserAPIEndpoint.UserData.userDataById(
            userId: userId,
            deviceKeyHash: deviceKeyHash
        )

        client.request(
            endpoint,
            method: .get,
            parameters: nil,
            headers: nil,
            completion: completion
        )
    }
}
