import SwiftUI
import Combine

/// Central gate that decides whether MLScan must run.
final class AppScanGate: ObservableObject {
    static let shared = AppScanGate()

    @Published var requireScan: Bool

    // Persisted key – if true, we require a scan on next launch
    private let scanKey = "scanRequiredOnNextLaunch"

    init() {
        // Default to true on first ever launch to force a scan once
        if UserDefaults.standard.object(forKey: scanKey) == nil {
            UserDefaults.standard.set(true, forKey: scanKey)
        }
        self.requireScan = UserDefaults.standard.bool(forKey: scanKey)
    }

    /// Re-read from storage (useful on app start)
    func reloadFromStorage() {
        requireScan = UserDefaults.standard.bool(forKey: scanKey)
    }

    /// Call after a successful scan
    func markScanCompleted() {
        requireScan = false
        UserDefaults.standard.set(false, forKey: scanKey)
    }

    /// Call when app is going inactive (lock screen, phone call, etc.)
    func markRequiredDueToInactive() {
        requireScan = true
        UserDefaults.standard.set(true, forKey: scanKey)
    }

    /// Call when app is about to terminate
    func markRequiredOnTerminate() {
        requireScan = true
        UserDefaults.standard.set(true, forKey: scanKey)
    }
}
