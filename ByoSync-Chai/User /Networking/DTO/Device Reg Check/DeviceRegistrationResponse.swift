//
//  DeviceRegistrationResponse.swift
//  ByoSync-Chai
//
//  Created by Hari's Mac on 25.01.2026.
//

import Foundation


struct DeviceRegistrationResponse: Codable {
    let statusCode: Int
    let data: DeviceRegistrationData
    let message: String
    let success: Bool
}
