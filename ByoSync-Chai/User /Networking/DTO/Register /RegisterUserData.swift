//
//  RegisterUserData.swift
//  ByoSync-User
//
//  Created by Hari's Mac on 25.01.2026.
//

import Foundation

struct RegisterUserData: Codable {
    let newUser: UserData
    let newDevice: RegisterUserDeviceData
}

