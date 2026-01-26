//
//  FetchUserByTokenData.swift
//  ByoSync-Chai
//
//  Created by Hari's Mac on 25.01.2026.
//

import Foundation

struct FetchUserByTokenData: Decodable {
    let userId: String
    let salt: String
    let deviceKeyHash: String?
    let faceData: [FaceId] // assumes FaceId: Decodable exists
}
