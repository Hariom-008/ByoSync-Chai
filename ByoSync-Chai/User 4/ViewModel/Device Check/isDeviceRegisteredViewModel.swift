import SwiftUI
import Foundation
import Combine

@MainActor
final class DeviceRegistrationViewModel: ObservableObject {

    // MARK: - Published State
    @Published var isLoading: Bool = false

    /// Full response from backend (only set on success).
    @Published var response: DeviceRegistrationResponse?

    /// Convenience flags
    @Published var isDeviceRegistered: Bool = false
    @Published var hasFaceData: Bool = false

    /// Error message to show in UI.
    @Published var errorMessage: String?

    // MARK: - Dependencies
    private let repository: DeviceRegistrationRepository

    init(repository: DeviceRegistrationRepository = .shared) {
        self.repository = repository
    }

    // MARK: - Public API
    func checkDeviceRegistration() {
        // reset state
        isLoading = true
        errorMessage = nil

        let userId = ""
        let deviceKey = DeviceIdentity.resolve()

        guard !deviceKey.isEmpty else {
            isLoading = false
            errorMessage = "Device identifier unavailable."
            Logger.shared.e("DEVICE_REG", "DeviceIdentity.resolve() returned empty deviceKey", user: userId)
            return
        }

        Logger.shared.d("DEVICE_REG", "Check start", user: userId)

        let startTime = CFAbsoluteTimeGetCurrent()

        repository.isDeviceRegistered(deviceKey: deviceKey) { [weak self] result in
            guard let self else { return }

            let elapsedMs = Int64((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0)

            Task { @MainActor in
                self.isLoading = false

                switch result {
                case .success(let resp):
                    #if DEBUG
                    print("✅ [DeviceRegistrationVM] Received response: \(resp)")
                    #endif

                    // Backend can return success=false even on HTTP 200
                    if resp.success {
                        self.response = resp
                        self.isDeviceRegistered = true
                        self.hasFaceData = resp.data.hasFaceData
                        self.errorMessage = nil

                        Logger.shared.i(
                            "DEVICE_REG",
                            "Check success | registered=true | hasFaceData=\(resp.data.hasFaceData) | msg=\(resp.message)",
                            timeTakenMs: elapsedMs,
                            user: userId
                        )
                    } else {
                        self.response = nil
                        self.isDeviceRegistered = false
                        self.hasFaceData = false
                        self.errorMessage = resp.message

                        #if DEBUG
                        print("❌ [DeviceRegistrationVM] Backend reported failure: \(resp.message)")
                        #endif

                        Logger.shared.e(
                            "DEVICE_REG",
                            "Backend failure | registered=false | msg=\(resp.message)",
                            timeTakenMs: elapsedMs,
                            user: userId
                        )
                    }

                case .failure(let error):
                    let msg = self.mapAPIErrorToMessage(error)

                    self.response = nil
                    self.isDeviceRegistered = false
                    self.hasFaceData = false
                    self.errorMessage = msg

                    #if DEBUG
                    print("❌ [DeviceRegistrationVM] API failure: \(msg)")
                    #endif

                    Logger.shared.e(
                        "DEVICE_REG",
                        "API failure | \(msg)",
                        error: error,
                        timeTakenMs: elapsedMs,
                        user: userId
                    )
                }
            }
        }
    }

    // MARK: - Error Mapping
    private func mapAPIErrorToMessage(_ error: APIError) -> String {
        if let localized = (error as? LocalizedError)?.errorDescription {
            return localized
        }
        return String(describing: error)
    }
}
