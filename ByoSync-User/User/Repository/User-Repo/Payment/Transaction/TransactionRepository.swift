import Foundation
import Alamofire

struct TransactionAPIResponse: Codable {
    let statusCode: Int
    let message: String
    let data: [Transaction]
}

struct Transaction: Codable, Identifiable, Equatable {
    let id: String
    let type: String
    let receiverId: TxUser?
    let senderId: TxUser?
    let senderDeviceId: String?
    let coins: Int?
    let status: String
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case type
        case receiverId
        case senderId
        case senderDeviceId
        case coins
        case status
        case createdAt
        case updatedAt
    }
}

struct MerchantInfo: Codable, Equatable {
    let id: String
    let merchantName: String
    let merchantProfilePic: String
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case merchantName
        case merchantProfilePic = "profilePic"
    }
}

struct TxUser: Codable, Equatable {
    let id: String
    let firstName: String
    let lastName: String
    let userProfilePic: String
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case firstName
        case lastName
        case userProfilePic = "profilePic"
    }
}

// MARK: - Protocol for Testability
protocol TransactionRepositoryProtocol {
    func fetchDailyReport(
        date: String,
        type: String,
        completion: @escaping (Result<[Transaction], APIError>) -> Void
    )
    
    func fetchCustomReport(
        startDate: String,
        endDate: String,
        type: String,
        completion: @escaping (Result<[Transaction], APIError>) -> Void
    )
    
    func fetchMonthlyReport(
        month: String,
        year: String,
        type: String,
        completion: @escaping (Result<[Transaction], APIError>) -> Void
    )
    
    func downloadDailyReport(
        date: String,
        completion: @escaping (Result<URL, APIError>) -> Void
    )
    
    func emailDailyReport(
        date: String,
        completion: @escaping (Result<String, APIError>) -> Void
    )
}

final class TransactionRepository: TransactionRepositoryProtocol {
    
    // MARK: - Initialization (No Singleton)
    init() {
        print("🏗️ [REPO] TransactionRepository initialized")
    }
    
    // MARK: - Private Helper: Get Auth Headers
    private func getAuthHeaders() -> HTTPHeaders {
        return getHeader.shared.getAuthHeaders()
    }
    
    // MARK: - Daily Report
    func fetchDailyReport(
        date: String,
        type: String,
        completion: @escaping (Result<[Transaction], APIError>) -> Void
    ) {
        let endpoint = UserAPIEndpoint.TransactionAPI.dailyReport(date: date, type: type)
        let headers = getAuthHeaders()
        
        print("📤 [REPO] Fetching Daily Report")
        print("📅 [REPO] Date: \(date), Type: \(type)")
        print("📍 [REPO] Endpoint: \(endpoint)")
        
        APIClient.shared.request(
            endpoint,
            method: .get,
            headers: headers
        ) { (result: Result<TransactionAPIResponse, APIError>) in
            switch result {
            case .success(let response):
                print("✅ [REPO] Daily report fetched successfully")
                print("📊 [REPO] Status Code: \(response.statusCode)")
                print("💬 [REPO] Message: \(response.message)")
                print("📈 [REPO] Data Count: \(response.data.count)")
                
                if (200...299).contains(response.statusCode) {
                    completion(.success(response.data))
                } else {
                    print("❌ [REPO] Invalid status code: \(response.statusCode)")
                    completion(.failure(.custom(response.message)))
                }
                
            case .failure(let error):
                print("❌ [REPO] Failed to fetch daily report: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Custom Date Range Report
    func fetchCustomReport(
        startDate: String,
        endDate: String,
        type: String,
        completion: @escaping (Result<[Transaction], APIError>) -> Void
    ) {
        let endpoint = UserAPIEndpoint.TransactionAPI.customReport(startDate: startDate, endDate: endDate, type: type)
        let headers = getAuthHeaders()
        
        print("📤 [REPO] Fetching Custom Report")
        print("📅 [REPO] Period: \(startDate) → \(endDate), Type: \(type)")
        print("📍 [REPO] Endpoint: \(endpoint)")
        
        APIClient.shared.request(
            endpoint,
            method: .get,
            headers: headers
        ) { (result: Result<TransactionAPIResponse, APIError>) in
            switch result {
            case .success(let response):
                print("✅ [REPO] Custom report fetched successfully")
                print("📊 [REPO] Status Code: \(response.statusCode)")
                print("📈 [REPO] Data Count: \(response.data.count)")
                
                if (200...299).contains(response.statusCode) {
                    completion(.success(response.data))
                } else {
                    print("❌ [REPO] Invalid status code: \(response.statusCode)")
                    completion(.failure(.custom(response.message)))
                }
                
            case .failure(let error):
                print("❌ [REPO] Failed to fetch custom report: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Monthly Report
    func fetchMonthlyReport(
        month: String,
        year: String,
        type: String,
        completion: @escaping (Result<[Transaction], APIError>) -> Void
    ) {
        let endpoint = UserAPIEndpoint.TransactionAPI.monthlyReport(month: month, year: year, type: type)
        let headers = getAuthHeaders()
        
        print("📤 [REPO] Fetching Monthly Report")
        print("📅 [REPO] Month: \(month), Year: \(year), Type: \(type)")
        print("📍 [REPO] Endpoint: \(endpoint)")
        
        APIClient.shared.request(
            endpoint,
            method: .get,
            headers: headers
        ) { (result: Result<APIResponse<[Transaction]>, APIError>) in
            switch result {
            case .success(let response):
                if response.success ?? false, let transactions = response.data {
                    print("✅ [REPO] Monthly report fetched successfully")
                    print("📈 [REPO] Data Count: \(transactions.count)")
                    completion(.success(transactions))
                } else {
                    print("❌ [REPO] Failed: \(response.message)")
                    completion(.failure(.custom(response.message)))
                }
                
            case .failure(let error):
                print("❌ [REPO] Failed to fetch monthly report: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }

    // MARK: - Download Daily Report
    func downloadDailyReport(
        date: String,
        completion: @escaping (Result<URL, APIError>) -> Void
    ) {
        let endpoint = UserAPIEndpoint.TransactionAPI.dailyReport(date: date, type: "DOWNLOAD")
        let headers = getAuthHeaders()
        
        print("📤 [REPO] Downloading Daily Report")
        print("📅 [REPO] Date: \(date)")
        print("📍 [REPO] Endpoint: \(endpoint)")
        
        APIClient.shared.downloadFile(
            endpoint,
            method: .get,
            headers: headers
        ) { result in
            switch result {
            case .success(let fileURL):
                print("✅ [REPO] Report downloaded successfully")
                print("📂 [REPO] File path: \(fileURL.path)")
                completion(.success(fileURL))
                
            case .failure(let error):
                print("❌ [REPO] Download failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }

    // MARK: - Email Daily Report
    func emailDailyReport(
        date: String,
        completion: @escaping (Result<String, APIError>) -> Void
    ) {
        let endpoint = UserAPIEndpoint.TransactionAPI.dailyReport(date: date, type: "EMAIL")
        let headers = getAuthHeaders()
        
        print("📤 [REPO] Sending Daily Report via Email")
        print("📅 [REPO] Date: \(date)")
        print("📍 [REPO] Endpoint: \(endpoint)")
        
        APIClient.shared.request(
            endpoint,
            method: .get,
            headers: headers
        ) { (result: Result<APIResponse<EmptyData>, APIError>) in
            switch result {
            case .success(let response):
                if (200...299).contains(response.statusCode) {
                    print("✅ [REPO] Email sent successfully")
                    print("💬 [REPO] Message: \(response.message)")
                    completion(.success(response.message))
                } else {
                    print("❌ [REPO] Email failed: \(response.message)")
                    completion(.failure(.custom(response.message)))
                }
                
            case .failure(let error):
                print("❌ [REPO] Failed to send email: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    deinit {
        print("♻️ [REPO] TransactionRepository deallocated")
    }
}
