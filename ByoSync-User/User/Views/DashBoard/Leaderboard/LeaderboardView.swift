import SwiftUI

struct LeaderboardView: View {
    @StateObject private var viewModel: GetUserRankViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var animateTopThree = false
    @State private var animateList = false
    @State private var selectedFilter: LeaderboardFilter = .transactions
    @State private var hasAppeared = false
    
    enum LeaderboardFilter: String, CaseIterable {
        case transactions = "Transactions"
        case coins = "Coins"
        case wallet = "Wallet"
    }
    
    // MARK: - Initialization with Dependency Injection
    init(
        repository: GetUserRankBoardRepositoryProtocol = GetUserRankBoardRepository(),
        cryptoManager: CryptoManager = CryptoManager()
    ) {
        _viewModel = StateObject(
            wrappedValue: GetUserRankViewModel(
                repository: repository,
                cryptoManager: cryptoManager
            )
        )
        print("🏗️ [VIEW] LeaderboardView initialized")
    }
    
    var body: some View {
        ZStack {
            // Background Gradient
            LinearGradient(
                colors: [
                    Color(hex: "4B548D"),
                    Color(hex: "3D4475")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Navigation Bar
                navigationBar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                
                if viewModel.isLoading && viewModel.users.isEmpty {
                    // Loading State
                    loadingView
                } else if !viewModel.errorMessage.isEmpty && viewModel.users.isEmpty {
                    // Error State
                    errorView
                } else if viewModel.users.isEmpty {
                    // Empty State
                    emptyStateView
                } else {
                    // Main Content
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 24) {
                            // Top 3 Podium
                            if sortedUsers.count >= 3 {
                                topThreePodium
                                    .padding(.horizontal, 20)
                                    .opacity(animateTopThree ? 1 : 0)
                                    .offset(y: animateTopThree ? 0 : 30)
                            } else if sortedUsers.count > 0 {
                                // Show available users even if less than 3
                                partialPodium
                                    .padding(.horizontal, 20)
                                    .opacity(animateTopThree ? 1 : 0)
                                    .offset(y: animateTopThree ? 0 : 30)
                            }
                            
                            // Rest of the Leaderboard
                            leaderboardList
                                .padding(.horizontal, 20)
                                .padding(.bottom, 30)
                                .opacity(animateList ? 1 : 0)
                                .offset(y: animateList ? 0 : 20)
                        }
                    }
                    .refreshable {
                        print("🔄 [VIEW] Refreshed Leaderboard List")
                        await refreshData()
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            print("🏆 [VIEW] ========== LEADERBOARD VIEW APPEARED ==========")
            if !hasAppeared {
                hasAppeared = true
                print("🔄 [VIEW] First appearance - Triggering API call")
                loadData()
            } else {
                print("⚠️ [VIEW] View already appeared before")
            }
        }
        .task {
            // This is another way to ensure the API call happens
            if viewModel.users.isEmpty && !viewModel.isLoading {
                print("📱 [VIEW] Task modifier triggered - Loading data")
                loadData()
            }
        }
    }
    
    // MARK: - Load Data
    private func loadData() {
        print("📡 [VIEW] loadData() called")
        print("📊 [VIEW] Current users count: \(viewModel.users.count)")
        print("⏳ [VIEW] Is loading: \(viewModel.isLoading)")
        
        viewModel.fetchAllUsers()
        
        // Animate elements after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("🎬 [VIEW] Starting animations")
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animateTopThree = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
                animateList = true
            }
        }
    }
    
    // MARK: - Refresh Data
    private func refreshData() async {
        print("🔄 [VIEW] refreshData() called")
        await withCheckedContinuation { continuation in
            viewModel.fetchAllUsers()
            // Give a small delay for the API call to complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                continuation.resume()
            }
        }
    }
    
    // MARK: - Sorted Users
    private var sortedUsers: [UserData] {
        let sorted: [UserData]
        switch selectedFilter {
        case .transactions:
            sorted = viewModel.users.sorted { $0.noOfTransactions > $1.noOfTransactions }
            print("📊 [VIEW] Sorted by transactions: \(sorted.count) users")
        case .coins:
            sorted = viewModel.users.sorted { $0.transactionCoins > $1.transactionCoins }
            print("🪙 [VIEW] Sorted by coins: \(sorted.count) users")
        case .wallet:
            sorted = viewModel.users.sorted { $0.wallet > $1.wallet }
            print("💰 [VIEW] Sorted by wallet: \(sorted.count) users")
        }
        return sorted
    }
    
    // MARK: - Navigation Bar
    private var navigationBar: some View {
        ZStack {
            Spacer()
            
            Text("Leaderboard")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            Spacer()
            
            HStack {
                Button {
                    print("⬅️ [VIEW] Back button tapped")
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                }
                
                Spacer()
                filterSection
            }
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
            
            Text("Loading Rankings...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            
            Text("Fetching latest data")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Error View
    private var errorView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Failed to Load")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            Text(viewModel.errorMessage)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                print("🔄 [VIEW] Retry button tapped")
                viewModel.fetchAllUsers()
            } label: {
                Text("Try Again")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "4B548D"))
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.white)
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 50))
                .foregroundColor(.white.opacity(0.5))
            
            Text("No Rankings Yet")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            Text("Be the first to make transactions!")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
            
            Button {
                print("🔄 [VIEW] Refresh button in empty state tapped")
                viewModel.fetchAllUsers()
            } label: {
                Text("Refresh")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "4B548D"))
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.white)
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Filter Section
    private var filterSection: some View {
        HStack(spacing: 12) {
            Menu {
                ForEach(LeaderboardFilter.allCases, id: \.self) { filter in
                    FilterButton(
                        title: filter.rawValue,
                        isSelected: selectedFilter == filter
                    ) {
                        print("🔄 [VIEW] Filter changed to: \(filter.rawValue)")
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedFilter = filter
                        }
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "list.dash")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Partial Podium (for less than 3 users)
    private var partialPodium: some View {
        VStack(spacing: 20) {
            HStack(alignment: .bottom, spacing: 12) {
                ForEach(Array(sortedUsers.prefix(3).enumerated()), id: \.element.id) { index, user in
                    PodiumCard(
                        user: user,
                        rank: index + 1,
                        height: index == 0 ? 180 : (index == 1 ? 140 : 120),
                        filterType: selectedFilter
                    )
                }
            }
        }
    }
    
    // MARK: - Top Three Podium
    private var topThreePodium: some View {
        VStack(spacing: 20) {
            // Podium Layout
            HStack(alignment: .bottom, spacing: 12) {
                // 2nd Place
                PodiumCard(
                    user: sortedUsers[1],
                    rank: 2,
                    height: 140,
                    filterType: selectedFilter
                )
                .scaleEffect(animateTopThree ? 1 : 0.8)
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.3), value: animateTopThree)
                
                // 1st Place
                PodiumCard(
                    user: sortedUsers[0],
                    rank: 1,
                    height: 180,
                    filterType: selectedFilter
                )
                .scaleEffect(animateTopThree ? 1 : 0.8)
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: animateTopThree)
                
                // 3rd Place
                PodiumCard(
                    user: sortedUsers[2],
                    rank: 3,
                    height: 120,
                    filterType: selectedFilter
                )
                .scaleEffect(animateTopThree ? 1 : 0.8)
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.4), value: animateTopThree)
            }
        }
    }
    
    // MARK: - Leaderboard List
    private var leaderboardList: some View {
        VStack(spacing: 16) {
            // Section Header
            HStack {
                Text("All Rankings")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(sortedUsers.count) users")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // User List
            VStack(spacing: 12) {
                ForEach(Array(sortedUsers.enumerated()), id: \.element.id) { index, user in
                    LeaderboardRowCard(
                        user: user,
                        rank: index + 1,
                        filterType: selectedFilter,
                        isCurrentUser: user.id == UserSession.shared.currentUser?.userId
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                }
            }
        }
    }
}

// MARK: - Filter Button
private struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                }
            }
            .foregroundColor(isSelected ? Color(hex: "4B548D") : .white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected ? Color.white : Color.white.opacity(0.2))
            )
        }
    }
}

// MARK: - Podium Card
private struct PodiumCard: View {
    let user: UserData
    let rank: Int
    let height: CGFloat
    let filterType: LeaderboardView.LeaderboardFilter
    let cryptoManager = CryptoManager()
    
    private var rankColor: Color {
        switch rank {
        case 1: return Color(hex: "FFD700") // Gold
        case 2: return Color(hex: "C0C0C0") // Silver
        case 3: return Color(hex: "CD7F32") // Bronze
        default: return .gray
        }
    }
    
    private var medalIcon: String {
        "medal.fill"
    }
    
    private var statValue: String {
        switch filterType {
        case .transactions:
            return "\(user.noOfTransactions)"
        case .coins:
            return "\(user.transactionCoins)"
        case .wallet:
            return "$\(String(format: "%.0f", user.wallet))"
        }
    }
    
    private var statLabel: String {
        switch filterType {
        case .transactions:
            return "transactions"
        case .coins:
            return "coins"
        case .wallet:
            return "wallet"
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Rank Badge
            ZStack {
                Circle()
                    .fill(rankColor)
                    .frame(width: rank == 1 ? 60 : 50, height: rank == 1 ? 60 : 50)
                    .shadow(color: rankColor.opacity(0.4), radius: 8, x: 0, y: 4)
                
                Image(systemName: medalIcon)
                    .font(.system(size: rank == 1 ? 28 : 24, weight: .bold))
                    .foregroundColor(.white)
            }
            .offset(y: rank == 1 ? -10 : 0)
            
            // Profile Picture
            AsyncImage(url: URL(string: user.profilePic)) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                ZStack {
                    Circle()
                        .fill(rankColor.opacity(0.2))
                    
                    Text(user.initials)
                        .font(.system(size: rank == 1 ? 20 : 18, weight: .bold))
                        .foregroundColor(rankColor)
                }
            }
            .frame(width: rank == 1 ? 70 : 60, height: rank == 1 ? 70 : 60)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(rankColor, lineWidth: 3)
            )
            
            // Name
            Text("\(cryptoManager.decrypt(encryptedData: user.firstName) ?? "nil") \(cryptoManager.decrypt(encryptedData: user.lastName) ?? "nil")")
                .font(.system(size: rank == 1 ? 16 : 14, weight: .bold))
                .foregroundColor(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: rankColor.opacity(0.3), radius: 15, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(rankColor, lineWidth: rank == 1 ? 2.5 : 2)
        )
    }
}

// MARK: - Leaderboard Row Card
private struct LeaderboardRowCard: View {
    let user: UserData
    let rank: Int
    let filterType: LeaderboardView.LeaderboardFilter
    let isCurrentUser: Bool
    let cryptoManager = CryptoManager()
    
    private var statValue: String {
        switch filterType {
        case .transactions:
            return "\(user.noOfTransactions)"
        case .coins:
            return "\(user.transactionCoins)"
        case .wallet:
            return "$\(String(format: "%.2f", user.wallet))"
        }
    }
    
    private var statLabel: String {
        switch filterType {
        case .transactions:
            return "Transactions"
        case .coins:
            return "Coins"
        case .wallet:
            return "Balance"
        }
    }
    
    private var rankColor: Color {
        if rank <= 3 {
            switch rank {
            case 1: return Color(hex: "FFD700")
            case 2: return Color(hex: "C0C0C0")
            case 3: return Color(hex: "CD7F32")
            default: return .gray
            }
        }
        return Color(hex: "4B548D")
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank Number
            ZStack {
                if rank <= 3 {
                    Circle()
                        .fill(rankColor.opacity(0.2))
                        .frame(width: 34, height: 34)
                }
                
                Text("#\(rank)")
                    .font(.system(size: rank <= 3 ? 18 : 16, weight: .bold))
                    .foregroundColor(rank <= 3 ? rankColor : .white)
                    .frame(width: 34)
            }
            
            // Profile Picture
            AsyncImage(url: URL(string: user.profilePic)) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                    
                    Text(user.initials)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(isCurrentUser ? Color.yellow : Color.white.opacity(0.3), lineWidth: isCurrentUser ? 2.5 : 1.5)
            )
            
            // User Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("\(cryptoManager.decrypt(encryptedData: user.firstName) ?? "nil") \(cryptoManager.decrypt(encryptedData: user.lastName) ?? "nil")")
                        .font(.system(size: isCurrentUser ? 8 : 12, weight: .semibold))
                        .foregroundColor(.white)
                    
                    if isCurrentUser {
                        Text("(You)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.yellow)
                    }
                }
                
                HStack(spacing: 0) {
                    Text("\(user.noOfTransactions) sent • \(user.noOfTransactionsReceived) received")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            Spacer()
            
            // Stat Value
            VStack(alignment: .trailing, spacing: 4) {
                Text(statValue)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    isCurrentUser ?
                    LinearGradient(
                        colors: [Color.yellow.opacity(0.3), Color.orange.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ) :
                    LinearGradient(
                        colors: [Color.white.opacity(0.15), Color.white.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(
                            isCurrentUser ? Color.yellow.opacity(0.5) : Color.white.opacity(0.2),
                            lineWidth: isCurrentUser ? 2 : 1
                        )
                )
        )
    }
}

#Preview {
    NavigationStack {
        LeaderboardView()
    }
}
