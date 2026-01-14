//
//  LoginUserRepository.swift
//  ByoSync
//

import Foundation
import Alamofire
import SwiftUI

final class LoginUserRepository {

    // MARK: - Properties
    private let cryptoService: any CryptoService
    private let hmacGenerator = HMACGenerator.self

    // MARK: - Initialization
    init(cryptoService: any CryptoService) {
        self.cryptoService = cryptoService
    }

    // MARK: - Helpers
    private func toJSONString<T: Encodable>(_ value: T) -> String? {
        do {
            let data = try JSONEncoder().encode(value)
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    // MARK: - Login Method (Generic)
    func login<T: Codable>(
        name: String,
        deviceKey: String,
        fcmToken: String,
        completion: @escaping (Result<APIResponse<T>, APIError>) -> Void
    ) {
        // Generate HMAC
        let deviceKeyHash = hmacGenerator.generateHMAC(jsonString: deviceKey)

        let loginData = LoginRequest(
            name: name,
            deviceKeyHash: deviceKeyHash,
            fcmToken: fcmToken
        )

        let endpoint = UserAPIEndpoint.Auth.logIn
        let endpointString = String(describing: endpoint)

        // Track API call performance (ms)
        let startTime = CFAbsoluteTimeGetCurrent()

        // Optional: lightweight trace
        Logger.shared.d("AUTH_LOGIN", "Login request start", user: name)

        APIClient.shared.request(
            endpoint,
            method: .post,
            parameters: loginData.asDictionary(),
            headers: ["Content-Type": "application/json"]
        ) { (result: Result<APIResponse<T>, APIError>) in

            let elapsedMs = Int64((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0)

            switch result {
            case .success(let response):
                #if DEBUG
                print("✅ User is Logged In Successfully")
                #endif

                // Log the API call with request + response bodies (truncated inside logger) :contentReference[oaicite:1]{index=1}
                Logger.shared.api(
                    url: endpointString,
                    requestBody: self.toJSONString(loginData),
                    responseBody: self.toJSONString(response),
                    timeTakenMs: elapsedMs,
                    user: name
                )

                // Explicit success marker
                Logger.shared.i(
                    "AUTH_LOGIN",
                    "Login success | message=\(response.message)",
                    timeTakenMs: elapsedMs,
                    user: name
                )

                completion(.success(response))

            case .failure(let error):
                // Log API call (we may not have a structured response body here)
                Logger.shared.api(
                    url: endpointString,
                    requestBody: self.toJSONString(loginData),
                    responseBody: "error=\(error.localizedDescription)",
                    timeTakenMs: elapsedMs,
                    user: name
                )

                // Error marker (priority upload) :contentReference[oaicite:2]{index=2}
                Logger.shared.e(
                    "AUTH_LOGIN",
                    "Login failed",
                    error: error,
                    timeTakenMs: elapsedMs,
                    user: name
                )

                completion(.failure(error))
            }
        }
    }

    // MARK: - Convenience Method for User Login
    func loginUser(
        name: String,
        deviceKey: String,
        fcmToken: String,
        completion: @escaping (Result<APIResponse<LoginData>, APIError>) -> Void
    ) {
        login(name: name, deviceKey: deviceKey, fcmToken: fcmToken, completion: completion)
    }

    // MARK: - Deinitialization
    deinit {
        #if DEBUG
        print("🍀 Login Repo deallocated")
        #endif
    }
}
