import Foundation
import Combine
import SwiftUI

@MainActor
final class FetchUserByTokenViewModel: ObservableObject {

    // MARK: - UI State
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var faceIds: [FaceId] = []          // always replaced on fetch
    @Published var userId: String? = nil
    @Published private(set) var salt: String? = nil
    @Published var deviceKeyHash: String? = nil
    @Published private(set) var message: String? = nil
    @Published private(set) var errorText: String? = nil
    
    @Published var token:Int = 0

    // MARK: - Dependencies
    private let repo: FetchUserByTokenRepositoryProtocol

    init(repo: FetchUserByTokenRepositoryProtocol = FetchUserByTokenRepository()) {
        self.repo = repo
    }

    // MARK: - Actions

    /// Clears old data and fetches fresh data. `faceIds` is replaced (not appended).
    func fetch(token: Int) async {
        guard !isLoading else {
            Logger.shared.d("FETCH_USER_BY_TOKEN", "Skipped: already loading", user: UserSession.shared.currentUser?.userId)
            return
        }
        self.token = token

        // Avoid logging full token if you consider it sensitive. Keep minimal.
        let tokenHint = "token=\(token)"

        isLoading = true
        errorText = nil
        message = nil

        // Clear old data immediately (so UI doesn't show stale data)
        faceIds.removeAll(keepingCapacity: true)
        userId = nil
        salt = nil
        deviceKeyHash = nil

        Logger.shared.i("FETCH_USER_BY_TOKEN", "Fetch start | \(tokenHint)", user: UserSession.shared.currentUser?.userId)
        let startTime = CFAbsoluteTimeGetCurrent()

        do {
            let res = try await repo.fetchUserByToken(token: token)
            let elapsedMs = Int64((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0)

            guard res.success else {
                errorText = res.message
                isLoading = false

                Logger.shared.e(
                    "FETCH_USER_BY_TOKEN",
                    "Backend failure | msg=\(res.message) | \(tokenHint)",
                    timeTakenMs: elapsedMs,
                    user: UserSession.shared.currentUser?.userId
                )
                return
            }

            // Replace everything with fresh values
            userId = res.data.userId
            salt = res.data.salt
            //deviceKeyHash = res.data.deviceKeyHash
            deviceKeyHash = ""
            faceIds = res.data.faceData
            message = res.message

            Logger.shared.i(
                "FETCH_USER_BY_TOKEN",
                "Fetch success | userId=\(res.data.userId) | faceIds=\(res.data.faceData.count) | \(tokenHint)",
                timeTakenMs: elapsedMs,
                user: UserSession.shared.currentUser?.userId
            )

            #if DEBUG
            print("✅ [FetchUserByTokenVM] success userId=\(res.data.userId) faceIds=\(res.data.faceData.count)")
            #endif

        } catch {
            let elapsedMs = Int64((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0)

            let msg = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            errorText = msg

            Logger.shared.e(
                "FETCH_USER_BY_TOKEN",
                "Fetch threw | msg=\(msg) | \(tokenHint)",
                error: error,
                timeTakenMs: elapsedMs,
                user: UserSession.shared.currentUser?.userId
            )

            #if DEBUG
            print("❌ [FetchUserByTokenVM] failed: \(msg)")
            #endif
        }

        isLoading = false
    }

    func reset() {
        #if DEBUG
        print("🧹 [FetchUserByTokenVM] reset()")
        #endif

        isLoading = false
        faceIds.removeAll()
        userId = nil
        salt = nil
        deviceKeyHash = nil
        message = nil
        errorText = nil

        Logger.shared.d("FETCH_USER_BY_TOKEN", "reset()", user: UserSession.shared.currentUser?.userId)
    }
}
