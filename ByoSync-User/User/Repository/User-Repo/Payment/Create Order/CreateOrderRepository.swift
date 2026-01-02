import Foundation
import Alamofire
import Combine

// MARK: - Request Model
struct CreateOrderRequest: Encodable {
    let receiverId: String
    let senderDeviceId: String
    let coins: Int
    let senderId: String
}

// MARK: - Response Model
struct CreateOrderResponse: Decodable {
    let success: Bool
    let data: OrderData
    let message: String?
}

struct OrderData: Codable, Identifiable {
    let id: String
    let type: OrderType
    let receiverId: String
    let coins: Int
    let status: OrderStatus
    let senderId: String
    let senderDeviceId: String
    let createdAt: String
    let updatedAt: String
    let v: Int

    enum CodingKeys: String, CodingKey {
        case type
        case receiverId
        case coins
        case status
        case senderId
        case senderDeviceId
        case createdAt
        case updatedAt
        case id = "_id"
        case v = "__v"
    }
}
enum OrderType: String, Codable {
    case transfer = "TRANSFER"
}
enum OrderStatus: String, Codable {
    case success = "SUCCESS"
    case pending = "PENDING"
    case failed = "FAILED"
}

// MARK: - Repository
final class CreateOrderRepository {
    
    // ✅ Inject crypto service for consistency
    private let cryptoService: any CryptoService
    
    // ✅ Dependency injection via initializer
    init(cryptoService: any CryptoService) {
        self.cryptoService = cryptoService
        #if DEBUG
        print("🔐 [REPO] CreateOrderRepository initialized with crypto service")
        #endif
    }
    
    // MARK: - Create Order
    func createOrder(
        receiverId: String,
        senderDeviceId: String,
        amount: Int,
        senderId: String,
        completion: @escaping (Result<CreateOrderResponse, APIError>) -> Void
    ) {
        #if DEBUG
        print("🔵 [CreateOrderRepo] Creating order...")
        print("📤 Receiver ID: \(receiverId)")
        print("📤 Sender Device ID: \(senderDeviceId)")
        print("📤 Amount (coins): \(amount)")
        print("📤 Sender ID: \(senderId)")
        #endif
        
        let requestBody = CreateOrderRequest(
            receiverId: receiverId,
            senderDeviceId: senderDeviceId,
            coins: amount,
            senderId: senderId
        )
        
        let parameters: [String: Any] = [
            "receiverId": receiverId,
            "senderDeviceId": senderDeviceId,
            "coins": amount,
            "senderId": senderId
        ]
        
        let headers = getHeader.shared.getAuthHeaders()
        
        #if DEBUG
        print("📦 [CreateOrderRepo] Request Body: \(parameters)")
        #endif
        
        APIClient.shared.request(
            CommonEndpoint.CreateOrder,
            method: .post,
            parameters: parameters,
            headers: headers
        ) { (result: Result<CreateOrderResponse, APIError>) in
            switch result {
            case .success(let response):
                
                #if DEBUG
                print("✅ [CreateOrderRepo] Order created successfully")
                print("✅ Order ID: \(response.data.id)")
                print("✅ Message: \(response.message ?? "N/A")")
                #endif
                
                completion(.success(response))
                
            case .failure(let error):
                #if DEBUG
                print("❌ [CreateOrderRepo] Failed to create order: \(error)")
                #endif
                completion(.failure(error))
            }
        }
    }
}


// MARK: - Create Order ViewModel
final class CreateOrderViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var orderId: String = ""
    
    @Published var senderDeviceId = UserSession.shared.currentUser?.userDeviceId
    @Published var senderId = UserSession.shared.currentUser?.userId
    
    // MARK: - Dependencies
    private let repository: CreateOrderRepository
    private let cryptoService: any CryptoService
    
    // MARK: - Initialization
    // ✅ Inject crypto service via initializer
    init(cryptoService: any CryptoService) {
        self.cryptoService = cryptoService
        self.repository = CreateOrderRepository(cryptoService: cryptoService)
        #if DEBUG
        print("🟢 [CreateOrderVM] Initialized with crypto service")
        #endif
    }
  
    // MARK: - Create Order
    func createOrder(
        receiverId: String,
        amount: Int
    ) {
        #if DEBUG
        print("🔵 [CreateOrderVM] Creating order...")
        print("📤 Amount: \(amount)")
        #endif
        
        // Reset previous states
        errorMessage = nil
        successMessage = nil
        orderId = ""
        isLoading = true
        
        repository.createOrder(
            receiverId: receiverId,
            senderDeviceId: senderDeviceId ?? "",
            amount: amount,
            senderId: senderId ?? ""
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let response):
                    print("✅ [CreateOrderVM] Order created successfully")
                    self?.orderId = response.data.id
                    self?.successMessage = response.message ?? "Order created successfully"
                    
                case .failure(let error):
                    print("❌ [CreateOrderVM] Failed to create order")
                    self?.handleError(error)
                }
            }
        }
    }
    
    // MARK: - Error Handling
    private func handleError(_ error: APIError) {
        switch error {
        case .unauthorized:
            errorMessage = "Authentication failed. Please log in again."
        case .serverError:
            errorMessage = "Server error. Please try again later."
        case .networkError:
            errorMessage = "Network error. Please check your connection."
        case .decodingError(let message):
            errorMessage = "Data error: \(message)"
        default:
            errorMessage = error.localizedDescription
        }
        #if DEBUG
        print("❌ [CreateOrderVM] Handling error: \(error)")
        print("📱 Error message displayed: \(errorMessage ?? "None")")
        #endif
    }
    
    // MARK: - Reset State
    func resetState() {
        print("🔄 [CreateOrderVM] Resetting state")
        errorMessage = nil
        successMessage = nil
        orderId = ""
        isLoading = false
    }
}
