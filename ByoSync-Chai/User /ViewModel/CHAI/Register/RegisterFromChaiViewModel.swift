//
//  RegisterFromChaiViewModel.swift
//  ByoSync-Chai
//
//  Created by Hari's Mac on 14.01.2026.
//

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
            Logger.shared.d("REGISTER_FROM_CHAI_APP", "Skipped: already loading", user: UserSession.shared.currentUser?.userId)
            return
        }

        isLoading = true
        errorText = nil
        message = nil
        newUser = nil

        let emailHash = HMACGenerator.generateHMAC(jsonString: email)
        let phoneNumberHash = HMACGenerator.generateHMAC(jsonString: phoneNumber)
        
        Logger.shared.i("REGISTER_FROM_CHAI_APP", "Start", user: UserSession.shared.currentUser?.userId)
        let startTime = CFAbsoluteTimeGetCurrent()

        do {
            let req = RegisterFromChaiAppRequest(
                firstName: firstName,
                lastName: lastName,
                email: email,
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

            Logger.shared.i(
                "REGISTER_FROM_CHAI_APP",
                "Success | userId=\(res.data.newUser.id) token=\(res.data.newUser.token)",
                timeTakenMs: elapsedMs,
                user: UserSession.shared.currentUser?.userId
            )

            #if DEBUG
            print("✅ [RegisterFromChaiAppVM] success userId=\(res.data.newUser.id) token=\(res.data.newUser.token)")
            #endif

        } catch {
            let elapsedMs = Int64((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0)
            let msg = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            errorText = msg

            Logger.shared.e(
                "REGISTER_FROM_CHAI_APP",
                "Threw | msg=\(msg)",
                error: error,
                timeTakenMs: elapsedMs,
                user: UserSession.shared.currentUser?.userId
            )

            #if DEBUG
            print("❌ [RegisterFromChaiAppVM] failed: \(msg)")
            #endif
        }

        isLoading = false
    }

    func reset() {
        isLoading = false
        newUser = nil
        message = nil
        errorText = nil
        Logger.shared.d("REGISTER_FROM_CHAI_APP", "reset()", user: UserSession.shared.currentUser?.userId)
    }
}
