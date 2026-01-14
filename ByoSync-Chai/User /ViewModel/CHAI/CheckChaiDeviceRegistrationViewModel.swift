import SwiftUI
import Foundation
import Combine

@MainActor
final class CheckChaiDeviceRegistrationViewModel: ObservableObject {

    // MARK: - Published State
    @Published var isLoading: Bool = false

    /// Full response from backend (only set on success).
    @Published var response: ChaiDeviceRegistrationResponse?

    /// Convenience flags
    @Published var isDeviceRegistered: Bool = false
    @Published var hasFaceData: Bool = false

    /// Error message to show in UI.
    @Published var errorMessage: String?

    // MARK: - Dependencies
    private let repository: ChaiDeviceRegisterCheckRepo

    init(repository: ChaiDeviceRegisterCheckRepo = .shared) {
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
            Logger.shared.e("Chai Device Registration", "DeviceIdentity.resolve() returned empty deviceKey", user: userId)
            return
        }

        Logger.shared.d("Chai Device Registration", "Check start", user: userId)

        let startTime = CFAbsoluteTimeGetCurrent()

        repository.isDeviceRegistered(deviceKey: deviceKey) { [weak self] result in
            guard let self else { return }

            let elapsedMs = Int64((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0)

            Task { @MainActor in
                self.isLoading = false

                switch result {
                case .success(let resp):
                    #if DEBUG
                    print("✅ [ChaiDeviceRegistrationVM] Received response: \(resp)")
                    #endif

                    // Backend can return success=false even on HTTP 200
                    if resp.success {
                        self.response = resp
                        self.isDeviceRegistered = resp.success
                        self.errorMessage = nil

                        Logger.shared.i(
                            "Chai Device Registration",
                            "Check success | registered=true | isRegistered:\(resp.success) | msg=\(resp.message)",
                            timeTakenMs: elapsedMs
                        )
                    } else {
                        self.response = nil
                        self.isDeviceRegistered = false
                        self.errorMessage = resp.message

                        #if DEBUG
                        print("❌ [ChaiDeviceRegistrationVM] Backend reported failure: \(resp.message)")
                        #endif

                        Logger.shared.e(
                            "Chai Device Registration",
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
                        "Chai Device Registration",
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
