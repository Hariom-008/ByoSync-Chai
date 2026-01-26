//
//  FetchUserByPhoneNumberResponse.swift
//  ByoSync-Chai
//
//  Created by Hari's Mac on 25.01.2026.
//

import Foundation

struct FetchUserByPhoneNumberResponse: Decodable {
    let statusCode: Int
    let data: FetchUserByPhoneNumberData
    let message: String
    let success: Bool
}

