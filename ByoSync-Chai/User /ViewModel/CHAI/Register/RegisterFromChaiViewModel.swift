import Foundation
import Combine
import SwiftUI

@MainActor
final class RegisterFromChaiAppViewModel: ObservableObject {

    // MARK: - UI State
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var newUser: RegisterFromChaiAppUser? = nil
    @Published private(set) var message: String? = nil
    @Published private(set) var errorText: String? = nil

    // MARK: - Dependencies
    private let repo: RegisterFromChaiAppRepositoryProtocol

    init(repo: RegisterFromChaiAppRepositoryProtocol = RegisterFromChaiAppRepository()) {
        self.repo = repo
    }

    func register(
        firstName: String,
        lastName: String,
        email: String,
        phoneNumber: String,
        deviceId: String
    ) async {
        guard !isLoading else {
            print("⏸️ [RegisterFromChaiAppVM] Skipped: already loading")
            Logger.shared.d("REGISTER_FROM_CHAI_APP", "Skipped: already loading", user: UserSession.shared.currentUser?.userId)
            return
        }

        isLoading = true
        errorText = nil
        message = nil
        newUser = nil

        // Handle optional email - use empty string if not provided
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalEmail = trimmedEmail.isEmpty ? "" : trimmedEmail
        
        // Generate hashes - empty string if email is empty
        let emailHash = finalEmail.isEmpty ? "" : HMACGenerator.generateHMAC(jsonString: finalEmail)
        let phoneNumberHash = HMACGenerator.generateHMAC(jsonString: phoneNumber)
        
        print("📝 [RegisterFromChaiAppVM] Starting registration")
        print("   Email provided: \(finalEmail.isEmpty ? "NO" : "YES")")
        print("   Phone: \(phoneNumber)")
        
        Logger.shared.i("REGISTER_FROM_CHAI_APP", "Start | emailProvided=\(finalEmail.isEmpty ? "NO" : "YES")", user: UserSession.shared.currentUser?.userId)
        let startTime = CFAbsoluteTimeGetCurrent()

        do {
            let req = RegisterFromChaiAppRequest(
                firstName: firstName,
                lastName: lastName,
                email: finalEmail,
                emailHash: emailHash,
                phoneNumber: phoneNumber,
                phoneNumberHash: phoneNumberHash,
                deviceId: KeychainHelper.shared.read(forKey: "chaiDeviceId") ?? ""
            )

            let res = try await repo.registerFromChaiApp(req: req)
            let elapsedMs = Int64((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0)

            guard res.success else {
                errorText = res.message
                isLoading = false
                
                print("❌ [RegisterFromChaiAppVM] Backend failure: \(res.message)")
                Logger.shared.e(
                    "REGISTER_FROM_CHAI_APP",
                    "Backend failure | msg=\(res.message)",
                    timeTakenMs: elapsedMs,
                    user: UserSession.shared.currentUser?.userId
                )
                return
            }

            await MainActor.run {
                self.newUser = res.data.newUser
            }
            message = res.message

            print("✅ [RegisterFromChaiAppVM] Success")
            print("   User ID: \(res.data.newUser.id)")
            print("   Token: \(res.data.newUser.token)")
            
            Logger.shared.i(
                "REGISTER_FROM_CHAI_APP",
                "Success | userId=\(res.data.newUser.id) token=\(res.data.newUser.token)",
                timeTakenMs: elapsedMs,
                user: UserSession.shared.currentUser?.userId
            )

        } catch {
            let elapsedMs = Int64((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0)
            let msg = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            errorText = msg

            print("❌ [RegisterFromChaiAppVM] Error: \(msg)")
            Logger.shared.e(
                "REGISTER_FROM_CHAI_APP",
                "Threw | msg=\(msg)",
                error: error,
                timeTakenMs: elapsedMs,
                user: UserSession.shared.currentUser?.userId
            )
        }

        isLoading = false
    }

    func reset() {
        isLoading = false
        newUser = nil
        message = nil
        errorText = nil
        
        print("🧹 [RegisterFromChaiAppVM] State reset")
        Logger.shared.d("REGISTER_FROM_CHAI_APP", "reset()", user: UserSession.shared.currentUser?.userId)
    }
}
