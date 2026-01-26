//
//  UserDataByIdPayload.swift
//  ByoSync-Chai
//
//  Created by Hari's Mac on 25.01.2026.
//

import Foundation


struct UserDataByIdPayload: Decodable {
    let user: UserByIdDTO
    let device: DeviceByIdDTO
}
