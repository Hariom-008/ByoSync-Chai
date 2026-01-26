//
//  FetchUserByTokenResponse.swift
//  ByoSync-Chai
//
//  Created by Hari's Mac on 25.01.2026.
//

import Foundation

struct FetchUserByTokenResponse: Decodable {
    let statusCode: Int
    let data: FetchUserByTokenData
    let message: String
    let success: Bool
}
