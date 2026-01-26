//
//  GetFaceIdResponseDTO.swift
//  ByoSync-User
//
//  Created by Hari's Mac on 25.01.2026.
//

import Foundation

struct GetFaceIdResponse: Codable {
    let statusCode: Int
    let data: GetFaceIdData
    let message: String
    let success: Bool
}
