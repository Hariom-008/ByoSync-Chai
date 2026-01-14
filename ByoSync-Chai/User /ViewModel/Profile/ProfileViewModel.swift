import Foundation
import SwiftUI
import Combine

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var showAlert: Bool = false
    @Published var alertMessage: String = ""
    @Published var alertTitle: String = ""
    @Published var profilePic: URL?
    
    // Dependencies
    private let getUserDataRepository: GetUserDataRepositoryProtocol
    private let logOutRepository: LogOutRepositoryProtocol
    private let userSession: UserSession
    
    // MARK: - Initialization with Dependency Injection
    init(
        getUserDataRepository: GetUserDataRepositoryProtocol,
        logOutRepository: LogOutRepositoryProtocol,
        userSession: UserSession = .shared
    ) {
        self.getUserDataRepository = getUserDataRepository
        self.logOutRepository = logOutRepository
        self.userSession = userSession
        print("🏗️ [VM] ProfileViewModel initialized")
    }
    
    // MARK: - Fetch User Data
    func fetchUserData() {
        print("📥 [VM] fetchUserData called")
        isLoading = true
        
        getUserDataRepository.getUserData { [weak self] result in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.isLoading = false
                
                switch result {
                case .success(let response):
                    print("✅ [VM] User data fetched successfully")
                    
                    let user = response.data?.user
                    self.alertTitle = L("success")
                    self.alertMessage = """
                    \(L("profile_refreshed"))

                    Name: \(user?.firstName ?? "N/A") \(user?.lastName ?? "N/A")
                    Email: \(user?.email ?? "N/A")
                    Phone: \(user?.phoneNumber ?? "N/A")
                    """
                    self.showAlert = true
                    
                    // Reload profile picture after data refresh
                    self.loadProfilePicture()
                    
                case .failure(let error):
                    print("❌ [VM] Failed to fetch user data: \(error.localizedDescription)")
                    self.alertTitle = L("error_refresh")
                    self.alertMessage = "\(L("refresh_failed"))\n\(error.localizedDescription)"
                    self.showAlert = true
                }
            }
        }
    }
    
    // MARK: - Load Profile Picture
    func loadProfilePicture() {
        print("🖼️ [VM] loadProfilePicture called")
        
        if let url = URL(string: userSession.userProfilePicture),
           !userSession.userProfilePicture.isEmpty {
            profilePic = url
            print("✅ [VM] Loaded profile picture URL: \(url)")
        } else {
            profilePic = nil
            print("⚠️ [VM] No valid profile picture URL found")
        }
    }
    
    // MARK: - Logout Handler
    func performLogout() {
        print("🚪 [VM] performLogout called")
        isLoading = true
        
        logOutRepository.logOut { [weak self] result in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.isLoading = false
                
                switch result {
                case .success:
                    print("✅ [VM] Logout successful")
                    // Session is already cleared by repository
                    // Navigation will be handled by auth state change
                    
                case .failure(let error):
                    print("❌ [VM] Logout failed: \(error.localizedDescription)")
                    self.alertTitle = "Logout Error"
                    self.alertMessage = "Failed to logout: \(error.localizedDescription)"
                    self.showAlert = true
                }
            }
        }
    }
    
    deinit {
        print("♻️ [VM] ProfileViewModel deallocated")
    }
}
