import Foundation

enum APIConfig {
    static let baseURL = URL(string: "https://backendapi.byosync.in")!
    static let host = "backendapi.byosync.in"
}

final class APIClient: NSObject {
    static let shared = APIClient()
    
    private var session: URLSession!
    private var pinnedCertificates: [SecCertificate] = []
    private let cookieName: String
    
    private override init() {
        self.cookieName = "token"
        super.init()
        
        // Load certificates from bundle
        loadPinnedCertificates()
        
        // Configure URLSession
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        
        // Cookie configuration
        configuration.httpCookieStorage = HTTPCookieStorage.shared
        configuration.httpShouldSetCookies = true
        configuration.httpCookieAcceptPolicy = .always
        
        // Create session with self as delegate for certificate pinning
        self.session = URLSession(
            configuration: configuration,
            delegate: self,
            delegateQueue: nil
        )
    }
    
    // MARK: - Load Certificates
    private func loadPinnedCertificates() {
         let cerPaths = Bundle.main.paths(forResourcesOfType: "cer", inDirectory: nil)
        if cerPaths.isEmpty{
            print("⚠️ No .cer files found in bundle")
            return
        }
        
        for cerPath in cerPaths {
            guard let cerData = try? Data(contentsOf: URL(fileURLWithPath: cerPath)),
                  let certificate = SecCertificateCreateWithData(nil, cerData as CFData) else {
                print("⚠️ Failed to load certificate at: \(cerPath)")
                continue
            }
            
            pinnedCertificates.append(certificate)
        }
    }
    
    // MARK: - Auth Token Injection (Interceptor Replacement)
    private func injectAuthToken(into request: inout URLRequest) {
        // Only attach for our API host
        guard let host = request.url?.host, host == APIConfig.host else { return }
        
        // Don't overwrite if caller already set Authorization
        guard request.value(forHTTPHeaderField: "Authorization") == nil else { return }
        
        // Read token from cookie
        if let token = readCookie(named: cookieName, for: APIConfig.baseURL) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }
    
    private func readCookie(named name: String, for url: URL) -> String? {
        let cookies = HTTPCookieStorage.shared.cookies(for: url) ?? []
        return cookies.first(where: { $0.name == name })?.value
    }
    
    // MARK: - Generic Request Method (For responses that return data)
    func request<T: Decodable>(
        _ endpoint: String,
        method: HTTPMethod,
        parameters: Parameters? = nil,
        headers: HTTPHeaders? = nil,
        completion: @escaping (Result<T, APIError>) -> Void
    ) {
        guard let url = URL(string: endpoint) else {
            print("❌ Invalid URL: \(endpoint)")
            completion(.failure(.custom("Invalid URL")))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.timeoutInterval = 30
        
        let requestHeaders = headers ?? HTTPHeaders()
        for header in requestHeaders {
            request.setValue(header.value, forHTTPHeaderField: header.name)
        }
        
        if let parameters = parameters {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            } catch {
                print("❌ JSON Encoding Error:", error.localizedDescription)
                completion(.failure(.custom("Failed to encode request parameters")))
                return
            }
        }
        
        injectAuthToken(into: &request)
        
        #if DEBUG
        let start = CFAbsoluteTimeGetCurrent()
        debugLogRequestStart(
            function: "request",
            method: method,
            url: endpoint,
            headers: requestHeaders,
            parameters: parameters
        )
        #endif
        
        let task = session.dataTask(with: request) { data, response, error in
            let httpResponse = response as? HTTPURLResponse
            let statusCode = httpResponse?.statusCode
            
            #if DEBUG
            let durationMs = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
            self.debugLogRequestEnd(
                function: "request",
                method: method,
                url: endpoint,
                statusCode: statusCode,
                durationMs: durationMs,
                data: data,
                error: error
            )
            #endif
            
            if let error = error {
                print("❌ Network Error:", error.localizedDescription)
                let apiError = APIError.map(from: statusCode, error: error, data: data)
                completion(.failure(apiError))
                return
            }
            
            guard let httpResponse = httpResponse else {
                print("❌ Invalid Response")
                completion(.failure(.custom("Invalid response from server")))
                return
            }
            
            guard let data = data else {
                print("❌ No Data")
                completion(.failure(.custom("No data received from server")))
                return
            }
            
            guard (200..<300).contains(httpResponse.statusCode) else {
                let apiError = APIError.map(from: httpResponse.statusCode, error: nil, data: data)
                completion(.failure(apiError))
                return
            }
            
            // ✅ FIX: Decode on background queue to prevent UI freeze
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    print("🔄 [APIClient] Starting JSON decode on background thread")
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    let decodedResponse = try decoder.decode(T.self, from: data)
                    print("✅ [APIClient] Decode completed successfully")
                    
                    // Return result on main queue
                    DispatchQueue.main.async {
                        completion(.success(decodedResponse))
                    }
                    
                } catch {
                    print("❌ [APIClient] Decode error: \(error)")
                    DispatchQueue.main.async {
                        completion(.failure(.decodingError(error.localizedDescription)))
                    }
                }
            }
        }
        
        task.resume()
    }
    
    // MARK: - Request Without Response
    func requestWithoutResponse(
        _ endpoint: String,
        method: HTTPMethod,
        parameters: Parameters? = nil,
        headers: HTTPHeaders? = nil,
        completion: @escaping (Result<Void, APIError>) -> Void
    ) {
        guard let url = URL(string: endpoint) else {
            print("❌ Invalid URL: \(endpoint)")
            completion(.failure(.custom("Invalid URL")))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.timeoutInterval = 30
        
        // Add headers
        let requestHeaders = headers ?? HTTPHeaders()
        for header in requestHeaders {
            request.setValue(header.value, forHTTPHeaderField: header.name)
        }
        
        // Add JSON body if parameters exist
        if let parameters = parameters {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            } catch {
                print("❌ JSON Encoding Error:", error.localizedDescription)
                completion(.failure(.custom("Failed to encode request parameters")))
                return
            }
        }
        
        // Inject auth token
        injectAuthToken(into: &request)
        
        #if DEBUG
        let start = CFAbsoluteTimeGetCurrent()
        debugLogRequestStart(
            function: "requestWithoutResponse",
            method: method,
            url: endpoint,
            headers: requestHeaders,
            parameters: parameters
        )
        #endif
        
        let task = session.dataTask(with: request) { data, response, error in
            let httpResponse = response as? HTTPURLResponse
            let statusCode = httpResponse?.statusCode
            
            #if DEBUG
            let durationMs = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
            self.debugLogRequestEnd(
                function: "requestWithoutResponse",
                method: method,
                url: endpoint,
                statusCode: statusCode,
                durationMs: durationMs,
                data: data,
                error: error
            )
            #endif
            
            if let error = error {
                print("❌ Network Error:", error.localizedDescription)
                let apiError = APIError.map(from: statusCode, error: error, data: data)
                completion(.failure(apiError))
                return
            }
            
            guard let httpResponse = httpResponse else {
                print("❌ Invalid Response")
                completion(.failure(.custom("Invalid response from server")))
                return
            }
            
            guard (200..<300).contains(httpResponse.statusCode) else {
                let apiError = APIError.map(from: httpResponse.statusCode, error: nil, data: data)
                completion(.failure(apiError))
                return
            }
            
            completion(.success(()))
        }
        
        task.resume()
    }
    
    // MARK: - Custom Request with Raw Body
    func requestWithCustomBody(
        _ urlRequest: URLRequest,
        completion: @escaping (Result<Void, APIError>) -> Void
    ) {
        assert(urlRequest.url?.scheme == "https", "All requests must use HTTPS")
        
        var request = urlRequest
        
        // Inject auth token
        injectAuthToken(into: &request)
        
        #if DEBUG
        let start = CFAbsoluteTimeGetCurrent()
        let urlString = request.url?.absoluteString ?? "<nil-url>"
        let method = HTTPMethod(rawValue: request.httpMethod ?? "GET")
        let headers = HTTPHeaders(request.allHTTPHeaderFields ?? [:])
        
        debugLogCustomRequestStart(
            function: "requestWithCustomBody",
            method: method ?? .get,
            url: urlString,
            headers: headers,
            rawBody: request.httpBody
        )
        #endif
        
        let task = session.dataTask(with: request) { data, response, error in
            let httpResponse = response as? HTTPURLResponse
            let statusCode = httpResponse?.statusCode
            
            #if DEBUG
            let durationMs = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
            self.debugLogRequestEnd(
                function: "requestWithCustomBody",
                method: method ?? .get,
                url: urlString,
                statusCode: statusCode,
                durationMs: durationMs,
                data: data,
                error: error
            )
            #endif
            
            if let error = error {
                print("❌ Request Error: \(error)")
                let apiError = APIError.map(from: statusCode, error: error, data: data)
                completion(.failure(apiError))
                return
            }
            
            guard let httpResponse = httpResponse else {
                print("❌ Invalid response")
                completion(.failure(.custom("Invalid response from server")))
                return
            }
            
            if (200..<300).contains(httpResponse.statusCode) {
                completion(.success(()))
            } else {
                let apiError = APIError.map(from: httpResponse.statusCode, error: nil, data: data)
                completion(.failure(apiError))
            }
        }
        
        task.resume()
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
        guard let url = URL(string: endpoint) else {
            print("❌ Invalid URL: \(endpoint)")
            completion(.failure(.custom("Invalid URL")))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.timeoutInterval = 30
        
        // Add headers
        let requestHeaders = headers ?? HTTPHeaders()
        for header in requestHeaders {
            request.setValue(header.value, forHTTPHeaderField: header.name)
        }
        
        // Add JSON body if parameters exist
        if let parameters = parameters {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            } catch {
                print("❌ JSON Encoding Error:", error.localizedDescription)
                completion(.failure(.custom("Failed to encode request parameters")))
                return
            }
        }
        
        // Inject auth token
        injectAuthToken(into: &request)
        
        #if DEBUG
        let start = CFAbsoluteTimeGetCurrent()
        debugLogRequestStart(
            function: "requestWithoutValidation",
            method: method,
            url: endpoint,
            headers: requestHeaders,
            parameters: parameters
        )
        #endif
        
        let task = session.dataTask(with: request) { data, response, error in
            let httpResponse = response as? HTTPURLResponse
            let statusCode = httpResponse?.statusCode ?? -1
            
            #if DEBUG
            let durationMs = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
            self.debugLogRequestEnd(
                function: "requestWithoutValidation",
                method: method,
                url: endpoint,
                statusCode: statusCode != -1 ? statusCode : nil,
                durationMs: durationMs,
                data: data,
                error: error
            )
            #endif
            
            guard let data = data else {
                if let error = error {
                    print("❌ Network Error:", error.localizedDescription)
                    let apiError = APIError.map(from: nil, error: error, data: nil)
                    completion(.failure(apiError))
                } else {
                    print("❌ No Data")
                    completion(.failure(.custom("No data received from server")))
                }
                return
            }
            
            // Try to decode regardless of status code if skipValidation is true
            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let decoded = try decoder.decode(T.self, from: data)
                
                // If skipValidation, return success even on error status codes
                if skipValidation || (200..<300).contains(statusCode) {
                    completion(.success(decoded))
                } else {
                    let apiError = APIError.map(from: statusCode, error: nil, data: data)
                    completion(.failure(apiError))
                }
            } catch {
                #if DEBUG
                print("APIClient requestWithoutValidation decodeError \(error)")
                #endif
                completion(.failure(.decodingError(error.localizedDescription)))
            }
        }
        
        task.resume()
    }
    
    // MARK: - Download File
    func downloadFile(
        _ endpoint: String,
        method: HTTPMethod,
        headers: HTTPHeaders? = nil,
        completion: @escaping (Result<URL, APIError>) -> Void
    ) {
        guard let url = URL(string: endpoint) else {
            print("❌ Invalid URL: \(endpoint)")
            completion(.failure(.custom("Invalid URL")))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.timeoutInterval = 60
        
        // Add headers
        let requestHeaders = headers ?? HTTPHeaders()
        for header in requestHeaders {
            request.setValue(header.value, forHTTPHeaderField: header.name)
        }
        
        // Inject auth token
        injectAuthToken(into: &request)
        
        #if DEBUG
        let start = CFAbsoluteTimeGetCurrent()
        debugLogRequestStart(
            function: "downloadFile",
            method: method,
            url: endpoint,
            headers: requestHeaders,
            parameters: nil
        )
        #endif
        
        let task = session.downloadTask(with: request) { tempURL, response, error in
            let httpResponse = response as? HTTPURLResponse
            let statusCode = httpResponse?.statusCode
            
            #if DEBUG
            let durationMs = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
            self.debugLogRequestEnd(
                function: "downloadFile",
                method: method,
                url: endpoint,
                statusCode: statusCode,
                durationMs: durationMs,
                data: nil,
                error: error
            )
            #endif
            
            if let error = error {
                print("❌ Download Error:", error.localizedDescription)
                let apiError = APIError.map(from: statusCode, error: error, data: nil)
                completion(.failure(apiError))
                return
            }
            
            guard let httpResponse = httpResponse else {
                print("❌ Invalid Response")
                completion(.failure(.custom("Invalid response from server")))
                return
            }
            
            guard (200..<300).contains(httpResponse.statusCode) else {
                let apiError = APIError.map(from: httpResponse.statusCode, error: nil, data: nil)
                completion(.failure(apiError))
                return
            }
            
            guard let tempURL = tempURL else {
                print("❌ No File URL")
                completion(.failure(.custom("No data received from server")))
                return
            }
            
            // Move to permanent location
            let documentsURL = FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask)[0]
            let destinationURL = documentsURL.appendingPathComponent(
                "transaction_report_\(Date().timeIntervalSince1970).pdf"
            )
            
            do {
                // Remove existing file if present
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                
                // Move temp file to destination
                try FileManager.default.moveItem(at: tempURL, to: destinationURL)
                completion(.success(destinationURL))
            } catch {
                print("❌ File move error:", error.localizedDescription)
                completion(.failure(.custom("Failed to save downloaded file")))
            }
        }
        
        task.resume()
    }
    
    // MARK: - Custom Request with Raw Body AND Response Decoding
    func requestWithCustomBodyAndResponse<T: Decodable>(
        _ urlRequest: URLRequest,
        completion: @escaping (Result<T, APIError>) -> Void
    ) {
        assert(urlRequest.url?.scheme == "https", "All requests must use HTTPS")
        
        var request = urlRequest
        
        // Inject auth token
        injectAuthToken(into: &request)
        
        #if DEBUG
        let start = CFAbsoluteTimeGetCurrent()
        let urlString = request.url?.absoluteString ?? "<nil-url>"
        let method = HTTPMethod(rawValue: request.httpMethod ?? "GET")
        let headers = HTTPHeaders(request.allHTTPHeaderFields ?? [:])
        
        debugLogCustomRequestStart(
            function: "requestWithCustomBodyAndResponse",
            method: method ?? .get,
            url: urlString,
            headers: headers,
            rawBody: request.httpBody
        )
        #endif
        
        let task = session.dataTask(with: request) { data, response, error in
            let httpResponse = response as? HTTPURLResponse
            let statusCode = httpResponse?.statusCode
            
            #if DEBUG
            let durationMs = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
            self.debugLogRequestEnd(
                function: "requestWithCustomBodyAndResponse",
                method: method ?? .get,
                url: urlString,
                statusCode: statusCode,
                durationMs: durationMs,
                data: data,
                error: error
            )
            #endif
            
            if let error = error {
                print("❌ Network Error:", error.localizedDescription)
                let apiError = APIError.map(from: statusCode, error: error, data: data)
                completion(.failure(apiError))
                return
            }
            
            guard let data = data else {
                print("❌ No Data")
                completion(.failure(.custom("No data received from server")))
                return
            }
            
            // Try to decode
            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let decoded = try decoder.decode(T.self, from: data)
                completion(.success(decoded))
            } catch {
                completion(.failure(.decodingError(error.localizedDescription)))
            }
        }
        
        task.resume()
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

// MARK: - URLSessionDelegate for Certificate Pinning
extension APIClient: URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Only handle server trust challenges
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        // Only pin our specific host
        guard challenge.protectionSpace.host == APIConfig.host else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            print("❌ No server trust found")
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        // Validate server trust
        var secResult = SecTrustResultType.invalid
        let status = SecTrustEvaluate(serverTrust, &secResult)
        
        guard status == errSecSuccess else {
            print("❌ Server trust evaluation failed")
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        // Get server certificate chain
        let certificateCount = SecTrustGetCertificateCount(serverTrust)
        var serverCertificates: [SecCertificate] = []
        
        for i in 0..<certificateCount {
            if let certificate = SecTrustGetCertificateAtIndex(serverTrust, i) {
                serverCertificates.append(certificate)
            }
        }
        
        // Check if any server certificate matches our pinned certificates
        var isPinned = false
        for serverCert in serverCertificates {
            let serverCertData = SecCertificateCopyData(serverCert) as Data
            
            for pinnedCert in pinnedCertificates {
                let pinnedCertData = SecCertificateCopyData(pinnedCert) as Data
                
                if serverCertData == pinnedCertData {
                    isPinned = true
                    break
                }
            }
            
            if isPinned { break }
        }
        
        if isPinned {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            print("❌ Certificate pinning failed - no matching certificate")
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}

// MARK: - Supporting Types
typealias Parameters = [String: Any]

struct HTTPHeaders: ExpressibleByDictionaryLiteral {
    private var headers: [HTTPHeader]
    
    init(_ headers: [HTTPHeader] = []) {
        self.headers = headers
    }
    
    init(_ dictionary: [String: String]) {
        self.headers = dictionary.map { HTTPHeader(name: $0.key, value: $0.value) }
    }
    
    // ExpressibleByDictionaryLiteral conformance
    init(dictionaryLiteral elements: (String, String)...) {
        self.headers = elements.map { HTTPHeader(name: $0.0, value: $0.1) }
    }
    
    // Computed property for compatibility
    var dictionary: [String: String] {
        var dict: [String: String] = [:]
        for header in headers {
            dict[header.name] = header.value
        }
        return dict
    }
    
    var isEmpty: Bool {
        headers.isEmpty
    }
    
    subscript(name: String) -> String? {
        get {
            headers.first(where: { $0.name.lowercased() == name.lowercased() })?.value
        }
        set {
            if let newValue = newValue {
                update(name: name, value: newValue)
            } else {
                remove(name: name)
            }
        }
    }
    
    mutating func add(name: String, value: String) {
        headers.append(HTTPHeader(name: name, value: value))
    }
    
    mutating func add(_ header: HTTPHeader) {
        headers.append(header)
    }
    
    mutating func update(name: String, value: String) {
        if let index = headers.firstIndex(where: { $0.name.lowercased() == name.lowercased() }) {
            headers[index] = HTTPHeader(name: name, value: value)
        } else {
            add(name: name, value: value)
        }
    }
    
    mutating func remove(name: String) {
        headers.removeAll(where: { $0.name.lowercased() == name.lowercased() })
    }
}

extension HTTPHeaders: Sequence {
    func makeIterator() -> IndexingIterator<[HTTPHeader]> {
        return headers.makeIterator()
    }
}

struct HTTPHeader {
    let name: String
    let value: String
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
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
        error: Error?
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
        
        if let error = error {
            print("APIClient error \(error)")
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
