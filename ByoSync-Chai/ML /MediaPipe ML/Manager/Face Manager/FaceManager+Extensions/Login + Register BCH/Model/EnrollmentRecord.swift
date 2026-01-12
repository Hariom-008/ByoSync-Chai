//
//  EnrollmentRecord.swift
//  ByoSync-User
//
//  Created by Hari's Mac on 01.01.2026.
//

import Foundation

struct EnrollmentRecord: Codable {
    let index: Int
    let helper: String          // codeword ⊕ biometricBits (as "0/1" string)
    let secretHash: String      // R = SHA256(secretKeyBitsString) hex
    let salt: String            // 256-bit hex, per enrollment (same across all Collected frames)
    let k2: String              // 256-bit hex, per frame
    let token: String           // SHA256(K || R) hex, per frame

    let timestamp: Date
}

struct EnrollmentStore: Codable {
    let savedAt: String
    let enrollments: [EnrollmentRecord]
}
