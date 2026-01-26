//
//  GetFaceIdDataDTO.swift
//  ByoSync-User
//
//  Created by Hari's Mac on 25.01.2026.
//

import Foundation

struct GetFaceIdData: Codable,Equatable {
    let salt: String
    let faceData: [FaceId]
}
