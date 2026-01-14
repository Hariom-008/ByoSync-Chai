import Foundation
import Combine

@MainActor
final class AdminLoginViewModel: ObservableObject {

    @Published var email: String = ""
    @Published var password: String = ""

    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published private(set) var adminUser: AdminUser? = nil
    @Published private(set) var successMessage: String? = nil

    private let repo: AdminLoginRepository

    init(repo: AdminLoginRepository) {
        self.repo = repo
    }

    convenience init() {
        self.init(repo: .shared)
    }
    

    func login() {
        errorMessage = nil
        successMessage = nil
        isLoading = true

        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        repo.login(email: cleanEmail, password: password) { [weak self] result in
            guard let self else { return }

            Task { @MainActor in
                self.isLoading = false

                switch result {
                case .success(let res):
                    guard res.success else {
                        self.errorMessage = res.message
                        return
                    }
                    self.adminUser = res.data
                    self.successMessage = res.message

                case .failure(let err):
                    self.errorMessage = err.localizedDescription
                }
            }
        }
    }
}
