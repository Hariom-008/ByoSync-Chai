import Foundation
import SwiftUI
import Combine

@MainActor
final class SortedUsersViewModel: ObservableObject {
    @Published var users: [UserData] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    
    // Dependencies
    private let repository: SortedUsersRepositoryProtocol
    private let cryptoManager: CryptoManager
    
    // MARK: - Initialization with Dependency Injection
    init(
        repository: SortedUsersRepositoryProtocol = SortedUsersRepository(),
        cryptoManager: CryptoManager = CryptoManager()
    ) {
        self.repository = repository
        self.cryptoManager = cryptoManager
        print("🏗️ [VM] SortedUsersViewModel initialized")
    }
    
    // MARK: - Fetch Sorted Users
    func fetchSortedUsers() async {
        print("📡 [VM] Starting fetch...")
        isLoading = true
        errorMessage = nil
        showError = false
        
        do {
            // Fetch users from repository
            let fetchedUsers = try await repository.fetchSortedUsers()
            
            users = fetchedUsers
            isLoading = false
            print("✅ [VM] Successfully loaded \(fetchedUsers.count) users")
            
            // Log first few users for debugging
            logUserSample(fetchedUsers)
            
        } catch let error as APIError {
            isLoading = false
            errorMessage = error.localizedDescription
            showError = true
            print("❌ [VM] API Error: \(error.localizedDescription)")
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            showError = true
            print("❌ [VM] Unknown Error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Retry Fetching
    func retry() async {
        print("🔄 [VM] Retrying fetch...")
        await fetchSortedUsers()
    }
    
    // MARK: - Filter Users
    func filterUsers(by searchText: String) -> [UserData] {
        if searchText.isEmpty {
            return users
        }
        
        let searchLower = searchText.lowercased().trimmingCharacters(in: .whitespaces)
        
        let filtered = users.filter { user in
            // Decrypt names for searching
            let firstName = cryptoManager.decrypt(encryptedData: user.firstName) ?? user.firstName
            let lastName = cryptoManager.decrypt(encryptedData: user.lastName) ?? user.lastName
            let fullName = "\(firstName) \(lastName)".lowercased()
            
            return fullName.contains(searchLower) ||
                   user.email.lowercased().contains(searchLower) ||
                   user.phoneNumber.contains(searchText)
        }
        
        print("🔍 [VM] Filtered \(filtered.count) users from \(users.count) for search: '\(searchText)'")
        return filtered
    }
    
    // MARK: - Get User by ID
    func getUser(byId userId: String) -> UserData? {
        let user = users.first(where: { $0.id == userId })
        if let user = user {
            print("✅ [VM] Found user: \(user.firstName) \(user.lastName)")
        } else {
            print("⚠️ [VM] User with ID \(userId) not found")
        }
        return user
    }
    
    // MARK: - Clear Data
    func clearData() {
        users = []
        errorMessage = nil
        showError = false
        print("🗑️ [VM] Data cleared")
    }
    
    // MARK: - Helper Methods
    private func logUserSample(_ users: [UserData]) {
        guard !users.isEmpty else { return }
        
        print("📊 [VM] User sample (first 3):")
        for (index, user) in users.prefix(3).enumerated() {
            let firstName = cryptoManager.decrypt(encryptedData: user.firstName) ?? "Encrypted"
            let lastName = cryptoManager.decrypt(encryptedData: user.lastName) ?? "Encrypted"
            print("   \(index + 1). \(firstName) \(lastName)")
            print("      Email: \(user.email)")
            print("      Transactions: Sent \(user.noOfTransactions), Received \(user.noOfTransactionsReceived)")
        }
    }
    
    deinit {
        print("♻️ [VM] SortedUsersViewModel deallocated")
    }
}
