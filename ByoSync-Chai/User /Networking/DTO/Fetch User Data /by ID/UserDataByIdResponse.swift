//
//  UserDataByIdResponse.swift
//  ByoSync-Chai
//
//  Created by Hari's Mac on 25.01.2026.
//

import Foundation
struct UserDataByIdResponse: Decodable {
    let statusCode: Int
    let data: UserDataByIdPayload
    let message: String
    let success: Bool
}
