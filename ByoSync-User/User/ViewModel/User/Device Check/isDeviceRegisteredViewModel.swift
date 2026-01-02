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
    /// - If backend returns success = false → this is backend `message`
    /// - If API fails (network / decoding / etc.) → mapped error string
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
        let deviceKey = DeviceIdentity.resolve()
        if deviceKey.isEmpty {
            print("❌ Device Key is empty")
            self.isLoading = false
            self.errorMessage = "Device identifier unavailable."
            return
        }
        repository.isDeviceRegistered(deviceKey: deviceKey) { [weak self] result in

            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                switch result {
                case .success(let resp):
                    print("✅ [DeviceRegistrationVM] Received response: \(resp)")
                    
                    // Even on HTTP 200, backend can signal failure via `success` flag.
                    if resp.success {
                        self.response = resp
                        self.isDeviceRegistered = true
                        self.hasFaceData = resp.data.hasFaceData
                        self.errorMessage = nil
                    } else {
                        // Backend-level failure: use backend-provided message.
                        self.response = nil
                        self.isDeviceRegistered = false
                        self.hasFaceData = false
                        self.errorMessage = resp.message
                        
                        print("❌ [DeviceRegistrationVM] Backend reported failure: \(resp.message)")
                    }
                    
                case .failure(let error):
                    // Transport / decoding / unknown errors: map to readable string.
                    let msg = self.mapAPIErrorToMessage(error)
                    self.response = nil
                    self.isDeviceRegistered = false
                    self.hasFaceData = false
                    self.errorMessage = msg
                    
                    print("❌ [DeviceRegistrationVM] API failure: \(msg)")
                }
            }
        }
    }
    
    // MARK: - Error Mapping
    
    private func mapAPIErrorToMessage(_ error: APIError) -> String {
        // If your APIError conforms to LocalizedError, this will pick that up.
        if let localized = (error as? LocalizedError)?.errorDescription {
            return localized
        }
        
        // Fallback to generic description.
        return String(describing: error)
    }
}
