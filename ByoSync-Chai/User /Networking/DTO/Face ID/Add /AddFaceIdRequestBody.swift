//
//  AddFaceIdRequest.swift
//  ByoSync-User
//
//  Created by Hari's Mac on 25.01.2026.
//

import Foundation

struct AddFaceIdRequestBody: Codable {
    let helper: String
    let k2: String
    let token: String
    let iod : String
}
