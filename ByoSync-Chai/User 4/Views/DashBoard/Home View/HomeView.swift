import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @StateObject private var leaderboardViewModel = GetUserRankViewModel()
    @State var paytoPerson: String = ""
    @State var openProfileView: Bool = false
    @State var openWalletView: Bool = false
    @State var openLeaderboardView: Bool = false
    @State var openTransactionView: Bool = false
    @Binding var hideTabBar: Bool
    @State var profilePic: URL?
    @AppStorage("creditAvailable") private var creditAvailable: Double = 0.0
    
    // Animation states
    @State private var isAnimating = false
    @State private var promotionOffset: CGFloat = 0

    // Top 3 users computed property
    private var top3Users: [UserData] {
        let sorted = leaderboardViewModel.users.sorted { $0.noOfTransactions > $1.noOfTransactions }
        return Array(sorted.prefix(3))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Enhanced Background with subtle animation
                LinearGradient(
                    colors: [
                        Color(hex: "4B548D"),
                        Color(hex: "3D4475"),
                        Color(hex: "2F3560")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .overlay(
                    GeometryReader { geometry in
                        Circle()
                            .fill(Color.white.opacity(0.05))
                            .frame(width: 300, height: 300)
                            .blur(radius: 50)
                            .offset(x: -100, y: -100)
                        
                        Circle()
                            .fill(Color.white.opacity(0.03))
                            .frame(width: 250, height: 250)
                            .blur(radius: 40)
                            .offset(x: geometry.size.width - 100, y: geometry.size.height - 400)
                    }
                )

                VStack(spacing: 0) {
                    // Header with profile
                    headerSection
                        .padding(.top, 8)
                        .padding(.bottom, 16)

                    // Credit and Wallet Cards
                    availableCreditAndWallet
                        .padding(.bottom, 20)

                    // Main Content
                    payFeaturesSection
                }
            }
            .navigationDestination(isPresented: $openProfileView) {
                ProfileView()
            }
            .navigationDestination(isPresented: $openWalletView) {
                WalletView()
            }
            .navigationDestination(isPresented: $openLeaderboardView) {
                LeaderboardView()
            }
            .navigationDestination(isPresented: $openTransactionView) {
                TransactionView(hideTabBar: $hideTabBar)
            }
        }
        .onAppear {
            print("🏠 HomeView appeared")
            loadProfilePicture()
            loadLeaderboardData()
            hideTabBar = false
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
        .environment(\.locale, .init(identifier: languageManager.currentLanguageCode))
    }

    private func loadProfilePicture() {
        if let url = URL(string: UserSession.shared.userProfilePicture),
           !UserSession.shared.userProfilePicture.isEmpty {
            profilePic = url
            print("✅ Profile picture loaded: \(UserSession.shared.userProfilePicture)")
        } else {
            profilePic = nil
            print("⚠️ No valid profile picture URL found on HOME")
        }
    }
    
    private func loadLeaderboardData() {
        print("📊 Loading leaderboard data for home preview")
        leaderboardViewModel.fetchAllUsers()
    }

    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                Text((UserSession.shared.currentUser == nil ? "User" : UserSession.shared.currentUser?.firstName) ?? "Nil")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            Button {
               // openSocketClientTestView.toggle()
                
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "bell.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                    
                    // Notification badge
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                        .offset(x: 12, y: -12)
                }
            }
            
            Button {
                print("👤 Profile button tapped")
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    openProfileView.toggle()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                    
                    if let profilePic = profilePic {
                        AsyncImage(url: profilePic) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Image(systemName: "person.fill")
                                .foregroundColor(.white)
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                    }
                }
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                        .frame(width: 44, height: 44)
                )
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Credit + Wallet (Enhanced)
    private var availableCreditAndWallet: some View {
        HStack(spacing: 14) {
            // Wallet Button
            Button {
                print("💰 Wallet button tapped")
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    openWalletView.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.25))
                            .frame(width: 50, height: 50)
                        
                        if #available(iOS 18.0, *) {
                            Image(systemName: "wallet.bifold.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(.white)
                        } else {
                            Image(systemName: "creditcard.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(.white)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("my_wallet"))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Spacer()
                }
                .padding(18)
                .frame(maxWidth: .infinity)
                .frame(height: 130)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.15),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.4), Color.white.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                )
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Main Features Section
    private var payFeaturesSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32)
                .fill(Color.white)
                .ignoresSafeArea(edges: .bottom)
                .shadow(color: Color.black.opacity(0.08), radius: 25, x: 0, y: -8)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // Transaction History Button
                    transactionHistoryButton
                        .padding(.horizontal, 20)
                    
                    // Leaderboard Card
                    leaderboardCard
                        .padding(.horizontal, 20)
                    
                    // Promotions
//                    promotionsSection
//                        .padding(.horizontal, 20)
//                        .padding(.bottom, 50)

                }
                .padding(.top,32)
                .padding(.bottom,56)
            }
        }
    }
    
    // MARK: - Leaderboard Card (Enhanced with Real Data)
    private var leaderboardCard: some View {
        Button {
            print("🏆 Leaderboard card tapped")
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                openLeaderboardView.toggle()
            }
        } label: {
            VStack(spacing: 18) {
                HStack {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.yellow.opacity(0.3), Color.orange.opacity(0.3)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 48, height: 48)
                            
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.yellow, Color.orange],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Leaderboard")
                                .font(.system(size: 19, weight: .bold))
                                .foregroundColor(.black)
                            Text("Tap to expand")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.gray.opacity(0.6))
                        }
                    }
                    
                    Spacer()
                }
                
                Divider()
                
                // Top 3 Preview with Real Data
                if leaderboardViewModel.isLoading {
                    // Loading State
                    HStack(spacing: 14) {
                        ForEach(0..<3) { index in
                            VStack(spacing: 10) {
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 48, height: 48)
                                
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 60, height: 30)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .shimmer()
                } else if top3Users.count >= 3 {
                    // Display actual top 3 users
                    VStack(spacing: 12) {
                        HStack(spacing: 14) {
                            // 2nd Place
                            LeaderboardPreviewItem(
                                rank: "2",
                                name: top3Users[1].firstName,
                                score: "\(top3Users[1].noOfTransactions)",
                                rankColor: Color(hex: "C0C0C0"),
                                isHighlighted: top3Users[1].id == UserSession.shared.currentUser?.userId,
                                isFirstRank: false
                            )
                            
                            // 1st Place
                            LeaderboardPreviewItem(
                                rank: "1",
                                name: top3Users[0].id == UserSession.shared.currentUser?.userId ? "You" : top3Users[0].firstName,
                                score: "\(top3Users[0].noOfTransactions)",
                                rankColor: Color.orange,
                                isHighlighted: false,
                                isFirstRank: true
                            )
                            
                            // 3rd Place
                            LeaderboardPreviewItem(
                                rank: "3",
                                name: top3Users[2].firstName,
                                score: "\(top3Users[2].noOfTransactions)",
                                rankColor: Color(hex: "CD7F32"),
                                isHighlighted: top3Users[2].id == UserSession.shared.currentUser?.userId,
                                isFirstRank: false
                            )
                        }
                        
                        // Show current user's rank if not in top 3
                        if let currentUser = UserSession.shared.currentUser,
                           !top3Users.contains(where: { $0.id == currentUser.userId }) {
                            currentUserRankView
                        }
                    }
                } else if !top3Users.isEmpty {
                    // Display available users (less than 3)
                    HStack(spacing: 14) {
                        ForEach(Array(top3Users.enumerated()), id: \.element.id) { index, user in
                            LeaderboardPreviewItem(
                                rank: "\(index + 1)",
                                name: user.id == UserSession.shared.currentUser?.userId ? "You" : user.firstName,
                                score: "\(user.noOfTransactions)",
                                rankColor: getRankColor(for: index + 1),
                                isHighlighted: index == 0
                            )
                        }
                    }
                } else {
                   Text("Sadly! No data in Leaderboard")
                        .foregroundStyle(.black)
                }
            }
            .padding(22)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(
                                LinearGradient(
                                    colors: [Color.yellow.opacity(0.1), Color.orange.opacity(0.5)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .shadow(color: Color.yellow.opacity(0.15), radius: 15, x: 0, y: 8)
            )
        }
    }

    // MARK: - Current User Rank View (When not in Top 3)
    private var currentUserRankView: some View {
        VStack(spacing: 8) {
            Divider()
                .padding(.vertical, 4)
            
            if let currentUser = UserSession.shared.currentUser,
               let userIndex = leaderboardViewModel.users.firstIndex(where: { $0.id == currentUser.userId }),
               let userData = leaderboardViewModel.users.first(where: { $0.id == currentUser.userId }) {
                
                HStack(spacing: 12) {
                    // Rank Badge
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "4B548D").opacity(0.2), Color(hex: "4B548D").opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 40)
                        
                        Text("#\(userIndex + 1)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color(hex: "4B548D"))
                    }
                    
                    // User Info
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Your Rank")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.black)
                        
                        Text("\(userData.noOfTransactions) transactions")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    // Arrow to indicate it's tappable
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gray.opacity(0.5))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: "4B548D").opacity(0.05))
                )
            }
        }
    }
    
    // Helper function to get rank colors
    private func getRankColor(for rank: Int) -> Color {
        switch rank {
        case 1: return Color.orange // Gold
        case 2: return Color(hex: "C0C0C0") // Silver
        case 3: return Color(hex: "CD7F32") // Bronze
        default: return Color.gray
        }
    }
    
    // MARK: - Transaction History Button (Enhanced)
    private var transactionHistoryButton: some View {
        Button {
            print("📊 Transaction history tapped")
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                openTransactionView.toggle()
                hideTabBar.toggle()
            }
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "4B548D").opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "4B548D")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Transaction History")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                    
                    Text("View all transactions")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex:"4B548D").opacity(0.05),
                                Color(hex:"4B548D").opacity(0.1),
                                Color(hex:"4B548D").opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.4), Color.white.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
            )
        }
    }
    
    // MARK: - Promotions Section (Enhanced)
    private var promotionsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Spacer()
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 6, height: 6)
                    
                    Text("Limited Time")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(Color.orange.opacity(0.12))
                )
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    PromotionCard(
                        promotionTitle: "Weekend Offers",
                        promotionDescription: "Pay to new users and earn exclusive discounts",
                        icon: "gift.fill",
                        iconColor: Color.orange,
                        accentColor: Color.orange
                    )
                    
                    PromotionCard(
                        promotionTitle: "Transaction Bonus",
                        promotionDescription: "Complete more transactions to unlock rewards",
                        icon: "chart.line.uptrend.xyaxis",
                        iconColor: Color.indigo,
                        accentColor: Color.indigo
                    )
                    
                    PromotionCard(
                        promotionTitle: "Refer & Earn",
                        promotionDescription: "Invite friends and earn 200 coins instantly",
                        icon: "person.2.fill",
                        iconColor: Color.green,
                        accentColor: Color.green
                    )
                }
                .padding(.vertical, 2)
            }
        }
    }
}
#Preview {
    HomeView(hideTabBar: .constant(false))
        .environmentObject(LanguageManager.shared)
}
