//
//  SummaryTransactionRepo.swift
//  ByoSync
//
//  Created by Hari's Mac on 02.11.2025.
//

import Foundation
import SwiftUI
import Alamofire

// MARK: - Protocol for Testability
protocol SummaryTransactionRepositoryProtocol {
    func fetchDailySummary(
        date: String,
        completion: @escaping (Result<SummaryTransactionData, APIError>) -> Void
    )
    
    func fetchMonthlySummary(
        month: String,
        year: String,
        completion: @escaping (Result<SummaryTransactionData, APIError>) -> Void
    )
    
    func fetchCustomSummary(
        startDate: String,
        endDate: String,
        completion: @escaping (Result<SummaryTransactionData, APIError>) -> Void
    )
    
    func fetchWeeklySummary(
        startDate: String,
        endDate: String,
        completion: @escaping (Result<SummaryTransactionData, APIError>) -> Void
    )
    
    func fetchYearlySummary(
        year: String,
        completion: @escaping (Result<SummaryTransactionData, APIError>) -> Void
    )
}

final class SummaryTransactionRepository: SummaryTransactionRepositoryProtocol {
    
    // MARK: - Initialization (No Singleton)
    init() {
        print("🏗️ [REPO] SummaryTransactionRepository initialized")
    }
    
    // MARK: - Private Helper: Get Auth Headers
    private func getAuthHeaders() -> HTTPHeaders {
        return getHeader.shared.getAuthHeaders()
    }
    
    // MARK: - Fetch Daily Summary
    func fetchDailySummary(
        date: String,
        completion: @escaping (Result<SummaryTransactionData, APIError>) -> Void
    ) {
        let endpoint = CommonEndpoint.summaryTransactionData
        let parameters: [String: Any] = [
            "date": date,
            "type": "daily"
        ]
        
        print("📤 [REPO] Fetching Daily Summary")
        print("📍 [REPO] URL: \(endpoint)")
        print("📅 [REPO] Date: \(date)")
        
        let headers = getAuthHeaders()
        
        APIClient.shared.request(
            endpoint,
            method: .post,
            parameters: parameters,
            headers: headers
        ) { (result: Result<SummaryTransactionResponse, APIError>) in
            switch result {
            case .success(let response):
                print("✅ [REPO] Daily summary fetched successfully")
                completion(.success(response.data))
            case .failure(let error):
                print("❌ [REPO] Failed to fetch daily summary: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Fetch Monthly Summary
    func fetchMonthlySummary(
        month: String,
        year: String,
        completion: @escaping (Result<SummaryTransactionData, APIError>) -> Void
    ) {
        let endpoint = CommonEndpoint.summaryTransactionData
        let parameters: [String: Any] = [
            "month": month,
            "year": year,
            "type": "monthly"
        ]
        
        print("📤 [REPO] Fetching Monthly Summary")
        print("📍 [REPO] URL: \(endpoint)")
        print("📅 [REPO] Month: \(month), Year: \(year)")
        
        let headers = getAuthHeaders()
        
        APIClient.shared.request(
            endpoint,
            method: .post,
            parameters: parameters,
            headers: headers
        ) { (result: Result<SummaryTransactionResponse, APIError>) in
            switch result {
            case .success(let response):
                print("✅ [REPO] Monthly summary fetched successfully")
                completion(.success(response.data))
            case .failure(let error):
                print("❌ [REPO] Failed to fetch monthly summary: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Fetch Custom Period Summary
    func fetchCustomSummary(
        startDate: String,
        endDate: String,
        completion: @escaping (Result<SummaryTransactionData, APIError>) -> Void
    ) {
        let endpoint = CommonEndpoint.summaryTransactionData
        let parameters: [String: Any] = [
            "startDate": startDate,
            "endDate": endDate,
            "type": "custom"
        ]
        
        print("📤 [REPO] Fetching Custom Summary")
        print("📍 [REPO] URL: \(endpoint)")
        print("📅 [REPO] Start Date: \(startDate), End Date: \(endDate)")
        
        let headers = getAuthHeaders()
        
        APIClient.shared.request(
            endpoint,
            method: .post,
            parameters: parameters,
            headers: headers
        ) { (result: Result<SummaryTransactionResponse, APIError>) in
            switch result {
            case .success(let response):
                print("✅ [REPO] Custom summary fetched successfully")
                completion(.success(response.data))
            case .failure(let error):
                print("❌ [REPO] Failed to fetch custom summary: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Fetch Weekly Summary
    func fetchWeeklySummary(
        startDate: String,
        endDate: String,
        completion: @escaping (Result<SummaryTransactionData, APIError>) -> Void
    ) {
        print("📤 [REPO] Fetching Weekly Summary (using custom)")
        print("📅 [REPO] Week: \(startDate) to \(endDate)")
        fetchCustomSummary(startDate: startDate, endDate: endDate, completion: completion)
    }
    
    // MARK: - Fetch Yearly Summary
    func fetchYearlySummary(
        year: String,
        completion: @escaping (Result<SummaryTransactionData, APIError>) -> Void
    ) {
        let endpoint = CommonEndpoint.summaryTransactionData
        let parameters: [String: Any] = [
            "year": year,
            "type": "yearly"
        ]
        
        print("📤 [REPO] Fetching Yearly Summary")
        print("📍 [REPO] URL: \(endpoint)")
        print("📅 [REPO] Year: \(year)")
        
        let headers = getAuthHeaders()
        
        APIClient.shared.request(
            endpoint,
            method: .post,
            parameters: parameters,
            headers: headers
        ) { (result: Result<SummaryTransactionResponse, APIError>) in
            switch result {
            case .success(let response):
                print("✅ [REPO] Yearly summary fetched successfully")
                completion(.success(response.data))
            case .failure(let error):
                print("❌ [REPO] Failed to fetch yearly summary: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    deinit {
        print("♻️ [REPO] SummaryTransactionRepository deallocated")
    }
}
