import Foundation
import Alamofire

final class AuthCookieInterceptor: RequestInterceptor {

    private let cookieName: String
    private let baseURL: URL

    init(cookieName: String = "token", baseURL: URL = APIConfig.baseURL) {
        self.cookieName = cookieName
        self.baseURL = baseURL
    }

    func adapt(
        _ urlRequest: URLRequest,
        for session: Session,
        completion: @escaping (Result<URLRequest, Error>) -> Void
    ) {
        var req = urlRequest

        // Only attach for our API host
        if let host = req.url?.host, host == baseURL.host {
            if let token = Self.readCookie(named: cookieName, for: baseURL) {
                // Don’t overwrite if caller already set Authorization
                if req.value(forHTTPHeaderField: "Authorization") == nil {
                    req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                }
            }
        }

        completion(.success(req))
    }

    private static func readCookie(named name: String, for url: URL) -> String? {
        let cookies = HTTPCookieStorage.shared.cookies(for: url) ?? []
        return cookies.first(where: { $0.name == name })?.value
    }
}
