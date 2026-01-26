//
//  VerifyOTPResponse.swift
//  ByoSync-User
//
//  Created by Hari's Mac on 25.01.2026.
//

import Foundation

struct VerifyOTPResponse: Codable {
    let success: Bool
    let message: String
    let statusCode: Int?
    let data: VerifyOTPData?
}
