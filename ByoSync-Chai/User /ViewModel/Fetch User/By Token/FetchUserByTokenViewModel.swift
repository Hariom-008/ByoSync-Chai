import Foundation
import Combine
import SwiftUI

@MainActor
final class FetchUserByTokenViewModel: ObservableObject {

    @Published private(set) var isLoading: Bool = false
    @Published private(set) var faceIds: [FaceId] = []
    @Published var userId: String? = nil
    @Published private(set) var salt: String? = nil
    @Published var deviceKeyHash: String? = nil
    @Published private(set) var message: String? = nil
    @Published private(set) var errorText: String? = nil
    @Published var token: Int = 0
    @Published var fetchCompleted: Bool = false

    private let repo: FetchUserByTokenRepositoryProtocol

    init(repo: FetchUserByTokenRepositoryProtocol = FetchUserByTokenRepository()) {
        self.repo = repo
    }

    func fetch(token: Int) async {
        print("🔄 [FetchUserByTokenVM] fetch() called with token: \(token)")
        
        guard !isLoading else {
            print("⏸️ [FetchUserByTokenVM] Already loading, skipping")
            Logger.shared.d("FETCH_USER_BY_TOKEN", "Skipped: already loading", user: UserSession.shared.currentUser?.userId)
            return
        }
        
        self.token = token
        let tokenHint = "token=\(token)"

        fetchCompleted = false
        isLoading = true
        errorText = nil
        message = nil

        faceIds.removeAll(keepingCapacity: true)
        userId = nil
        salt = nil
        deviceKeyHash = nil

        print("📡 [FetchUserByTokenVM] Starting network request")
        Logger.shared.i("FETCH_USER_BY_TOKEN", "Fetch start | \(tokenHint)", user: UserSession.shared.currentUser?.userId)
        let startTime = CFAbsoluteTimeGetCurrent()

        do {
            try Task.checkCancellation()
            
            let res = try await repo.fetchUserByToken(token: token)
            
            try Task.checkCancellation()
            
            let elapsedMs = Int64((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0)
            print("📥 [FetchUserByTokenVM] Response received | success: \(res.success) | elapsed: \(elapsedMs)ms")
            
            guard res.success else {
                errorText = res.message
                isLoading = false
                
                try? await Task.sleep(nanoseconds: 50_000_000)
                fetchCompleted = true

                print("❌ [FetchUserByTokenVM] Backend failure: \(res.message)")
                Logger.shared.e(
                    "FETCH_USER_BY_TOKEN",
                    "Backend failure | msg=\(res.message) | \(tokenHint)",
                    timeTakenMs: elapsedMs,
                    user: UserSession.shared.currentUser?.userId
                )
                return
            }

            userId = res.data.userId
            salt = res.data.salt
            deviceKeyHash = res.data.deviceKeyHash
            faceIds = res.data.faceData
            message = res.message
            
            print("✅ [FetchUserByTokenVM] Data updated successfully")
            print("   userId: \(res.data.userId)")
            print("   faceIds count: \(res.data.faceData.count)")
            print("   deviceKeyHash: \(res.data.deviceKeyHash ?? "nil")")

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
            
            isLoading = false
            fetchCompleted = false
            return
            
        } catch {
            let elapsedMs = Int64((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0)
            let msg = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            errorText = msg

            print("❌ [FetchUserByTokenVM] Fetch threw error: \(msg)")
            Logger.shared.e(
                "FETCH_USER_BY_TOKEN",
                "Fetch threw | msg=\(msg) | \(tokenHint)",
                error: error,
                timeTakenMs: elapsedMs,
                user: UserSession.shared.currentUser?.userId
            )
        }

        print("🏁 [FetchUserByTokenVM] Setting completion flags")
        isLoading = false
        
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        fetchCompleted = true
        print("🏁 [FetchUserByTokenVM] Fetch completed | isLoading: \(isLoading) | fetchCompleted: \(fetchCompleted)")
    }

    func reset() {
        print("🧹 [FetchUserByTokenVM] reset()")

        isLoading = false
        fetchCompleted = false
        faceIds.removeAll()
        userId = nil
        salt = nil
        deviceKeyHash = nil
        message = nil
        errorText = nil

        Logger.shared.d("FETCH_USER_BY_TOKEN", "reset()", user: UserSession.shared.currentUser?.userId)
    }
}
