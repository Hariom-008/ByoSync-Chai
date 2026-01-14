import Foundation

struct ChaiEndpoints{
    static let baseURL = "https://backendapi.byosync.in"
    
   static let addDevice = "\(baseURL)/api/v1/chai/add-device"
   static let scanReport = "\(baseURL)/api/v1/chai/scan-report"
   static let createChaiOrder = "\(baseURL)/api/v1/orders/create"
    
    static let registerFromChaiApp = "\(baseURL)/api/v1/chai/user-register-from-phone"
    
    static let isChaiDeviceRegister = "\(baseURL)/api/v1/chai/is-device-register"
    
    static let findUserTokenByPhoneNumber = "\(baseURL)/api/v1/users/find-user-token-by-phone-number"
    static let fetchUserByToken = "\(baseURL)/api/v1/users/find-user-by-token"
    
    
}
