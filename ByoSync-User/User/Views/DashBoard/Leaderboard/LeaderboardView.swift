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
        case paidAmount = "Paid Amount"
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
            // Clean White Background
            Color.white
                .ignoresSafeArea()
            
            // Subtle background pattern
            GeometryReader { geometry in
                ForEach(0..<6, id: \.self) { index in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(hex: "4B548D").opacity(0.03),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 50,
                                endRadius: 150
                            )
                        )
                        .frame(width: 200, height: 200)
                        .position(
                            x: CGFloat.random(in: 0...geometry.size.width),
                            y: CGFloat.random(in: 0...geometry.size.height)
                        )
                        .blur(radius: 20)
                }
            }
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Navigation Bar
                navigationBar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                
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
                        VStack(spacing: 28) {
                            // Filter Pills
                            filterPillsSection
                                .padding(.horizontal, 20)
                                .padding(.top, 8)
                            
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
        case .paidAmount:
            sorted = viewModel.users.sorted { $0.transactionCoins > $1.transactionCoins }
            print("🪙 [VIEW] Sorted by coins: \(sorted.count) users")
        }
        return sorted
    }
    
    // MARK: - Navigation Bar
    private var navigationBar: some View {
        HStack(spacing: 16) {
            Button {
                print("⬅️ [VIEW] Back button tapped")
                dismiss()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color(hex: "F5F6FA"))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "4B548D"))
                }
            }
            
            Spacer()
            
            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "FFD700"), Color(hex: "FFA500")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("Leaderboard")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color(hex: "1A1F36"))
                }
                
                Text("Top performers")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "6B7280"))
            }
            
            Spacer()
            
            // Balance spacer
            Color.clear.frame(width: 44, height: 44)
        }
    }
    
    // MARK: - Filter Pills Section
    private var filterPillsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(LeaderboardFilter.allCases, id: \.self) { filter in
                    FilterPill(
                        title: filter.rawValue,
                        icon: filterIcon(for: filter),
                        isSelected: selectedFilter == filter
                    ) {
                        print("🔄 [VIEW] Filter changed to: \(filter.rawValue)")
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedFilter = filter
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    private func filterIcon(for filter: LeaderboardFilter) -> String {
        switch filter {
        case .transactions: return "arrow.left.arrow.right"
        case .paidAmount: return "bitcoinsign.circle.fill"
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .stroke(Color(hex: "E5E7F0"), lineWidth: 4)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(
                            colors: [Color(hex: "4B548D"), Color(hex: "6B74A8")],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: UUID())
            }
            
            VStack(spacing: 8) {
                Text("Loading Rankings...")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(hex: "1A1F36"))
                
                Text("Fetching latest data")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "6B7280"))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Error View
    private var errorView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color(hex: "FEE2E2"))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "EF4444"), Color(hex: "DC2626")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 8) {
                Text("Failed to Load")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color(hex: "1A1F36"))
                
                Text(viewModel.errorMessage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "6B7280"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button {
                print("🔄 [VIEW] Retry button tapped")
                viewModel.fetchAllUsers()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text("Try Again")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "4B548D"), Color(hex: "6B74A8")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: Color(hex: "4B548D").opacity(0.3), radius: 12, x: 0, y: 6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color(hex: "F5F6FA"))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "person.3.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "4B548D"), Color(hex: "6B74A8")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 8) {
                Text("No Rankings Yet")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color(hex: "1A1F36"))
                
                Text("Be the first to make transactions!")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "6B7280"))
            }
            
            Button {
                print("🔄 [VIEW] Refresh button in empty state tapped")
                viewModel.fetchAllUsers()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text("Refresh")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "4B548D"), Color(hex: "6B74A8")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: Color(hex: "4B548D").opacity(0.3), radius: 12, x: 0, y: 6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Partial Podium (for less than 3 users)
    private var partialPodium: some View {
        VStack(spacing: 20) {
            HStack(alignment: .bottom, spacing: 12) {
                ForEach(Array(sortedUsers.prefix(3).enumerated()), id: \.element.id) { index, user in
                    PodiumCard(
                        user: user,
                        rank: index + 1,
                        height: index == 0 ? 200 : (index == 1 ? 160 : 140),
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
                    height: 240,
                    filterType: selectedFilter
                )
                .scaleEffect(animateTopThree ? 1 : 0.8)
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.3), value: animateTopThree)
                
                // 1st Place
                PodiumCard(
                    user: sortedUsers[0],
                    rank: 1,
                    height: 300,
                    filterType: selectedFilter
                )
                .scaleEffect(animateTopThree ? 1 : 0.8)
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: animateTopThree)
                
                // 3rd Place
                PodiumCard(
                    user: sortedUsers[2],
                    rank: 3,
                    height: 240,
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
                HStack(spacing: 8) {
                    Image(systemName: "list.bullet.rectangle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "4B548D"))
                    
                    Text("All Rankings")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(hex: "1A1F36"))
                }
                
                Spacer()
                
                Text("\(sortedUsers.count) users")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "6B7280"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color(hex: "F5F6FA"))
                    )
            }
            .padding(.top, 8)
            
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

// MARK: - Filter Pill
private struct FilterPill: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(isSelected ? .white : Color(hex: "4B548D"))
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                Group {
                    if isSelected {
                        LinearGradient(
                            colors: [Color(hex: "4B548D"), Color(hex: "6B74A8")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    } else {
                        LinearGradient(
                            colors: [Color(hex: "F5F6FA"), Color(hex: "F5F6FA")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }
                }
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(
                        isSelected ? Color.clear : Color(hex: "E5E7F0"),
                        lineWidth: 1.5
                    )
            )
            .shadow(
                color: isSelected ? Color(hex: "4B548D").opacity(0.3) : Color.clear,
                radius: isSelected ? 8 : 0,
                x: 0,
                y: isSelected ? 4 : 0
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
        default: return Color(hex: "9CA3AF")
        }
    }
    
    private var rankGradient: LinearGradient {
        switch rank {
        case 1:
            return LinearGradient(
                colors: [Color(hex: "FFD700"), Color(hex: "FFA500")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case 2:
            return LinearGradient(
                colors: [Color(hex: "E8E8E8"), Color(hex: "C0C0C0")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case 3:
            return LinearGradient(
                colors: [Color(hex: "CD7F32"), Color(hex: "B8733C")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            return LinearGradient(
                colors: [Color(hex: "9CA3AF"), Color(hex: "6B7280")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var medalIcon: String {
        "medal.fill"
    }
    
    private var statValue: String {
        switch filterType {
        case .transactions:
            return "\(user.noOfTransactions)"
        case .paidAmount:
            return "\(user.transactionCoins)"
        }
    }
    
    private var statLabel: String {
        switch filterType {
        case .transactions:
            return "Transactions"
        case .paidAmount:
            return "Paid Amount"
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Crown for 1st place
            if rank == 1 {
                Image(systemName: "crown.fill")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(rankGradient)
                    .shadow(color: rankColor.opacity(0.5), radius: 8, x: 0, y: 4)
            }
            
            VStack(spacing: 14) {
                // Rank Badge
                ZStack {
                    Circle()
                        .fill(rankGradient)
                        .frame(width: rank == 1 ? 68 : 56, height: rank == 1 ? 68 : 56)
                        .shadow(color: rankColor.opacity(0.5), radius: 12, x: 0, y: 6)
                    
                    Circle()
                        .fill(.white)
                        .frame(width: rank == 1 ? 60 : 50, height: rank == 1 ? 60 : 50)
                    
                    Text("\(rank)")
                        .font(.system(size: rank == 1 ? 28 : 24, weight: .black))
                        .foregroundStyle(rankGradient)
                }
                .offset(y: rank == 1 ? -16 : -8)
                
                // Profile Picture
                AsyncImage(url: URL(string: user.profilePic)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        rankColor.opacity(0.2),
                                        rankColor.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text(user.initials)
                            .font(.system(size: rank == 1 ? 24 : 20, weight: .bold))
                            .foregroundStyle(rankGradient)
                    }
                }
                .frame(width: rank == 1 ? 80 : 68, height: rank == 1 ? 80 : 68)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(rankGradient, lineWidth: 3.5)
                )
                .shadow(color: rankColor.opacity(0.3), radius: 10, x: 0, y: 5)
                
                // Name
                VStack(spacing: 4) {
                    Text("\(cryptoManager.decrypt(encryptedData: user.firstName) ?? "nil") \(cryptoManager.decrypt(encryptedData: user.lastName) ?? "nil")")
                        .font(.system(size: rank == 1 ? 16 : 14, weight: .bold))
                        .foregroundColor(Color(hex: "1A1F36"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    
                    // Stat Display
                    VStack(spacing: 2) {
                        Text(statValue)
                            .font(.system(size: rank == 1 ? 20 : 18, weight: .black))
                            .foregroundStyle(rankGradient)
                        
                        Text(statLabel)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(hex: "6B7280"))
                            .textCase(.uppercase)
                            .tracking(0.5)
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 8)
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .padding(.vertical, 20)
            .padding(.horizontal, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(rankGradient.opacity(0.4))
                .shadow(color: rankColor.opacity(0.25), radius: 16, x: 0, y: 8)
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
        case .paidAmount:
            return "\(user.transactionCoins)"
        }
    }
    
    private var statLabel: String {
        switch filterType {
        case .transactions:
            return "Transactions"
        case .paidAmount:
            return "Paid Amount"
        }
    }
    
    private var rankColor: Color {
        if rank <= 3 {
            switch rank {
            case 1: return Color(hex: "FFD700")
            case 2: return Color(hex: "C0C0C0")
            case 3: return Color(hex: "CD7F32")
            default: return Color(hex: "9CA3AF")
            }
        }
        return Color(hex: "6B7280")
    }
    
    private var rankGradient: LinearGradient {
        if rank <= 3 {
            switch rank {
            case 1:
                return LinearGradient(
                    colors: [Color(hex: "FFD700"), Color(hex: "FFA500")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            case 2:
                return LinearGradient(
                    colors: [Color(hex: "E8E8E8"), Color(hex: "C0C0C0")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            case 3:
                return LinearGradient(
                    colors: [Color(hex: "CD7F32"), Color(hex: "B8733C")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            default:
                return LinearGradient(
                    colors: [Color(hex: "9CA3AF"), Color(hex: "6B7280")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        }
        return LinearGradient(
            colors: [Color(hex: "6B7280"), Color(hex: "6B7280")],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank Number
                Text("#\(rank)")
                    .font(.system(size: rank <= 3 ? 16 : 14, weight: .bold))
                    .foregroundStyle(rank <= 3 ? rankColor : Color.black)
                    .frame(width: 40)
            
            // Profile Picture
            AsyncImage(url: URL(string: user.profilePic)) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                ZStack {
                    Circle()
                        .fill(Color(hex: "F5F6FA"))
                    
                    Text(user.initials)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(hex: "4B548D"))
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(
                        isCurrentUser ?
                        LinearGradient(
                            colors: [Color(hex: "FFD700"), Color(hex: "FFA500")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [Color(hex: "E5E7F0")],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: isCurrentUser ? 3 : 2
                    )
            )
            .shadow(
                color: isCurrentUser ? Color(hex: "FFD700").opacity(0.3) : Color.clear,
                radius: isCurrentUser ? 6 : 0,
                x: 0,
                y: isCurrentUser ? 3 : 0
            )
            
            // User Info
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text("\(cryptoManager.decrypt(encryptedData: user.firstName) ?? "nil") \(cryptoManager.decrypt(encryptedData: user.lastName) ?? "nil")")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color(hex: "1A1F36"))
                    
                    if isCurrentUser {
                        Text("You")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "FFD700"), Color(hex: "FFA500")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                    }
                }
                
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color(hex: "10B981"))
                        
                        Text("\(user.noOfTransactions)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: "6B7280"))
                    }
                    
                    Circle()
                        .fill(Color(hex: "D1D5DB"))
                        .frame(width: 3, height: 3)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color(hex: "3B82F6"))
                        
                        Text("\(user.noOfTransactionsReceived)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: "6B7280"))
                    }
                }
            }
            
            Spacer()
            
            // Stat Value
            VStack(alignment: .trailing, spacing: 4) {
                Text(statValue)
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(Color(hex: "1A1F36"))
                
                Text(statLabel)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(hex: "9CA3AF"))
                    .textCase(.uppercase)
                    .tracking(0.3)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    isCurrentUser ?
                    LinearGradient(
                        colors: [
                            Color(hex: "FFF7E6"),
                            Color(hex: "FFE8B8")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ) :
                    LinearGradient(
                        colors: [.white, .white],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(
                    color: isCurrentUser ? Color(hex: "FFD700").opacity(0.2) : Color(hex: "4B548D").opacity(0.08),
                    radius: isCurrentUser ? 12 : 8,
                    x: 0,
                    y: isCurrentUser ? 6 : 4
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    isCurrentUser ?
                    LinearGradient(
                        colors: [Color(hex: "FFD700").opacity(0.5), Color(hex: "FFA500").opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ) :
                    LinearGradient(
                        colors: [Color(hex: "E5E7F0")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isCurrentUser ? 2 : 1.5
                )
        )
    }
}

#Preview {
    NavigationStack {
        LeaderboardView()
    }
}
