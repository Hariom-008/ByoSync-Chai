import Foundation
import Alamofire

protocol LogRepositoryProtocol {
    func sendLogs(_ logs: [BackendLogEntry], completion: @escaping (Result<LogCreateResponse, APIError>) -> Void)
}

final class LogRepository: LogRepositoryProtocol {

    func sendLogs(_ logs: [BackendLogEntry], completion: @escaping (Result<LogCreateResponse, APIError>) -> Void) {
        guard !logs.isEmpty else {
            completion(.failure(.custom("No logs to send")))
            return
        }

        let headers: HTTPHeaders = ["Content-Type": "application/json"]

        let parameters: Parameters = [
            "logsArray": logs.map { [
                "type": $0.type,
                "form": $0.form,
                "message": $0.message,
                "timeTaken": $0.timeTaken, // duration ms string (Android semantics)
                "user": $0.user
            ]}
        ]

        AF.request(
            LogEndpoint.createLogs,
            method: .post,
            parameters: parameters,
            encoding: JSONEncoding.default,
            headers: headers
        )
        .validate()
        .responseData { response in
            switch response.result {
            case .success(let data):
                do {
                    let decoded = try JSONDecoder().decode(LogCreateResponse.self, from: data)
                    completion(.success(decoded))
                } catch {
                    completion(.failure(.custom("Failed to decode response")))
                }
            case .failure(let error):
                let apiError: APIError
                if let statusCode = response.response?.statusCode {
                    apiError = .serverError(statusCode, "Status Code")
                } else {
                    apiError = .custom(error.localizedDescription)
                }
                completion(.failure(apiError))
            }
        }
    }
}
