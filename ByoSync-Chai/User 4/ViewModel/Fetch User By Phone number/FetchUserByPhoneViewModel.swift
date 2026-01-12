import Foundation
import Combine
import SwiftUI

@MainActor
final class FetchUserByPhoneNumberViewModel: ObservableObject {

    // MARK: - UI State
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var faceIds: [FaceId] = []          // always replaced on fetch
    @Published var userId: String? = nil
    @Published private(set) var salt: String? = nil
    @Published var deviceKeyHash: String? = nil
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
        guard !isLoading else {
            Logger.shared.d("FETCH_USER_By_Phone", "Skipped: already loading", user: UserSession.shared.currentUser?.userId)
            return
        }

        // NOTE: avoid logging raw phoneNumber (PII). Log length / last2 only.
        let phoneHint: String = {
            let trimmed = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            let last2 = String(trimmed.suffix(2))
            return "len=\(trimmed.count),last2=\(last2)"
        }()

        isLoading = true
        errorText = nil
        message = nil

        // Clear old data immediately (so UI doesn't show stale faceIds)
        faceIds.removeAll(keepingCapacity: true)
        userId = nil
        salt = nil
        deviceKeyHash = nil

        Logger.shared.i("FETCH_USER_BY_PHONE", "Fetch start | \(phoneHint)", user: UserSession.shared.currentUser?.userId)
        let startTime = CFAbsoluteTimeGetCurrent()

        do {
            let res = try await repo.fetchUserByPhoneNumber(phoneNumber: phoneNumber)
            let elapsedMs = Int64((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0)

            guard res.success else {
                errorText = res.message
                isLoading = false

                Logger.shared.e(
                    "FETCH_USER_BY_PHONE",
                    "Backend failure | msg=\(res.message) | \(phoneHint)",
                    timeTakenMs: elapsedMs,
                    user: UserSession.shared.currentUser?.userId
                )
                return
            }

            // Replace everything with fresh values
            userId = res.data.userId
            salt = res.data.salt
            deviceKeyHash = res.data.deviceKeyHash
            faceIds = res.data.faceData
            message = res.message

            Logger.shared.i(
                "FETCH_USER_BY_PHONE",
                "Fetch success | userId=\(res.data.userId) | faceIds=\(res.data.faceData.count) | \(phoneHint)",
                timeTakenMs: elapsedMs,
                user: UserSession.shared.currentUser?.userId
            )

            #if DEBUG
            print("✅ [FetchUserByPhoneNumberVM] success userId=\(res.data.userId) faceIds=\(res.data.faceData.count)")
            #endif

        } catch {
            let elapsedMs = Int64((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0)

            // Prefer LocalizedError if present
            let msg = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            errorText = msg

            Logger.shared.e(
                "FETCH_USER_BY_PHONE",
                "Fetch threw | msg=\(msg) | \(phoneHint)",
                error: error,
                timeTakenMs: elapsedMs,
                user: UserSession.shared.currentUser?.userId
            )

            #if DEBUG
            print("❌ [FetchUserByPhoneNumberVM] failed: \(msg)")
            #endif
        }

        isLoading = false
    }

    func reset() {
        #if DEBUG
        print("🧹 [FetchUserByPhoneNumberVM] reset()")
        #endif

        isLoading = false
        faceIds.removeAll()
        userId = nil
        salt = nil
        deviceKeyHash = nil
        message = nil
        errorText = nil

        Logger.shared.d("FETCH_USER_BY_PHONE", "reset()", user: UserSession.shared.currentUser?.userId)
    }
}
