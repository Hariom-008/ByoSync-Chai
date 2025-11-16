//
//  UserData.swift
//  ByoSync
//
//  Created by Hari's Mac on 22.10.2025.
//

import Foundation

// MARK: - User Model
struct User: Codable,Equatable{
    let firstName: String
    let lastName: String
    let email: String
    let phoneNumber: String?
    let deviceKey: String?
    let deviceName: String?
    let fcmToken: String?
    let refferalCode: String?
    let userId: String?
    let userDeviceId: String?
    
    
    // Convenience initializer
    init(firstName: String, lastName: String, email: String, phoneNumber: String? = nil, deviceKey: String? = nil, deviceName: String? = nil,fcmToken:String? = nil, refferalCode: String? = nil, userId:String? = nil,userDeviceId:String? = nil) {
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.phoneNumber = phoneNumber
        self.deviceKey = deviceKey
        self.deviceName = deviceName
        self.fcmToken = fcmToken
        self.refferalCode = refferalCode
        self.userId = userId
        self.userDeviceId = userDeviceId
    }
}
struct Address: Codable {
    var address1: String
    var address2: String
    var city: String
    var state: String
    var pincode: String
}


// MARK: - User Data
struct UserData: Codable,Identifiable {
    let id: String
    let email: String
    let firstName: String
    let lastName: String
    let phoneNumber: String
    let pattern: [String]
    let salt: String
    let faceToken: String
    let wallet: Double
    let referralCode: String
    let transactionCoins: Int
    let noOfTransactions: Int
    let noOfTransactionsReceived: Int
    let profilePic: String
    let devices: [String]
    let emailVerified: Bool
    let faceId: [String]
    let createdAt: String
    let updatedAt: String
    let v: Int
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case email
        case firstName
        case lastName
        case phoneNumber
        case pattern
        case salt
        case faceToken
        case wallet
        case referralCode
        case transactionCoins
        case noOfTransactions
        case noOfTransactionsReceived
        case profilePic
        case devices
        case emailVerified
        case faceId
        case createdAt
        case updatedAt
        case v = "__v"
    }
    
    var initials: String {
           let firstInitial = firstName.first?.uppercased() ?? ""
           let lastInitial = lastName.first?.uppercased() ?? ""
           return "\(firstInitial)\(lastInitial)"
       }
}
