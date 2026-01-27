import Foundation
import Combine
import SwiftUI

final class FetchUserByTokenViewModel: ObservableObject {

    // MARK: - Published (UI)
    @MainActor @Published private(set) var isLoading: Bool = false
    @MainActor @Published private(set) var faceIds: [FaceId] = []
    @MainActor @Published var userId: String? = nil
    @MainActor @Published private(set) var salt: String? = nil
    @MainActor @Published var deviceKeyHash: String? = nil
    @MainActor @Published private(set) var message: String? = nil
    @MainActor @Published private(set) var errorText: String? = nil
    @MainActor @Published var token: Int = 0

    private let repo: FetchUserByTokenRepositoryProtocol

    init(repo: FetchUserByTokenRepositoryProtocol = FetchUserByTokenRepository()) {
        self.repo = repo
    }

    func fetch(token: Int) async {
        print("🔄 [FetchUserByTokenVM] fetch() called with token: \(token)")
        let tokenHint = "token=\(token)"
        let startTime = CFAbsoluteTimeGetCurrent()

        let shouldStart: Bool = await MainActor.run {
            if isLoading {
                print("⏸️ [FetchUserByTokenVM] Already loading, skipping")
                Logger.shared.d("FETCH_USER_BY_TOKEN", "Skipped: already loading", user: UserSession.shared.currentUser?.userId)
                return false
            }

            self.token = token
            self.isLoading = true
            self.errorText = nil
            self.message = nil

            self.faceIds.removeAll(keepingCapacity: true)
            self.userId = nil
            self.salt = nil
            self.deviceKeyHash = nil
            return true
        }

        guard shouldStart else { return }

        print("📡 [FetchUserByTokenVM] Starting network request")
        Logger.shared.i("FETCH_USER_BY_TOKEN", "Fetch start | \(tokenHint)", user: UserSession.shared.currentUser?.userId)

        do {
            try Task.checkCancellation()

            let res = try await repo.fetchUserByToken(token: token)

            try Task.checkCancellation()

            let elapsedMs = Int64((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0)
            print("📥 [FetchUserByTokenVM] Response received | success: \(res.success) | elapsed: \(elapsedMs)ms")
            print("📊 [FetchUserByTokenVM] Face data count: \(res.data.faceData.count)")

            if !res.success {
                await MainActor.run {
                    self.errorText = res.message
                    self.isLoading = false
                }

                print("❌ [FetchUserByTokenVM] Backend failure: \(res.message)")
                Logger.shared.e(
                    "FETCH_USER_BY_TOKEN",
                    "Backend failure | msg=\(res.message) | \(tokenHint)",
                    timeTakenMs: elapsedMs,
                    user: UserSession.shared.currentUser?.userId
                )
                return
            }

            // ✅ FIX: Update UI state in smaller batches to prevent freeze
            await MainActor.run {
                print("🔄 [FetchUserByTokenVM] Updating basic user data")
                self.userId = res.data.userId
                self.salt = res.data.salt
                self.deviceKeyHash = res.data.deviceKeyHash
                self.message = res.message
            }
            
            // Small delay to let UI update
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            
            // ✅ FIX: Update large array separately
            await MainActor.run {
                print("🔄 [FetchUserByTokenVM] Updating face data (\(res.data.faceData.count) items)")
                self.faceIds = res.data.faceData
                self.isLoading = false
            }

            print("✅ [FetchUserByTokenVM] Data updated successfully")
            Logger.shared.i(
                "FETCH_USER_BY_TOKEN",
                "Fetch success | userId=\(res.data.userId) | faceIds=\(res.data.faceData.count) | \(tokenHint)",
                timeTakenMs: elapsedMs,
                user: UserSession.shared.currentUser?.userId
            )

        } catch is CancellationError {
            let elapsedMs = Int64((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0)
            print("🚫 [FetchUserByTokenVM] Fetch cancelled | elapsed: \(elapsedMs)ms")
            Logger.shared.d("FETCH_USER_BY_TOKEN", "Cancelled | \(tokenHint)", timeTakenMs: elapsedMs, user: UserSession.shared.currentUser?.userId)

            await MainActor.run {
                self.isLoading = false
            }
            return

        } catch {
            let elapsedMs = Int64((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0)
            let msg = (error as? LocalizedError)?.errorDescription ?? String(describing: error)

            print("❌ [FetchUserByTokenVM] Fetch threw error: \(msg)")
            Logger.shared.e(
                "FETCH_USER_BY_TOKEN",
                "Fetch threw | msg=\(msg) | \(tokenHint)",
                error: error,
                timeTakenMs: elapsedMs,
                user: UserSession.shared.currentUser?.userId
            )

            await MainActor.run {
                self.errorText = msg
                self.isLoading = false
            }
        }
    }

    @MainActor
    func clearError() {
        errorText = nil
    }

    @MainActor
    func reset() {
        print("🧹 [FetchUserByTokenVM] reset()")

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
