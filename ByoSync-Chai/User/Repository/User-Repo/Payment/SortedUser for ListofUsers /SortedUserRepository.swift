//
//  SortedUserRepository.swift
//  ByoSync-User
//
//  Created by Hari's Mac on 08.11.2025.
//

import Foundation
import SwiftUI
import Combine
import Alamofire

// MARK: - Sorted Users Response
struct SortedUsersResponse: Codable {
    let statusCode: Int
    let data: [UserData]
    let message: String
}

// MARK: - Protocol for Testability
protocol SortedUsersRepositoryProtocol {
    func fetchSortedUsers() async throws -> [UserData]
}

final class SortedUsersRepository: SortedUsersRepositoryProtocol {
    
    // MARK: - Initialization (No Singleton)
    init() {
        print("🏗️ [REPO] SortedUsersRepository initialized")
    }
    
    // MARK: - Private Helper: Get Auth Headers
    private func getAuthHeaders() -> HTTPHeaders {
        return getHeader.shared.getAuthHeaders()
    }
    
    // MARK: - Fetch Sorted Users
    func fetchSortedUsers() async throws -> [UserData] {
        print("📤 [REPO] Starting to fetch sorted users...")
        
        let urlString = UserAPIEndpoint.GetUserSorted.getUserSortedbyTransaction
        let headers = getAuthHeaders()
        
        print("📍 [REPO] URL: \(urlString)")
        
        return try await withCheckedThrowingContinuation { continuation in
            APIClient.shared.request(
                urlString,
                method: .get,
                parameters: nil,
                headers: headers
            ) { (result: Result<SortedUsersResponse, APIError>) in
                switch result {
                case .success(let response):
                    print("✅ [REPO] Successfully fetched \(response.data.count) users")
                    print("💬 [REPO] Response message: \(response.message)")
                    continuation.resume(returning: response.data)
                    
                case .failure(let error):
                    print("❌ [REPO] Failed to fetch users: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    deinit {
        print("♻️ [REPO] SortedUsersRepository deallocated")
    }
}
