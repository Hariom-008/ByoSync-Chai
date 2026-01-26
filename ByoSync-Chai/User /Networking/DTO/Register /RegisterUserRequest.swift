//
//  RegisterUserRequest.swift
//  ByoSync-User
//
//  Created by Hari's Mac on 25.01.2026.
//

import Foundation

struct RegisterUserRequest: Encodable {
    let firstName: String
    let lastName: String
    let email: String
    let emailHash: String
    let phoneNumber: String
    let phoneNumberHash: String
    let deviceKey: String
    let deviceKeyHash: String
    let deviceName: String
    let fcmToken: String
    let referralCode: String?
    let deviceData: String
}
