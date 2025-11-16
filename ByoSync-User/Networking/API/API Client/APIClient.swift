import Alamofire
import Foundation

// MARK: - APIClient (Singleton)
final class APIClient {
    static let shared = APIClient()
    
    private let session: Session
    
    private init(){
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        
        self.session = Session(configuration: configuration)
    }
    
    // MARK: - Generic Request Method (For responses that return data)
    /// Use this for endpoints that return JSON responses
    func request<T: Decodable>(
        _ endpoint: String,
        method: HTTPMethod,
        parameters: Parameters? = nil,
        headers: HTTPHeaders? = nil,
        completion: @escaping (Result<T, APIError>) -> Void
    ) {
        let requestHeaders = headers ?? HTTPHeaders()

        session.request(
            endpoint,
            method: method,
            parameters: parameters,
            encoding: JSONEncoding.default,
            headers: requestHeaders
        )
        .validate(statusCode: 200..<300)
        .responseData { response in
            switch response.result {
            case .success(let data):
                do {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    
                    let decodedResponse = try decoder.decode(T.self, from: data)
                    completion(.success(decodedResponse))
                } catch {
                    print("❌ JSON DECODE ERROR:", error)
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("📦 RAW RESPONSE:\n\(jsonString)")
                    }
                    completion(.failure(.decodingError(error.localizedDescription)))
                }

            case .failure(let afError):
                let apiError = APIError.map(
                    from: response.response?.statusCode,
                    error: afError,
                    data: response.data
                )
                completion(.failure(apiError))
            }
        }
    }

    // MARK: - Request Without Response (For operations that return no data)
    /// Use this for endpoints that return 200 OK with no body
    func requestWithoutResponse(
        _ endpoint: String,
        method: HTTPMethod,
        parameters: Parameters? = nil,
        headers: HTTPHeaders? = nil,
        completion: @escaping (Result<Void, APIError>) -> Void
    ) {
        let requestHeaders = headers ?? HTTPHeaders()
        
        session.request(
            endpoint,
            method: method,
            parameters: parameters,
            encoding: JSONEncoding.default,
            headers: requestHeaders
        )
        .validate(statusCode: 200..<300)
        .response { response in
            if let error = response.error {
                let apiError = APIError.map(
                    from: response.response?.statusCode,
                    error: error,
                    data: response.data
                )
                completion(.failure(apiError))
            } else {
                completion(.success(()))
            }
        }
    }
    
    // MARK: - Custom Request with Raw Body (For HMAC signed requests)
    /// Use this when you need full control over the request body (like HMAC signing)
    /// This is what your RegisterUserRepository uses
    func requestWithCustomBody(
        _ urlRequest: URLRequest,
        completion: @escaping (Result<Void, APIError>) -> Void
    ) {
        session.request(urlRequest)
            .validate(statusCode: 200..<300)
            .response { response in
                print("📥 Response Status Code: \(response.response?.statusCode ?? -1)")
                
                if let data = response.data, let responseString = String(data: data, encoding: .utf8) {
                    print("📥 Response Body: \(responseString)")
                }
                
                if let error = response.error {
                    print("❌ Request Error: \(error)")
                    let apiError = APIError.map(
                        from: response.response?.statusCode,
                        error: error,
                        data: response.data
                    )
                    completion(.failure(apiError))
                } else if let statusCode = response.response?.statusCode, (200..<300).contains(statusCode) {
                    print("✅ Request successful")
                    completion(.success(()))
                } else {
                    completion(.failure(.unknown))
                }
            }
    }
    
    
// Request without validation so that if api's like change primary device don't have status code i can call them
    func requestWithoutValidation<T: Decodable>(
        _ endpoint: String,
        method: HTTPMethod,
        parameters: Parameters? = nil,
        headers: HTTPHeaders? = nil,
        skipValidation: Bool = false,                 
        completion: @escaping (Result<T, APIError>) -> Void
    ) {
        let requestHeaders = headers ?? HTTPHeaders()
        var req = session.request(
            endpoint,
            method: method,
            parameters: parameters,
            encoding: JSONEncoding.default,
            headers: requestHeaders
        )
       
        //print("I am Ark Jain")
        
        if !skipValidation {
            req = req.validate(statusCode: 200..<300)
        }

        req.responseData { response in
            switch response.result {
            case .success(let data):
                // let jsonString = String(data: data, encoding: .utf8)
            
                do {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    let decoded = try decoder.decode(T.self, from: data)
                    completion(.success(decoded))
                } catch {
                    print("❌ Decoding error: \(error)")
                    print("❌ Failed to decode type: \(T.self)")
                    completion(.failure(.decodingError(error.localizedDescription)))
                }

            case .failure(let afError):
                // 👇 Try to decode the body even on non-2xx if caller asked for it
                if skipValidation, let data = response.data {
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("📥 Raw Error Body: \(jsonString)")
                    }
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    if let decoded = try? decoder.decode(T.self, from: data) {
                        // Treat decodable message as a logical/business success
                        completion(.success(decoded))
                        return
                    }
                }
                let apiError = APIError.map(
                    from: response.response?.statusCode,
                    error: afError,
                    data: response.data
                )
                completion(.failure(apiError))
            }
        }
    }

    // MARK: - Download File
    func downloadFile(
        _ endpoint: String,
        method: HTTPMethod,
        headers: HTTPHeaders? = nil,
        completion: @escaping (Result<URL, APIError>) -> Void
    ) {
        let requestHeaders = headers ?? HTTPHeaders()
        
        let destination: DownloadRequest.Destination = { _, _ in
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = documentsURL.appendingPathComponent("transaction_report_\(Date().timeIntervalSince1970).pdf")
            return (fileURL, [.removePreviousFile, .createIntermediateDirectories])
        }
        
        session.download(
            endpoint,
            method: method,
            headers: requestHeaders,
            to: destination
        )
        .validate(statusCode: 200..<300)
        .response { response in
            if let error = response.error {
                let apiError = APIError.map(
                    from: response.response?.statusCode,
                    error: error,
                    data: nil
                )
                completion(.failure(apiError))
            } else if let fileURL = response.fileURL {
                completion(.success(fileURL))
            } else {
                completion(.failure(.unknown))
            }
        }
    }
    // MARK: - Custom Request with Raw Body AND Response Decoding
    /// Use this when you need full control over the request body (like HMAC signing) AND need to decode the response
    func requestWithCustomBodyAndResponse<T: Decodable>(
        _ urlRequest: URLRequest,
        completion: @escaping (Result<T, APIError>) -> Void
    ) {
        session.request(urlRequest)
            .responseData { response in
                let status = response.response?.statusCode ?? -1
                print("📥 [APIClient] Status Code:", status)

                if let data = response.data,
                   let raw = String(data: data, encoding: .utf8) {
                    print("📥 [APIClient] Raw Response:\n\(raw)")
                }

                switch response.result {
                case .success(let data):
                    do {
                        let decoder = JSONDecoder()
                        decoder.keyDecodingStrategy = .convertFromSnakeCase
                        let decoded = try decoder.decode(T.self, from: data)
                        print("✅ [APIClient] Successfully decoded \(T.self)")
                        completion(.success(decoded))
                    } catch {
                        print("❌ [APIClient] JSON decode error:", error)
                        completion(.failure(.decodingError(error.localizedDescription)))
                    }

                case .failure(let afError):
                    // ✅ Always print details
                    print("❌ [APIClient] Alamofire Error:", afError)
                    if let data = response.data,
                       let raw = String(data: data, encoding: .utf8) {
                        print("📦 [APIClient] Error Body:\n\(raw)")
                    }

                    // Optional: try to decode backend error message
                    if let data = response.data,
                       let backendError = try? JSONDecoder().decode(BackendError.self, from: data) {
                        print("⚠️ Backend Error:", backendError.message ?? "Unknown")
                    }

                    let apiError = APIError.map(
                        from: response.response?.statusCode,
                        error: afError,
                        data: response.data
                    )
                    completion(.failure(apiError))
                }
            }
    }

}

private struct BackendError: Codable {
    let message: String?
    let error: String?
}
