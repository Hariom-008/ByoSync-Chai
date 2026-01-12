import Alamofire
import Foundation

enum APIConfig {
    static let baseURL = URL(string: "https://backendapi.byosync.in")!
    static let host = "backendapi.byosync.in"
}

final class APIClient {
    static let shared = APIClient()

    private let session: Session

    private init() {
        let configuration = URLSessionConfiguration.af.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60

        configuration.httpCookieStorage = HTTPCookieStorage.shared
        configuration.httpShouldSetCookies = true
        configuration.httpCookieAcceptPolicy = .always

        let evaluators: [String: ServerTrustEvaluating] = [
            APIConfig.host: PinnedCertificatesTrustEvaluator(
                acceptSelfSignedCertificates: false,
                performDefaultValidation: true,
                validateHost: true
            )
        ]

        let serverTrustManager = ServerTrustManager(evaluators: evaluators)
        let interceptor = AuthCookieInterceptor(cookieName: "token", baseURL: APIConfig.baseURL)

        self.session = Session(
            configuration: configuration,
            interceptor: interceptor,
            serverTrustManager: serverTrustManager
        )
    }

    // MARK: - Generic Request Method (For responses that return data)
    func request<T: Decodable>(
        _ endpoint: String,
        method: HTTPMethod,
        parameters: Parameters? = nil,
        headers: HTTPHeaders? = nil,
        completion: @escaping (Result<T, APIError>) -> Void
    ) {
        let requestHeaders = headers ?? HTTPHeaders()
        let urlString = endpoint

        #if DEBUG
        let start = CFAbsoluteTimeGetCurrent()
        debugLogRequestStart(
            function: "request",
            method: method,
            url: urlString,
            headers: requestHeaders,
            parameters: parameters
        )
        #endif

        session.request(
            urlString,
            method: method,
            parameters: parameters,
            encoding: JSONEncoding.default,
            headers: requestHeaders
        )
        .validate(statusCode: 200..<300)
        .responseData { response in

            #if DEBUG
            let durationMs = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
            self.debugLogRequestEnd(
                function: "request",
                method: method,
                url: urlString,
                statusCode: response.response?.statusCode,
                durationMs: durationMs,
                data: response.data,
                afError: response.error
            )
            #endif

            switch response.result {
            case .success(let data):
                do {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    let decodedResponse = try decoder.decode(T.self, from: data)
                    completion(.success(decodedResponse))
                } catch {
                    #if DEBUG
                    print("APIClient request decodeError \(error)")
                    #endif
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

    // MARK: - Request Without Response
    func requestWithoutResponse(
        _ endpoint: String,
        method: HTTPMethod,
        parameters: Parameters? = nil,
        headers: HTTPHeaders? = nil,
        completion: @escaping (Result<Void, APIError>) -> Void
    ) {
        let requestHeaders = headers ?? HTTPHeaders()
        let urlString = endpoint

        #if DEBUG
        let start = CFAbsoluteTimeGetCurrent()
        debugLogRequestStart(
            function: "requestWithoutResponse",
            method: method,
            url: urlString,
            headers: requestHeaders,
            parameters: parameters
        )
        #endif

        session.request(
            urlString,
            method: method,
            parameters: parameters,
            encoding: JSONEncoding.default,
            headers: requestHeaders
        )
        .validate(statusCode: 200..<300)
        .response { response in

            #if DEBUG
            let durationMs = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
            self.debugLogRequestEnd(
                function: "requestWithoutResponse",
                method: method,
                url: urlString,
                statusCode: response.response?.statusCode,
                durationMs: durationMs,
                data: response.data,
                afError: response.error
            )
            #endif

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

    // MARK: - Custom Request with Raw Body
    func requestWithCustomBody(
        _ urlRequest: URLRequest,
        completion: @escaping (Result<Void, APIError>) -> Void
    ) {
        assert(urlRequest.url?.scheme == "https", "All requests must use HTTPS")

        #if DEBUG
        let start = CFAbsoluteTimeGetCurrent()
        let urlString = urlRequest.url?.absoluteString ?? "<nil-url>"
        let method = HTTPMethod(rawValue: urlRequest.httpMethod ?? "GET")
        let headers = HTTPHeaders(urlRequest.allHTTPHeaderFields ?? [:])

        debugLogCustomRequestStart(
            function: "requestWithCustomBody",
            method: method,
            url: urlString,
            headers: headers,
            rawBody: urlRequest.httpBody
        )
        #endif

        session.request(urlRequest)
            .validate(statusCode: 200..<300)
            .response { response in

                #if DEBUG
                let durationMs = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
                self.debugLogRequestEnd(
                    function: "requestWithCustomBody",
                    method: method,
                    url: urlString,
                    statusCode: response.response?.statusCode,
                    durationMs: durationMs,
                    data: response.data,
                    afError: response.error
                )
                #endif

                if let error = response.error {
                    let apiError = APIError.map(
                        from: response.response?.statusCode,
                        error: error,
                        data: response.data
                    )
                    completion(.failure(apiError))
                } else if let statusCode = response.response?.statusCode,
                          (200..<300).contains(statusCode) {
                    completion(.success(()))
                } else {
                    completion(.failure(.unknown))
                }
            }
    }

    // MARK: - Request Without Validation
    func requestWithoutValidation<T: Decodable>(
        _ endpoint: String,
        method: HTTPMethod,
        parameters: Parameters? = nil,
        headers: HTTPHeaders? = nil,
        skipValidation: Bool = false,
        completion: @escaping (Result<T, APIError>) -> Void
    ) {
        let requestHeaders = headers ?? HTTPHeaders()
        let urlString = endpoint

        #if DEBUG
        let start = CFAbsoluteTimeGetCurrent()
        debugLogRequestStart(
            function: "requestWithoutValidation",
            method: method,
            url: urlString,
            headers: requestHeaders,
            parameters: parameters
        )
        #endif

        var req = session.request(
            urlString,
            method: method,
            parameters: parameters,
            encoding: JSONEncoding.default,
            headers: requestHeaders
        )

        if !skipValidation {
            req = req.validate(statusCode: 200..<300)
        }

        req.responseData { response in

            #if DEBUG
            let durationMs = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
            self.debugLogRequestEnd(
                function: "requestWithoutValidation",
                method: method,
                url: urlString,
                statusCode: response.response?.statusCode,
                durationMs: durationMs,
                data: response.data,
                afError: response.error
            )
            #endif

            switch response.result {
            case .success(let data):
                do {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    let decoded = try decoder.decode(T.self, from: data)
                    completion(.success(decoded))
                } catch {
                    #if DEBUG
                    print("APIClient requestWithoutValidation decodeError \(error)")
                    #endif
                    completion(.failure(.decodingError(error.localizedDescription)))
                }

            case .failure(let afError):
                if skipValidation, let data = response.data {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    if let decoded = try? decoder.decode(T.self, from: data) {
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
        let urlString = endpoint

        #if DEBUG
        let start = CFAbsoluteTimeGetCurrent()
        debugLogRequestStart(
            function: "downloadFile",
            method: method,
            url: urlString,
            headers: requestHeaders,
            parameters: nil
        )
        #endif

        let destination: DownloadRequest.Destination = { _, _ in
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = documentsURL.appendingPathComponent("transaction_report_\(Date().timeIntervalSince1970).pdf")
            return (fileURL, [.removePreviousFile, .createIntermediateDirectories])
        }

        session.download(
            urlString,
            method: method,
            headers: requestHeaders,
            to: destination
        )
        .validate(statusCode: 200..<300)
        .response { response in

            #if DEBUG
            let durationMs = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
            self.debugLogRequestEnd(
                function: "downloadFile",
                method: method,
                url: urlString,
                statusCode: response.response?.statusCode,
                durationMs: durationMs,
                data: response.resumeData,
                afError: response.error
            )
            #endif

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
    func requestWithCustomBodyAndResponse<T: Decodable>(
        _ urlRequest: URLRequest,
        completion: @escaping (Result<T, APIError>) -> Void
    ) {
        assert(urlRequest.url?.scheme == "https", "All requests must use HTTPS")

        #if DEBUG
        let start = CFAbsoluteTimeGetCurrent()
        let urlString = urlRequest.url?.absoluteString ?? "<nil-url>"
        let method = HTTPMethod(rawValue: urlRequest.httpMethod ?? "GET")
        let headers = HTTPHeaders(urlRequest.allHTTPHeaderFields ?? [:])

        debugLogCustomRequestStart(
            function: "requestWithCustomBodyAndResponse",
            method: method,
            url: urlString,
            headers: headers,
            rawBody: urlRequest.httpBody
        )
        #endif

        session.request(urlRequest)
            .responseData { response in

                #if DEBUG
                let durationMs = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
                self.debugLogRequestEnd(
                    function: "requestWithCustomBodyAndResponse",
                    method: method,
                    url: urlString,
                    statusCode: response.response?.statusCode,
                    durationMs: durationMs,
                    data: response.data,
                    afError: response.error
                )
                #endif

                switch response.result {
                case .success(let data):
                    do {
                        let decoder = JSONDecoder()
                        decoder.keyDecodingStrategy = .convertFromSnakeCase
                        let decoded = try decoder.decode(T.self, from: data)
                        completion(.success(decoded))
                    } catch {
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

    #if DEBUG
    func debugPrintCookies() {
        let url = APIConfig.baseURL
        let cookies = HTTPCookieStorage.shared.cookies(for: url) ?? []
        print("APIClient cookies host=\(url.host ?? "?") count=\(cookies.count)")
        for c in cookies {
            print("APIClient cookie name=\(c.name) value=<redacted> domain=\(c.domain) path=\(c.path) secure=\(c.isSecure) expires=\(String(describing: c.expiresDate))")
        }
    }
    #endif
}

// MARK: - Backend Error Model
private struct BackendError: Codable {
    let message: String?
    let error: String?
}

// MARK: - Debug Helpers
#if DEBUG
private extension APIClient {

    func debugLogRequestStart(
        function: String,
        method: HTTPMethod,
        url: String,
        headers: HTTPHeaders,
        parameters: Parameters?
    ) {
        print("APIClient \(function) start")
        print("APIClient method \(method.rawValue)")
        print("APIClient url \(url)")
        debugPrintHeaders(headers)
        debugPrintParameters(parameters)
    }

    func debugLogCustomRequestStart(
        function: String,
        method: HTTPMethod,
        url: String,
        headers: HTTPHeaders,
        rawBody: Data?
    ) {
        print("APIClient \(function) start")
        print("APIClient method \(method.rawValue)")
        print("APIClient url \(url)")
        debugPrintHeaders(headers)

        if let rawBody = rawBody, !rawBody.isEmpty {
            if let raw = String(data: rawBody, encoding: .utf8) {
                print("APIClient rawBody \(raw.singleLine)")
            } else {
                print("APIClient rawBody nonUtf8Bytes=\(rawBody.count)")
            }
        } else {
            print("APIClient rawBody nil")
        }
    }

    func debugLogRequestEnd(
        function: String,
        method: HTTPMethod,
        url: String,
        statusCode: Int?,
        durationMs: Double,
        data: Data?,
        afError: AFError?
    ) {
        print("APIClient \(function) end")
        print("APIClient method \(method.rawValue)")
        print("APIClient url \(url)")
        print("APIClient status \(statusCode.map(String.init) ?? "nil")")

        if let data = data, !data.isEmpty {
            if let raw = String(data: data, encoding: .utf8) {
                print("APIClient rawResponse \(raw.singleLine)")
            } else {
                print("APIClient rawResponse nonUtf8Bytes=\(data.count)")
            }
        } else {
            print("APIClient rawResponse empty")
        }

        if let afError = afError {
            print("APIClient afError \(afError)")
        }
    }

    func debugPrintHeaders(_ headers: HTTPHeaders) {
        if headers.isEmpty {
            print("APIClient headers none")
            return
        }
        print("APIClient headers")
        for h in headers {
            let v = sanitizeHeaderValue(name: h.name, value: h.value)
            print("APIClient header \(h.name) \(v.singleLine)")
        }
    }

    func debugPrintParameters(_ parameters: Parameters?) {
        guard let parameters = parameters else {
            print("APIClient body nil")
            return
        }

        // Compact single-line JSON to avoid large spacing / multi-line logs
        if let compact = compactJSON(from: parameters) {
            print("APIClient body \(compact)")
        } else {
            print("APIClient body \(String(describing: parameters).singleLine)")
        }
    }

    func compactJSON(from obj: Any) -> String? {
        guard JSONSerialization.isValidJSONObject(obj) else { return nil }
        do {
            // no .prettyPrinted => no newlines
            let data = try JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys])
            return String(data: data, encoding: .utf8)?.singleLine
        } catch {
            return nil
        }
    }

    func sanitizeHeaderValue(name: String, value: String) -> String {
        let lower = name.lowercased()
        if lower.contains("authorization") || lower.contains("token") || lower.contains("cookie") {
            return "<redacted>"
        }
        return value
    }
}

// Keep logs tight: remove newlines/tabs + collapse multiple spaces
private extension String {
    var singleLine: String {
        self
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
    }
}
#endif
