import Foundation
import SwiftUI

struct SortedUsersView: View {
    @StateObject private var viewModel: SortedUsersViewModel
    @State private var searchText = ""
    @State private var showSearchBar = false
    @Binding var hideTabBar: Bool
    @Binding var amount: String
    @State private var selectedUser: UserData?
    @State private var openSelectedUserDetailsView: Bool = false
    @State private var showContent: Bool = false
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cryptoManager: CryptoManager
    @State private var popToHome = false
    
    init(
        hideTabBar: Binding<Bool>,
        amount: Binding<String>,
        repository: SortedUsersRepositoryProtocol = SortedUsersRepository(),
        cryptoManager: CryptoManager = CryptoManager()
    ) {
        self._hideTabBar = hideTabBar
        self._amount = amount
        _viewModel = StateObject(
            wrappedValue: SortedUsersViewModel(
                repository: repository,
                cryptoManager: cryptoManager
            )
        )
        _cryptoManager = StateObject(wrappedValue: cryptoManager)
        print("🏗️ [VIEW] SortedUsersView initialized")
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient
                
                VStack(spacing: 12) {
                    customHeader
                    amountBanner
                    
                    if showSearchBar {
                        searchBarView
                    }
                    
                    contentView
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $openSelectedUserDetailsView) {
                if let user = selectedUser {
                    PaymentConfirmationView(
                        hideTabBar: $hideTabBar,
                        selectedUser: .constant(user),
                        amount: amount,
                        popToHome: $popToHome
                    )
                }
            }
            .task {
                print("📱 [VIEW] SortedUsersView appeared, fetching users...")
                await viewModel.fetchSortedUsers()
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                    showContent = true
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("Retry") {
                    print("🔄 [VIEW] Retry button tapped")
                    Task {
                        await viewModel.retry()
                    }
                }
                Button("Cancel", role: .cancel) {
                    print("❌ [VIEW] Error alert cancelled")
                }
            } message: {
                Text(viewModel.errorMessage ?? "An unknown error occurred")
            }
        }
        .onDisappear {
            print("👋 [VIEW] SortedUsersView disappeared")
        }
    }
    
    // MARK: - Custom Header
    private var customHeader: some View {
        HStack(spacing: 16) {
            Button {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                print("🔙 [VIEW] Back button tapped")
                dismiss()
                hideTabBar = false
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 44, height: 44)
                        .shadow(color: Color(hex: "4B548D").opacity(0.1), radius: 12, x: 0, y: 4)
                    
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color(hex: "4B548D"))
                }
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text("Select Recipient")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Choose who to pay")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            searchButton
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .background(
            Color(.systemBackground)
                .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 2)
        )
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : -20)
    }
    
    // MARK: - Amount Banner
    private var amountBanner: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Coin display
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: "FFD700").opacity(0.15),
                                    Color(hex: "FFA500").opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(hex: "FFD700").opacity(0.3),
                                    Color(hex: "FFA500").opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 60, height: 60)
                    
                    Image("byosync_coin")
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 44, height: 44)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Amount to Send")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(amount)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "4B548D"), Color(hex: "6B74A8")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        Text("coins")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.secondary)
                            .offset(y: 2)
                    }
                }
                
                Spacer()
                
                // User count badge
                if !viewModel.users.isEmpty {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "4B548D"), Color(hex: "6B74A8")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 48, height: 48)
                            
                            Text("\(filteredUsers.count - 1)")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        Text("available")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.5)
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .shadow(color: Color(hex: "4B548D").opacity(0.1), radius: 16, x: 0, y: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(hex: "4B548D").opacity(0.1),
                                Color(hex: "6B74A8").opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .scaleEffect(showContent ? 1 : 0.9)
            .opacity(showContent ? 1 : 0)
        }
    }
    
    // MARK: - Background
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(hex: "F5F7FC"),
                Color(hex: "E8EBF5")
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Search Bar
    private var searchBarView: some View {
        HStack(spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Color(hex: "4B548D"))
            
            TextField("Search by name or email", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
            
            if !searchText.isEmpty {
                Button(action: {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    print("🗑️ [VIEW] Clearing search text")
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        searchText = ""
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.gray)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color(hex: "4B548D").opacity(0.08), radius: 12, x: 0, y: 4)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    private var searchButton: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            print("🔍 [VIEW] Search button toggled: \(!showSearchBar)")
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                showSearchBar.toggle()
                if !showSearchBar {
                    searchText = ""
                }
            }
        }) {
            ZStack {
                Circle()
                    .fill(
                        showSearchBar
                        ? LinearGradient(
                            colors: [Color(hex: "4B548D"), Color(hex: "6B74A8")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(colors: [Color.white, Color.white], startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: 44, height: 44)
                    .shadow(color: Color(hex: "4B548D").opacity(showSearchBar ? 0.3 : 0.1), radius: 12, x: 0, y: 4)
                
                Image(systemName: showSearchBar ? "xmark" : "magnifyingglass")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(showSearchBar ? .white : Color(hex: "4B548D"))
                    .rotationEffect(.degrees(showSearchBar ? 90 : 0))
            }
        }
    }
    
    // MARK: - Content View
    @ViewBuilder
    private var contentView: some View {
        if viewModel.isLoading {
            loadingView
        } else if viewModel.users.isEmpty {
            emptyStateView
        } else {
            usersList
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.3)
                .tint(Color(hex: "4B548D"))
            
            Text("Finding Users...")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            
            Text("Please wait a moment")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer()
                    .frame(height: 60)
                
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: "4B548D").opacity(0.1),
                                    Color(hex: "6B74A8").opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "person.2.slash.fill")
                        .font(.system(size: 52, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "4B548D"), Color(hex: "6B74A8")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                VStack(spacing: 12) {
                    Text("No Users Available")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("There are no users to send money to right now. Try refreshing to check again.")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 40)
                }
                
                Button(action: {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    print("🔄 [VIEW] Refresh button tapped")
                    Task {
                        await viewModel.retry()
                    }
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Refresh")
                            .font(.system(size: 17, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(hex: "4B548D"),
                                Color(hex: "6B74A8")
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: Color(hex: "4B548D").opacity(0.3), radius: 16, x: 0, y: 8)
                }
                .padding(.top, 12)
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private var usersList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 14) {
                ForEach(Array(filteredUsers.enumerated()), id: \.element.id) { index, user in
                    if UserSession.shared.currentUser?.userId != user.id {
                        ModernUserCardView(cryptoManager: cryptoManager, user: user) {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            print("✅ [VIEW] User selected - \(user.firstName) \(user.lastName)")
                            print("🆔 [VIEW] User ID - \(user.id)")
                            selectedUser = user
                            openSelectedUserDetailsView = true
                        }
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 30)
                        .animation(
                            .spring(response: 0.6, dampingFraction: 0.8)
                            .delay(Double(index) * 0.05),
                            value: showContent
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .padding(.bottom, 20)
        }
        .refreshable {
            print("🔄 [VIEW] Pull to refresh triggered")
            await viewModel.fetchSortedUsers()
        }
    }
    
    private var filteredUsers: [UserData] {
        let filtered = viewModel.filterUsers(by: searchText)
        print("🔎 [VIEW] Filtered users count: \(filtered.count) from search: '\(searchText)'")
        return filtered
    }
}

// MARK: - Modern User Card View
struct ModernUserCardView: View {
    @ObservedObject var cryptoManager: CryptoManager
    let user: UserData
    let onTap: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            print("👆 [CARD] Card tapped for user: \(user.firstName) \(user.lastName)")
            onTap()
        }) {
            HStack(spacing: 16) {
                // Profile Section
                profileImage
                
                // User Info
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(cryptoManager.decrypt(encryptedData: user.firstName) ?? "") \(cryptoManager.decrypt(encryptedData: user.lastName) ?? "")")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(cryptoManager.decrypt(encryptedData: user.email) ?? "")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    // Transaction stats
                    HStack(spacing: 12) {
                        statBadge(
                            icon: "arrow.down.circle.fill",
                            value: "\(user.noOfTransactionsReceived)",
                            color: Color(hex: "4CAF50")
                        )
                        
                        statBadge(
                            icon: "arrow.up.circle.fill",
                            value: "\(user.noOfTransactions)",
                            color: Color(hex: "FF9500")
                        )
                    }
                }
                
                Spacer()
                
                // Arrow indicator
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "4B548D").opacity(0.4))
                    .offset(x: isPressed ? -4 : 0)
            }
            .padding(18)
            .background(cardBackground)
            .cornerRadius(20)
            .shadow(
                color: Color(hex: "4B548D").opacity(isPressed ? 0.15 : 0.08),
                radius: isPressed ? 8 : 16,
                x: 0,
                y: isPressed ? 4 : 8
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
        }
        .buttonStyle(ModernCardButtonStyle(isPressed: $isPressed))
    }
    
    private var profileImage: some View {
        Group {
            if let url = URL(string: user.profilePic ?? "") {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.1))
                                .frame(width: 60, height: 60)
                            
                            ProgressView()
                                .tint(Color(hex: "4B548D"))
                        }
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color(hex: "4B548D").opacity(0.3),
                                                Color(hex: "6B74A8").opacity(0.2)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2.5
                                    )
                            )
                    case .failure:
                        initialsView
                    @unknown default:
                        initialsView
                    }
                }
            } else {
                initialsView
            }
        }
    }
    
    private var initialsView: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(hex: "4B548D").opacity(0.15),
                            Color(hex: "6B74A8").opacity(0.1)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 60, height: 60)
            
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(hex: "4B548D").opacity(0.3),
                            Color(hex: "6B74A8").opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2.5
                )
                .frame(width: 60, height: 60)
            
            Text(user.initials)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "4B548D"), Color(hex: "6B74A8")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
    
    private func statBadge(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(color.opacity(0.12))
        )
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(hex: "4B548D").opacity(0.1),
                                Color(hex: "6B74A8").opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
    }
}

// MARK: - Custom Button Style
struct ModernCardButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { oldValue, newValue in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isPressed = newValue
                }
            }
    }
}
