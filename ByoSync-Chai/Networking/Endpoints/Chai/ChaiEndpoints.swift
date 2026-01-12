import Foundation

struct ChaiEndpoints{
    static let baseURL = "https://backendapi.byosync.in"
    
   static let addDevice = "\(baseURL)/api/v1/chai/add-device"
   static let scanReport = "\(baseURL)/api/v1/chai/scan-report"
   static let createChaiOrder = "\(baseURL)/api/v1/orders/create"
    
    static let registerFromChaiApp = "\(baseURL)/api/v1/chai/user-register-from-phone"
}
