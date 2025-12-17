// FetchUserByPhoneNumberViewModel.swift

import Foundation
import Combine
import SwiftUI

@MainActor
final class FetchUserByPhoneNumberViewModel: ObservableObject {

    // MARK: - UI State
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var faceIds: [FaceId] = []          // always replaced on fetch
    @Published private(set) var userId: String? = nil
    @Published private(set) var salt: String? = nil
    @Published private(set) var deviceKeyHash: String? = nil
    @Published private(set) var message: String? = nil
    @Published private(set) var errorText: String? = nil

    // MARK: - Dependencies
    private let repo: FetchUserByPhoneNumberRepositoryProtocol

    init(repo: FetchUserByPhoneNumberRepositoryProtocol = FetchUserByPhoneNumberRepository()) {
        self.repo = repo
    }

    // MARK: - Actions

    /// Clears old data and fetches fresh data. `faceIds` is replaced (not appended).
    func fetch(phoneNumber: String) async {
        guard !isLoading else { return }

        isLoading = true
        errorText = nil
        message = nil

        // Clear old data immediately (so UI doesn't show stale faceIds)
        faceIds.removeAll(keepingCapacity: true)
        userId = nil
        salt = nil
        deviceKeyHash = nil

        do {
            let res = try await repo.fetchUserByPhoneNumber(phoneNumber: phoneNumber)

            guard res.success else {
                errorText = res.message
                isLoading = false
                return
            }

            // Replace everything with fresh values
            userId = res.data.userId
            salt = res.data.salt
            deviceKeyHash = res.data.deviceKeyHash
            faceIds = res.data.faceData
            message = res.message
        } catch {
            errorText = String(describing: error)
        }

        isLoading = false
    }

    func reset() {
        isLoading = false
        faceIds.removeAll()
        userId = nil
        salt = nil
        deviceKeyHash = nil
        message = nil
        errorText = nil
    }
}
