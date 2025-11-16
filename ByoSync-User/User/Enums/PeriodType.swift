import Foundation
import SwiftUI

// MARK: - Period Type
enum PeriodType: String, CaseIterable {
    case daily = "daily"
    case monthly = "monthly"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .daily:
            return "Daily"
        case .monthly:
            return "Monthly"
        case .custom:
            return "Custom"
        }
    }
    
    var iconName: String {
        switch self {
        case .daily:
            return "calendar"
        case .monthly:
            return "calendar.badge.clock"
        case .custom:
            return "calendar.badge.plus"
        }
    }
}
