//
//  AdminDeleteFaceIdViewModel.swift
//

import Foundation
import Combine

@MainActor
final class AdminDeleteFaceIdViewModel: ObservableObject {

    enum UIState: Equatable {
        case idle
        case loading
        case success(message: String)
        case failure(errorMessage: String)
    }

    @Published private(set) var state: UIState = .idle

    private let repo: AdminDeleteFaceIdRepositoryProtocol

    init(repo: AdminDeleteFaceIdRepositoryProtocol = AdminDeleteFaceIdRepository()) {
        self.repo = repo
    }

    func reset() {
        state = .idle
    }

    // ✅ authToken removed
    func deleteFaceId(phoneNumberHash: String) {
        state = .loading

        repo.deleteFaceId(phoneNumberHash: phoneNumberHash) { [weak self] result in
            guard let self else { return }

            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    let msg = response.message ?? "Face Data deleted successfully"
                    self.state = .success(message: msg)

                case .failure(let err):
                    self.state = .failure(errorMessage: err.localizedDescription)
                }
            }
        }
    }
}
