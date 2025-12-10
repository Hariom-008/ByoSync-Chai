import Foundation
import SwiftUI
import Combine
import UIKit

@MainActor
final class TransactionViewModel: ObservableObject {
    @Published var transactions: [Transaction] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var downloadedFileURL: URL?
    @Published var totalAmount: Double = 0.0

    @AppStorage("transactionCount") var savedTransactionCount: Int = 0
    
    // Dependencies
    private let repository: TransactionRepositoryProtocol
    
    // Computed properties
    var transactionCount: Int {
        transactions.count
    }
    
    var successCount: Int {
        transactions.filter { $0.status.uppercased() == "SUCCESS" }.count
    }
    
    var formattedTotalAmount: String {
        "₹\(String(format: "%.2f", totalAmount))"
    }
    
    // MARK: - Initialization with Dependency Injection
    init(repository: TransactionRepositoryProtocol = TransactionRepository()) {
        self.repository = repository
        print("🏗️ [VM] TransactionViewModel initialized")
    }
    
    // MARK: - Sort Transactions
    /// Returns transactions sorted by createdAt in descending order (newest first)
    func getSortedTransactions() -> [Transaction] {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        
        return transactions.sorted { tx1, tx2 in
            guard let date1 = dateFormatter.date(from: tx1.createdAt),
                  let date2 = dateFormatter.date(from: tx2.createdAt) else {
                return false
            }
            return date1 > date2  // Descending order (newest first)
        }
    }
    
    // MARK: - Fetch Daily Transactions
    func fetchTransactions(for date: Date, reportType: ReportType) {
        print("📡 [VM] fetchTransactions called")
        print("📅 [VM] Date: \(formattedDate(date)), Type: \(reportType.displayName)")
        
        let dateString = formattedDate(date)
        
        switch reportType {
        case .view:
            fetchViewReport(date: dateString, type: "daily")
        }
    }
    
    // MARK: - Fetch Monthly Transactions
    func fetchMonthlyTransactions(month: Int, year: Int, reportType: ReportType) {
        print("📡 [VM] fetchMonthlyTransactions called")
        print("📅 [VM] Month: \(month), Year: \(year), Type: \(reportType.displayName)")
        
        let monthString = String(format: "%02d", month)
        let yearString = String(year)
        
        switch reportType {
        case .view:
            fetchMonthlyViewReport(month: monthString, year: yearString)
        }
    }
    
    // MARK: - Fetch Custom Period Transactions
    func fetchCustomTransactions(startDate: Date, endDate: Date, reportType: ReportType) {
        print("📡 [VM] fetchCustomTransactions called")
        print("📅 [VM] Period: \(formattedDate(startDate)) → \(formattedDate(endDate))")
        
        let startDateString = formattedDate(startDate)
        let endDateString = formattedDate(endDate)
        
        switch reportType {
        case .view:
            fetchCustomViewReport(startDate: startDateString, endDate: endDateString)
        }
    }
    
    // MARK: - Daily Report Methods
    private func fetchViewReport(date: String, type: String) {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        transactions = []
        
        print("⏳ [VM] Loading daily report...")
        
        repository.fetchDailyReport(date: date, type: "VIEW") { [weak self] result in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.isLoading = false
                
                switch result {
                case .success(let data):
                    print("✅ [VM] Daily report loaded: \(data.count) transactions")
                    self.transactions = data
                    self.calculateTotalAmount(from: data)
                    self.savedTransactionCount = data.count
                    self.successMessage = "✓ Loaded \(data.count) transaction\(data.count != 1 ? "s" : "")"
                    self.hideSuccessMessageAfterDelay()
                    
                case .failure(let error):
                    print("❌ [VM] Failed to load daily report: \(error.localizedDescription)")
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func sendEmailReport(date: String, type: String) {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        print("📧 [VM] Sending email report...")
        
        repository.emailDailyReport(date: date) { [weak self] result in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.isLoading = false
                
                switch result {
                case .success(let message):
                    print("✅ [VM] Email sent: \(message)")
                    self.successMessage = "✓ \(message)"
                    self.hideSuccessMessageAfterDelay()
                    
                case .failure(let error):
                    print("❌ [VM] Failed to send email: \(error.localizedDescription)")
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func downloadReport(date: String, type: String) {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        print("📥 [VM] Downloading report...")
        
        repository.downloadDailyReport(date: date) { [weak self] result in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.isLoading = false
                
                switch result {
                case .success(let fileURL):
                    print("✅ [VM] Report downloaded: \(fileURL.path)")
                    self.downloadedFileURL = fileURL
                    self.successMessage = "✓ Report downloaded successfully"
                    self.hideSuccessMessageAfterDelay()
                    
                case .failure(let error):
                    print("❌ [VM] Download failed: \(error.localizedDescription)")
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: - Monthly Report Methods
    private func fetchMonthlyViewReport(month: String, year: String) {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        transactions = []
        
        print("⏳ [VM] Loading monthly report...")
        
        repository.fetchMonthlyReport(month: month, year: year, type: "VIEW") { [weak self] result in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.isLoading = false
                
                switch result {
                case .success(let data):
                    print("✅ [VM] Monthly report loaded: \(data.count) transactions")
                    self.transactions = data
                    self.calculateTotalAmount(from: data)
                    self.savedTransactionCount = data.count
                    self.successMessage = "✓ Loaded \(data.count) transaction\(data.count != 1 ? "s" : "")"
                    self.hideSuccessMessageAfterDelay()
                    
                case .failure(let error):
                    print("❌ [VM] Failed to load monthly report: \(error.localizedDescription)")
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func sendMonthlyEmailReport(month: String, year: String) {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        print("⚠️ [VM] Monthly email not yet implemented")
        
        // TODO: Implement monthly email endpoint when available
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.isLoading = false
            self.successMessage = "✓ Monthly report will be sent to your email"
            self.hideSuccessMessageAfterDelay()
        }
    }
    
    private func downloadMonthlyReport(month: String, year: String) {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        print("⚠️ [VM] Monthly download not yet implemented")
        
        // TODO: Implement monthly download endpoint when available
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.isLoading = false
            self.errorMessage = "Monthly download not yet implemented"
        }
    }
    
    // MARK: - Custom Period Report Methods
    private func fetchCustomViewReport(startDate: String, endDate: String) {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        transactions = []
        
        print("⏳ [VM] Loading custom report...")
        
        repository.fetchCustomReport(startDate: startDate, endDate: endDate, type: "VIEW") { [weak self] result in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.isLoading = false
                
                switch result {
                case .success(let data):
                    print("✅ [VM] Custom report loaded: \(data.count) transactions")
                    self.transactions = data
                    self.calculateTotalAmount(from: data)
                    self.savedTransactionCount = data.count
                    self.successMessage = "✓ Loaded \(data.count) transaction\(data.count != 1 ? "s" : "")"
                    self.hideSuccessMessageAfterDelay()
                    
                case .failure(let error):
                    print("❌ [VM] Failed to load custom report: \(error.localizedDescription)")
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func sendCustomEmailReport(startDate: String, endDate: String) {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        print("⚠️ [VM] Custom email not yet implemented")
        
        // TODO: Implement custom email endpoint when available
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.isLoading = false
            self.successMessage = "✓ Custom report will be sent to your email"
            self.hideSuccessMessageAfterDelay()
        }
    }
    
    private func downloadCustomReport(startDate: String, endDate: String) {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        print("⚠️ [VM] Custom download not yet implemented")
        
        // TODO: Implement custom download endpoint when available
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.isLoading = false
            self.errorMessage = "Custom download not yet implemented"
        }
    }
    
    // MARK: - Calculate Total Amount
    /// Calculates total amount from all transactions
    private func calculateTotalAmount(from transactions: [Transaction]) {
        let total = transactions.reduce(0.0) { $0 + Double($1.coins ?? 0) }
        totalAmount = total
        
        print("📊 [VM] Amount Calculation:")
        print("   Total Amount: ₹\(String(format: "%.2f", total))")
        print("   Number of transactions: \(transactions.count)")
    }

    // MARK: - Share Downloaded File
    func shareFile(url: URL) {
        print("📤 [VM] Sharing file: \(url.path)")
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            print("⚠️ [VM] Could not find root view controller")
            return
        }
        
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = rootViewController.view
            popover.sourceRect = CGRect(
                x: rootViewController.view.bounds.midX,
                y: rootViewController.view.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }
        
        rootViewController.present(activityVC, animated: true)
    }
    
    // MARK: - Helpers
    private func hideSuccessMessageAfterDelay(delay: TimeInterval = 3.0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            withAnimation {
                self?.successMessage = nil
            }
        }
    }
    
    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    func formattedDateDisplay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, yyyy"
        return formatter.string(from: date)
    }
    
    deinit {
        print("♻️ [VM] TransactionViewModel deallocated")
    }
}
