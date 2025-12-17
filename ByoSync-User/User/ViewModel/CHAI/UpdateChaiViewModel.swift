// ChaiViewModel.swift

import Foundation
import Combine

@MainActor
final class ChaiViewModel: ObservableObject {

    // MARK: - UI State
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var chai: Int = 0              // increments on success, max 5
    @Published private(set) var lastMessage: String? = nil
    @Published private(set) var lastError: String? = nil

    // MARK: - Dependencies
    private let repo: ChaiRepositoryProtocol

    init(repo: ChaiRepositoryProtocol = ChaiRepository()) {
        self.repo = repo
    }

    // MARK: - Actions (async/await)
    func updateChai(userId: String) async {
        guard !isLoading else { return }

        isLoading = true
        lastError = nil
        lastMessage = nil

        do {
            let envelope = try await repo.updateChai(userId: userId)

            // Your API returns:
            // { statusCode: 200, data: {}, message: "...", success: true }
            if envelope.success ?? false, envelope.statusCode == 200 {
                chai = min(chai + 1, 5)
            }

            lastMessage = envelope.message
        } catch {
            lastError = String(describing: error)
        }

        isLoading = false
    }

    // Optional: if you want to reset chain manually (e.g., on logout)
    func resetChain() {
        chai = 0
    }
}
