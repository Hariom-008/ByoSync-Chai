//
//  RegisterUserDeviceData.swift
//  ByoSync-User
//
//  Created by Hari's Mac on 25.01.2026.
//

import Foundation

struct RegisterUserDeviceData: Codable, Identifiable {
    let id: String
    let deviceKey: String
    let deviceKeyHash: String?
    let deviceName: String
    let user: String
    let isPrimary: Bool
    let fcmToken: String
    let deviceData: String?
    let createdAt: String
    let updatedAt: String
    let v: Int
    let token: String

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case deviceKey
        case deviceKeyHash
        case deviceName
        case user
        case isPrimary
        case fcmToken
        case deviceData
        case createdAt
        case updatedAt
        case v = "__v"
        case token
    }
}
