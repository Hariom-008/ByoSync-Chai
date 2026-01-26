//
//  OTPData.swift
//  ByoSync-User
//
//  Created by Hari's Mac on 25.01.2026.
//

import Foundation

struct OTPData: Codable {
    let otp: String?  // Added otp field as per new response structure
    let phoneNumber: String?
    let otpSentAt: String?
    let expiresIn: Int?
}
