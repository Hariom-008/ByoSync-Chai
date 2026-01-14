import Foundation
import SwiftUI
import Combine

@MainActor
final class GetUserRankViewModel: ObservableObject {
    @Published var users: [UserData] = []
    @Published var errorMessage: String = ""
    @Published var isLoading: Bool = false
    
    // Dependencies
    private let repository: GetUserRankBoardRepositoryProtocol
    private let cryptoManager: CryptoManager
    private let userSession: UserSession
    
    // MARK: - Initialization with Dependency Injection
    init(
        repository: GetUserRankBoardRepositoryProtocol = GetUserRankBoardRepository(),
        cryptoManager: CryptoManager = CryptoManager(),
        userSession: UserSession = .shared
    ) {
        self.repository = repository
        self.cryptoManager = cryptoManager
        self.userSession = userSession
        print("🏗️ [VM] GetUserRankViewModel initialized")
    }
    
    // MARK: - Fetch All Users
    func fetchAllUsers() {
        print("📡 [VM] Starting to fetch all users for leaderboard...")
        isLoading = true
        errorMessage = ""
        
        repository.getUserRankBoard { [weak self] result in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.isLoading = false
                
                switch result {
                case .success(let response):
                    print("✅ [VM] Successfully fetched \(response.data.count) users from leaderboard")
                    print("📊 [VM] Response: \(response.message)")
                    self.users = response.data
                    
                    // Update current user's wallet balance
                    self.updateCurrentUserWallet(from: response.data)
                    
                    // Debug: Print top 3 users
                    self.logTopUsers(response.data)
                    
                case .failure(let error):
                    print("❌ [VM] Failed to fetch leaderboard data")
                    print("❌ [VM] Error: \(error.localizedDescription)")
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: - Update Current User Wallet
    private func updateCurrentUserWallet(from users: [UserData]) {
        guard let currentUserId = userSession.currentUser?.userId else {
            print("⚠️ [VM] No current user ID found")
            return
        }
        
        if let currentUser = users.first(where: { $0.id == currentUserId }) {
            userSession.wallet = currentUser.wallet
            print("✅ [VM] Updated wallet balance for current user: $\(currentUser.wallet)")
        } else {
            print("⚠️ [VM] Current user not found in leaderboard data")
        }
    }
    
    // MARK: - Log Top Users
    private func logTopUsers(_ users: [UserData]) {
        let topUsers = users.prefix(3)
        print("🏆 [VM] Top 3 Users:")
        for (index, user) in topUsers.enumerated() {
            let firstName = cryptoManager.decrypt(encryptedData: user.firstName) ?? "Unknown"
            let lastName = cryptoManager.decrypt(encryptedData: user.lastName) ?? "Unknown"
            print("   #\(index + 1): \(firstName) \(lastName)")
            print("       Transactions: \(user.noOfTransactions)")
            print("       Coins: \(user.transactionCoins)")
            print("       Wallet: $\(user.wallet)")
        }
    }
    
    // MARK: - Get User Rank
    func getUserRank(userId: String, sortBy: SortCriteria) -> Int? {
        print("📍 [VM] Getting rank for user: \(userId), sorted by: \(sortBy)")
        
        let sortedUsers = getSortedUsers(by: sortBy)
        if let index = sortedUsers.firstIndex(where: { $0.id == userId }) {
            let rank = index + 1
            print("✅ [VM] User rank: #\(rank)")
            return rank
        }
        
        print("⚠️ [VM] User \(userId) not found in leaderboard")
        return nil
    }
    
    // MARK: - Get Sorted Users
    func getSortedUsers(by criteria: SortCriteria) -> [UserData] {
        let sorted: [UserData]
        
        switch criteria {
        case .transactions:
            sorted = users.sorted { $0.noOfTransactions > $1.noOfTransactions }
            print("📊 [VM] Sorted \(sorted.count) users by transactions")
        case .coins:
            sorted = users.sorted { $0.transactionCoins > $1.transactionCoins }
            print("🪙 [VM] Sorted \(sorted.count) users by coins")
        case .wallet:
            sorted = users.sorted { $0.wallet > $1.wallet }
            print("💰 [VM] Sorted \(sorted.count) users by wallet balance")
        }
        
        return sorted
    }
    
    // MARK: - Get Current User Rank
    func getCurrentUserRank(sortBy: SortCriteria) -> Int? {
        guard let currentUserId = userSession.currentUser?.userId else {
            print("⚠️ [VM] No current user ID for rank calculation")
            return nil
        }
        return getUserRank(userId: currentUserId, sortBy: sortBy)
    }
    
    // MARK: - Sort Criteria Enum
    enum SortCriteria: String {
        case transactions = "Transactions"
        case coins = "Coins"
        case wallet = "Wallet Balance"
    }
    
    deinit {
        print("♻️ [VM] GetUserRankViewModel deallocated")
    }
}
