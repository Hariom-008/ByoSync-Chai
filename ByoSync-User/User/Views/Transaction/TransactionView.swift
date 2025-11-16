import SwiftUI

struct TransactionView: View {
    @StateObject private var viewModel: TransactionViewModel
    @State private var selectedPeriodType: PeriodType = .daily
    @State private var selectedReportType: ReportType = .view
    @State private var selectedDate: Date = Date()
    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var customStartDate: Date = Date()
    @State private var customEndDate: Date = Date()
    @Binding var hideTabBar: Bool
    @Environment(\.dismiss) var dismiss
    
    // MARK: - Initialization with Dependency Injection
    init(
        hideTabBar: Binding<Bool>,
        repository: TransactionRepositoryProtocol = TransactionRepository()
    ) {
        self._hideTabBar = hideTabBar
        _viewModel = StateObject(
            wrappedValue: TransactionViewModel(repository: repository)
        )
        print("🏗️ [VIEW] TransactionView initialized")
    }
    
    var body: some View {
        ZStack {
            // Background
            Color(hex: "F8F9FD")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: - Main Content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Filter Section
                        filterSection
                            .padding(.horizontal, 20)
                            .padding(.top, 24)
                        
                        // Stats Cards
                        statsSection
                            .padding(.horizontal, 20)
                        
                        // Success Message
                        if let successMessage = viewModel.successMessage {
                            successBanner(message: successMessage)
                                .padding(.horizontal, 20)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        
                        // Content Area
                        contentSection
                            .padding(.horizontal, 20)
                            .padding(.bottom, 24)
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    print("🔙 [VIEW] Back button tapped")
                    dismiss()
                    hideTabBar.toggle()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                }
            }
            
            ToolbarItem(placement: .principal) {
                Text("Transactions")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
            }
        }
        .onAppear {
            print("📱 [VIEW] TransactionView appeared")
            fetchInitialData()
        }
        .onDisappear {
            print("👋 [VIEW] TransactionView disappeared")
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.isLoading)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.transactions.count)
        .animation(.easeInOut(duration: 0.3), value: viewModel.successMessage)
        .onChange(of: viewModel.downloadedFileURL) { oldValue, newValue in
            if let url = newValue {
                print("📁 [VIEW] File downloaded, initiating share")
                viewModel.shareFile(url: url)
            }
        }
    }
    
    // MARK: - Filter Section
    private var filterSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Period Type Selector
                periodTypeSelector
                
                // Report Type Selector
                reportTypeSelector
            }
            
            // Date Selector
            dateSelector
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
    }
    
    private var periodTypeSelector: some View {
        Menu {
            ForEach(PeriodType.allCases, id: \.self) { type in
                Button {
                    print("📅 [VIEW] Period type changed to: \(type.displayName)")
                    withAnimation(.spring(response: 0.3)) {
                        selectedPeriodType = type
                    }
                } label: {
                    Label(type.displayName, systemImage: type.iconName)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: selectedPeriodType.iconName)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "4B548D"))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Period")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(selectedPeriodType.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color(hex: "F5F7FA"))
            .cornerRadius(12)
        }
    }
    
    private var reportTypeSelector: some View {
        Menu {
            ForEach(ReportType.allCases, id: \.self) { type in
                Button {
                    print("📊 [VIEW] Report type changed to: \(type.displayName)")
                    withAnimation(.spring(response: 0.3)) {
                        selectedReportType = type
                    }
                } label: {
                    Label(type.displayName, systemImage: type.iconName)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: selectedReportType.iconName)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "4B548D"))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Type")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(selectedReportType.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color(hex: "F5F7FA"))
            .cornerRadius(12)
        }
    }
    
    @ViewBuilder
    private var dateSelector: some View {
        VStack(spacing: 12) {
            switch selectedPeriodType {
            case .daily:
                DatePicker(
                    "Select Date",
                    selection: $selectedDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(Color(hex: "4B548D"))
                
            case .monthly:
                HStack(spacing: 12) {
                    Menu {
                        Picker("Month", selection: $selectedMonth) {
                            ForEach(1...12, id: \.self) { month in
                                Text(monthName(month)).tag(month)
                            }
                        }
                    } label: {
                        HStack {
                            Text(monthName(selectedMonth))
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .foregroundColor(.primary)
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(Color(hex: "F5F7FA"))
                        .cornerRadius(12)
                    }
                    
                    Menu {
                        Picker("Year", selection: $selectedYear) {
                            ForEach(2020...Calendar.current.component(.year, from: Date()), id: \.self) { year in
                                Text(String(year)).tag(year)
                            }
                        }
                    } label: {
                        HStack {
                            Text(String(selectedYear))
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .foregroundColor(.primary)
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(Color(hex: "F5F7FA"))
                        .cornerRadius(12)
                    }
                }
                
            case .custom:
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("From")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            DatePicker(
                                "",
                                selection: $customStartDate,
                                in: ...Date(),
                                displayedComponents: .date
                            )
                            .datePickerStyle(.compact)
                            .labelsHidden()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(Color(hex: "F5F7FA"))
                        .cornerRadius(12)
                        
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("To")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            DatePicker(
                                "",
                                selection: $customEndDate,
                                in: customStartDate...Date(),
                                displayedComponents: .date
                            )
                            .datePickerStyle(.compact)
                            .labelsHidden()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(Color(hex: "F5F7FA"))
                        .cornerRadius(12)
                    }
                }
            }
            
            // Fetch Button
            Button(action: {
                print("🔍 [VIEW] Fetch button tapped")
                fetchData()
            }) {
                HStack(spacing: 8) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)
                    } else {
                        Image(systemName: selectedReportType == .view ? "eye.fill" : "arrow.down.circle.fill")
                            .font(.system(size: 14))
                    }
                    Text(viewModel.isLoading ? "Loading..." : selectedReportType.buttonText)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "4B548D"), Color(hex: "5E6BA8")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: Color(hex: "4B548D").opacity(0.3), radius: 8, y: 4)
            }
            .disabled(viewModel.isLoading)
        }
    }
    
    // MARK: - Stats Section
    private var statsSection: some View {
        HStack(spacing: 12) {
            StatCard(
                icon: "doc.text.fill",
                iconColor: Color(hex: "4B548D"),
                title: "Total",
                value: "\(viewModel.transactionCount)",
                subtitle: viewModel.transactionCount == 1 ? "transaction" : "transactions"
            )
            
            StatCard(
                icon: "indianrupeesign.circle.fill",
                iconColor: Color(hex: "5E6BA8"),
                title: "Amount",
                value: "\(String(format: "%.0f", viewModel.totalAmount))",
                subtitle: "total spent"
            )
        }
    }
    
    // MARK: - Success Banner
    private func successBanner(message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.green)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.green)
            
            Spacer()
        }
        .padding(16)
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Content Section
    @ViewBuilder
    private var contentSection: some View {
        if viewModel.isLoading {
            loadingView
        } else if let errorMessage = viewModel.errorMessage {
            errorView(message: errorMessage)
        } else if viewModel.transactions.isEmpty && selectedReportType == .view {
            emptyStateView
        } else if selectedReportType == .view {
            transactionListView
        } else {
            reportInfoView
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(Color(hex: "4B548D"))
            
            Text("Loading transactions...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 300)
        .background(Color.white)
        .cornerRadius(16)
    }
    
    // MARK: - Error View
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 56))
                .foregroundColor(.orange)
            
            Text("Something went wrong")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            
            Button(action: {
                print("🔄 [VIEW] Try again button tapped")
                fetchData()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color(hex: "4B548D"))
                .cornerRadius(10)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color.white)
        .cornerRadius(16)
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray.fill")
                .font(.system(size: 64))
                .foregroundColor(Color(hex: "4B548D").opacity(0.3))
            
            Text("No Transactions Found")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("No transactions were found for \(periodDisplayText)")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color.white)
        .cornerRadius(16)
    }
    
    // MARK: - Transaction List View
    private var transactionListView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("\(viewModel.transactionCount) \(viewModel.transactionCount == 1 ? "Transaction" : "Transactions")")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(periodDisplayText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(hex: "F5F7FA"))
                    .cornerRadius(8)
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(16, corners: [.topLeft, .topRight])
            
            // Transactions
            LazyVStack(spacing: 12) {
                ForEach(viewModel.getSortedTransactions()) { transaction in
                    TransactionRow(transaction: transaction)
                }
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(16, corners: [.bottomLeft, .bottomRight])
        }
    }
    
    // MARK: - Report Info View
    private var reportInfoView: some View {
        VStack(spacing: 24) {
            Image(systemName: "arrow.down.doc.fill")
                .font(.system(size: 64))
                .foregroundColor(Color(hex: "4B548D").opacity(0.3))
            
            VStack(spacing: 8) {
                Text("Report Ready")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Click '\(selectedReportType.buttonText)' to proceed")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color.white)
        .cornerRadius(16)
    }
    
    // MARK: - Helper Methods
    private func fetchInitialData() {
        print("🔄 [VIEW] Fetching initial data")
        fetchData()
    }
    
    private func fetchData() {
        switch selectedPeriodType {
        case .daily:
            viewModel.fetchTransactions(for: selectedDate, reportType: selectedReportType)
        case .monthly:
            viewModel.fetchMonthlyTransactions(
                month: selectedMonth,
                year: selectedYear,
                reportType: selectedReportType
            )
        case .custom:
            viewModel.fetchCustomTransactions(
                startDate: customStartDate,
                endDate: customEndDate,
                reportType: selectedReportType
            )
        }
    }
    
    private var periodDisplayText: String {
        switch selectedPeriodType {
        case .daily:
            return viewModel.formattedDateDisplay(selectedDate)
        case .monthly:
            return "\(monthName(selectedMonth)) \(selectedYear)"
        case .custom:
            return "\(viewModel.formattedDateDisplay(customStartDate)) - \(viewModel.formattedDateDisplay(customEndDate))"
        }
    }
    
    private func monthName(_ month: Int) -> String {
        let formatter = DateFormatter()
        formatter.monthSymbols = Calendar.current.monthSymbols
        return formatter.monthSymbols[month - 1]
    }
}

#Preview {
    NavigationStack {
        TransactionView(hideTabBar: .constant(false))
    }
}
