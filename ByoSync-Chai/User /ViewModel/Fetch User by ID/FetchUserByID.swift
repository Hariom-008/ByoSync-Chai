import Foundation
import Combine
import SwiftUI

@MainActor
final class UserDataByIdViewModel: ObservableObject {
    // MARK: - UI State
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var user: UserByIdDTO? = nil
    @Published private(set) var device: DeviceByIdDTO? = nil
    @Published private(set) var message: String? = nil
    @Published private(set) var errorText: String? = nil

    // Convenience fields
    @Published private(set) var wallet: Double = 0
    @Published private(set) var chai: Int = 0
    @Published private(set) var isPrimaryDevice: Bool = false

    @Published private(set) var hasAttemptedLoad: Bool = false

    // MARK: - Dependencies
    private let repo: UserDataByIdRepositoryProtocol

    init(repo: UserDataByIdRepositoryProtocol = UserDataByIdRepository()) {
        self.repo = repo
    }

    // MARK: - State helpers
    /// Call this right before starting the network call.
    func beginLoading(clearOldData: Bool = true) {
        guard !isLoading else { return }

        hasAttemptedLoad = true
        isLoading = true
        errorText = nil
        message = nil

        if clearOldData {
            user = nil
            device = nil
            wallet = 0
            chai = 0
            isPrimaryDevice = false
        }
    }

    func finishLoading() {
        isLoading = false
    }

    func setError(_ text: String) {
        errorText = text
        isLoading = false
        hasAttemptedLoad = true
    }

    // MARK: - Action (completion-based)

    func fetch(userId: String, deviceKeyHash: String) {
        // If caller forgot, ensure we still flip UI ASAP.
        if !isLoading {
            beginLoading(clearOldData: true)
        } else {
            hasAttemptedLoad = true
        }
        repo.fetchUserDataById(userId: userId, deviceKeyHash: deviceKeyHash) { [weak self] result in
            guard let self else { return }

            DispatchQueue.main.async {
                switch result {
                case .success(let res):
                    
                    guard res.success else {
                        self.errorText = res.message
                        self.isLoading = false
                        return
                    }

                    self.user = res.data.user
                    self.device = res.data.device
                    self.message = res.message

                    self.wallet = res.data.user.wallet
                    self.chai = res.data.user.chai
                    self.isPrimaryDevice = res.data.device.isPrimary

                    
                    let user = User(firstName: res.data.user.firstName, lastName: res.data.user.lastName, email: res.data.user.email,phoneNumber:res.data.user.phoneNumber,deviceKey: res.data.device.deviceKey,deviceName: res.data.device.deviceName,userId: res.data.user.id,userDeviceId: res.data.device.id)
                    
                    UserSession.shared.saveUser(user)
                    UserDefaults.standard.set("user", forKey: "accountType")
                    
                    self.isLoading = false

                case .failure(let err):
                    self.errorText = String(describing: err)
                    self.isLoading = false
                }
            }
        }
    }

    func reset() {
        isLoading = false
        hasAttemptedLoad = false
        user = nil
        device = nil
        message = nil
        errorText = nil
        wallet = 0
        chai = 0
        isPrimaryDevice = false
    }
}

#if DEBUG
extension UserDataByIdViewModel {
    func loadMock() {
        isLoading = false
        hasAttemptedLoad = true
        errorText = nil
        message = "Mock data loaded"
        user = .mock
        device = .mockPrimary

        wallet = user?.wallet ?? 0
        chai = user?.chai ?? 0
        isPrimaryDevice = device?.isPrimary ?? false
    }

    func loadMockLoading() {
        reset()
        hasAttemptedLoad = true
        isLoading = true
    }

    func loadMockError(_ text: String = "Mock error: something failed") {
        reset()
        hasAttemptedLoad = true
        errorText = text
    }
}
#endif
