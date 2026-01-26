//
//  LoginRequest.swift
//  ByoSync-User
//
//  Created by Hari's Mac on 25.01.2026.
//

import Foundation

struct LoginRequest: Codable {
    let name: String
    let deviceKeyHash: String
    let fcmToken: String
    
    func asDictionary() -> [String: Any] {
        return [
            "name": name,
            "deviceKeyHash" : deviceKeyHash,
            "fcmToken" : fcmToken
        ]
    }
}
