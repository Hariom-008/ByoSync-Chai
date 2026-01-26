//
//  DeviceDetails.swift
//  ByoSync-User
//
//  Created by Hari's Mac on 25.01.2026.
//

import Foundation

struct DeviceDetails: Encodable {
    let manufacturer: String
    let model: String
    let brand: String
    let deviceName: String
    let sdkInt: Int
    let iosVersion: String
    let supportedAbis: [String]

    let cpuCoreCount: Int
    let cpuMaxFreqHz: Int?           // best-effort (may be null)

    let totalRamBytes: Int
    let totalStorageBytes: Int
    let freeStorageBytes: Int

    let frontCamera: FrontCameraDetails?
}
