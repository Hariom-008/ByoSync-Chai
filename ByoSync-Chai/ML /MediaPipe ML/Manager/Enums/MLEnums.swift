//
//  MLEnums.swift
//  ByoSync-User
//
//  Created by Hari's Mac on 31.12.2025.
//

import Foundation
import SwiftUI

enum RegistrationPhase: Equatable {
    case centerCollecting                 // collect 60 frames (IOD + stable pose)
    case movementCollecting(endAt: Date)  // collect frames for 15s using direction thresholds
    case done
}

enum HeadDirection: CaseIterable {
    case left, right, up, down, center
}


