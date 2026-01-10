// UserDataByIdViewModel.swift

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

    // Convenience fields if your UI needs them directly
    @Published private(set) var wallet: Double = 0
    @Published private(set) var chai: Int = 0
    @Published private(set) var isPrimaryDevice: Bool = false

    // MARK: - Dependencies
    private let repo: UserDataByIdRepositoryProtocol

    init(repo: UserDataByIdRepositoryProtocol = UserDataByIdRepository()) {
        self.repo = repo
    }

    // MARK: - Actions

    /// Fetches user+device. Clears old data on each call.
    func fetch(userId: String, deviceKeyHash: String) async {
        guard !isLoading else { return }

        // Clear old data so UI doesn't show stale values
        isLoading = true
        errorText = nil
        message = nil
        user = nil
        device = nil
        wallet = 0
        chai = 0
        isPrimaryDevice = false

        do {
            let res = try await repo.fetchUserDataById(userId: userId, deviceKeyHash: deviceKeyHash)

            guard res.success else {
                errorText = res.message
                isLoading = false
                return
            }

            user = res.data.user
            device = res.data.device
            message = res.message

            // Derived values (safe defaults)
            wallet = res.data.user.wallet
            chai = res.data.user.chai + 1
            isPrimaryDevice = res.data.device.isPrimary
        } catch {
            errorText = String(describing: error)
        }

        isLoading = false
    }

    func reset() {
        isLoading = false
        user = nil
        device = nil
        message = nil
        errorText = nil
        wallet = 0
        chai = 0
        isPrimaryDevice = false
    }
}
