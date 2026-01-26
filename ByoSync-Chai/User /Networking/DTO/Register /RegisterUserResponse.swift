//
//  RegisterUserResponse.swift
//  ByoSync-User
//
//  Created by Hari's Mac on 25.01.2026.
//

import Foundation

struct RegisterUserResponse: Codable {
    let statusCode: Int?
    let success: Bool
    let message: String
    let data: RegisterUserData?
}
