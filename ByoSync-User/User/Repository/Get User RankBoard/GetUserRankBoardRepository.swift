//
//  GetUserRankBoardRepository.swift
//  ByoSync-User
//
//  Created by Hari's Mac on 08.11.2025.
//

import Foundation
import SwiftUI
import Alamofire
import Combine

struct LeaderboardAPIResponse: Codable {
    let statusCode: Int
    let data: [UserData]
    let message: String
}

// MARK: - Protocol for Testability
protocol GetUserRankBoardRepositoryProtocol {
    func getUserRankBoard(completion: @escaping (Result<LeaderboardAPIResponse, APIError>) -> Void)
}

final class GetUserRankBoardRepository: GetUserRankBoardRepositoryProtocol {
    
    // MARK: - Initialization (No Singleton)
    init() {
        print("🏗️ [REPO] GetUserRankBoardRepository initialized")
    }
    
    // MARK: - Private Helper: Get Auth Headers
    private func getAuthHeaders() -> HTTPHeaders {
        return getHeader.shared.getAuthHeaders()
    }
    
    // MARK: - Fetch User Rankboard
    func getUserRankBoard(completion: @escaping (Result<LeaderboardAPIResponse, APIError>) -> Void) {
        print("📤 [REPO] Fetching user rankboard from API...")
        
        let urlString = UserAPIEndpoint.Leaderboard.getRankboard
        let headers = getAuthHeaders()
        
        print("📍 [REPO] URL: \(urlString)")
        
        APIClient.shared.request(
            urlString,
            method: .get,
            parameters: nil,
            headers: headers
        ) { (result: Result<LeaderboardAPIResponse, APIError>) in
            switch result {
            case .success(let response):
                print("✅ [REPO] Successfully fetched \(response.data.count) users from leaderboard")
                print("💬 [REPO] Response: \(response.message)")
                completion(.success(response))
                
            case .failure(let error):
                print("❌ [REPO] Failed to fetch leaderboard data: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    deinit {
        print("♻️ [REPO] GetUserRankBoardRepository deallocated")
    }
}


