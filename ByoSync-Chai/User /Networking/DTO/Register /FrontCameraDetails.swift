//
//  FrontCameraDetails.swift
//  ByoSync-User
//
//  Created by Hari's Mac on 25.01.2026.
//

import Foundation

struct FrontCameraDetails: Encodable {
    let cameraId: String
    let focalLengthMm: Float?
    let sensorWidthMm: Float?
    let sensorHeightMm: Float?

    let pixelArrayWidth: Int?
    let pixelArrayHeight: Int?

    let horizontalFovDegrees: Double?
    let verticalFovDegrees: Double?
}
