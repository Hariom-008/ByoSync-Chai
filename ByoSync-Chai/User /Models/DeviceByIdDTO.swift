//
//  DeviceByIdDTO.swift
//  ByoSync-Chai
//
//  Created by Hari's Mac on 25.01.2026.
//

import Foundation

struct DeviceByIdDTO: Decodable, Identifiable {
    let id: String
    let deviceKey: String
    let deviceName: String
    let user: String
    let isPrimary: Bool
    let createdAt: String
    let updatedAt: String
    let v: Int

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case deviceKey, deviceName, user, isPrimary, createdAt, updatedAt
        case v = "__v"
    }
}
