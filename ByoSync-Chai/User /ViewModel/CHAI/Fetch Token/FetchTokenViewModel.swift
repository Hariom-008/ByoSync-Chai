import Foundation
import Combine
import SwiftUI

@MainActor
final class FindUserTokenByPhoneNumberViewModel: ObservableObject {

    // MARK: - UI State
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var token: Int? = nil
    @Published private(set) var message: String? = nil
    @Published private(set) var errorText: String? = nil

    // MARK: - Dependencies
    private let repo: FindUserTokenByPhoneNumberRepositoryProtocol

    init(repo: FindUserTokenByPhoneNumberRepositoryProtocol = FindUserTokenByPhoneNumberRepository()) {
        self.repo = repo
    }

    // MARK: - Actions

    func fetch(phoneNumber: String) async {
        guard !isLoading else {
            Logger.shared.d("FIND_TOKEN_BY_PHONE_HASH", "Skipped: already loading", user: UserSession.shared.currentUser?.userId)
            return
        }

        // Never log full hash; log last4 only
        let hint: String = {
            let trimmed = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            let last4 = String(trimmed.suffix(4))
            return "len=\(trimmed.count),last4=\(last4)"
        }()

        isLoading = true
        errorText = nil
        message = nil
        token = nil

        Logger.shared.i("FIND_TOKEN_BY_PHONE_HASH", "Fetch start | \(hint)", user: UserSession.shared.currentUser?.userId)
        let startTime = CFAbsoluteTimeGetCurrent()

        do {
            let res = try await repo.findUserTokenByPhoneNumber(phoneNumber: phoneNumber)
            let elapsedMs = Int64((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0)

            guard res.success else {
                errorText = res.message
                isLoading = false

                Logger.shared.e(
                    "FIND_TOKEN_BY_PHONE_HASH",
                    "Backend failure | msg=\(res.message) | \(hint)",
                    timeTakenMs: elapsedMs,
                    user: UserSession.shared.currentUser?.userId
                )
                return
            }

            token = res.data.token
            message = res.message

            Logger.shared.i(
                "FIND_TOKEN_BY_PHONE_HASH",
                "Fetch success | token=\(res.data.token) | \(hint)",
                timeTakenMs: elapsedMs,
                user: UserSession.shared.currentUser?.userId
            )

            #if DEBUG
            print("✅ [FindUserTokenByPhoneNumberVM] success token=\(res.data.token)")
            #endif

        } catch {
            let elapsedMs = Int64((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0)
            let msg = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            errorText = msg

            Logger.shared.e(
                "FIND_TOKEN_BY_PHONE_HASH",
                "Fetch threw | msg=\(msg) | \(hint)",
                error: error,
                timeTakenMs: elapsedMs,
                user: UserSession.shared.currentUser?.userId
            )

            #if DEBUG
            print("❌ [FindUserTokenByPhoneNumberVM] failed: \(msg)")
            #endif
        }

        isLoading = false
    }

    func reset() {
        #if DEBUG
        print("🧹 [FindUserTokenByPhoneNumberVM] reset()")
        #endif

        isLoading = false
        token = nil
        message = nil
        errorText = nil

        Logger.shared.d("FIND_TOKEN_BY_PHONE_HASH", "reset()", user: UserSession.shared.currentUser?.userId)
    }
}
