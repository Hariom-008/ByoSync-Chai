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
    @StateObject private var cryptoManager:CryptoManager
    
    // MARK: - Initialization with Dependency Injection
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
        // Add this line to initialize the @StateObject
        _cryptoManager = StateObject(wrappedValue: cryptoManager)
        print("🏗️ [VIEW] SortedUsersView initialized")
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient
                
                VStack(spacing: 0) {
                    // Custom header
                    customHeader
                    
                    // Amount display banner
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
                        amount: amount
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
                print("🔙 [VIEW] Back button tapped")
                dismiss()
                hideTabBar = false
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 40, height: 40)
                        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
                    
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "4B548D"))
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Send Money")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Select a recipient")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            searchButton
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : -20)
    }
    
    // MARK: - Amount Banner
    private var amountBanner: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: "4B548D").opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image("byosync_coin")
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Amount to Pay")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text("\(amount) Coin")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "4B548D"), Color(hex: "6B74A8")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            
            Spacer()
            
            // Show user count
            if !viewModel.users.isEmpty {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(filteredUsers.count - 1)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color(hex: "4B548D"))
                    
                    Text("users")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
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
        .scaleEffect(showContent ? 1 : 0.9)
        .opacity(showContent ? 1 : 0)
    }
    
    // MARK: - Background
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(hex: "F8F9FD"),
                Color(hex: "EEF0F8")
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Search Bar
    private var searchBarView: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.gray)
            
            TextField("Search by name, email or phone", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 15))
            
            if !searchText.isEmpty {
                Button(action: {
                    print("🗑️ [VIEW] Clearing search text")
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    private var searchButton: some View {
        Button(action: {
            print("🔍 [VIEW] Search button toggled: \(!showSearchBar)")
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                showSearchBar.toggle()
                if !showSearchBar {
                    searchText = ""
                }
            }
        }) {
            ZStack {
                Circle()
                    .fill(showSearchBar ? Color(hex: "4B548D").opacity(0.1) : Color.white)
                    .frame(width: 40, height: 40)
                    .shadow(color: showSearchBar ? .clear : .black.opacity(0.06), radius: 8, x: 0, y: 2)
                
                Image(systemName: showSearchBar ? "xmark" : "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "4B548D"))
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
        VStack(spacing: 12) {
            ProgressView()
            
            Text("Finding Users")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color(hex: "4B548D").opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "person.2.slash")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "4B548D"), Color(hex: "6B74A8")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 12) {
                Text("No Users Found")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("There are no users available to send money to at the moment. Pull down to refresh.")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button(action: {
                print("🔄 [VIEW] Refresh button tapped")
                Task {
                    await viewModel.retry()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Refresh")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
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
                .cornerRadius(14)
                .shadow(color: Color(hex: "4B548D").opacity(0.3), radius: 12, x: 0, y: 6)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var usersList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(filteredUsers.enumerated()), id: \.element.id) { index, user in
                    if UserSession.shared.currentUser?.userId != user.id {
                        UserCardView(cryptoManager: cryptoManager,user: user) {
                            print("✅ [VIEW] User selected - \(user.firstName) \(user.lastName)")
                            print("🆔 [VIEW] User ID - \(user.id)")
                            selectedUser = user
                            openSelectedUserDetailsView = true
                        }
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                        .animation(
                            .spring(response: 0.6, dampingFraction: 0.8)
                            .delay(Double(index) * 0.05),
                            value: showContent
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
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

// MARK: - User Card View
struct UserCardView: View {
    @ObservedObject var cryptoManager:CryptoManager
    let user: UserData
    let onTap: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            print("👆 [CARD] Card tapped for user: \(user.firstName) \(user.lastName)")
            onTap()
        }) {
            HStack(spacing: 8) {
                profileImage
                userInfo
                Spacer()
                Selectbutton
            }
            .padding(16)
            .background(cardBackground)
            .cornerRadius(16)
            .shadow(color: .black.opacity(isPressed ? 0.08 : 0.04), radius: isPressed ? 4 : 8, x: 0, y: isPressed ? 2 : 4)
            .scaleEffect(isPressed ? 0.97 : 1.0)
        }
        .buttonStyle(CardButtonStyle(isPressed: $isPressed))
    }
    
    private var profileImage: some View {
        Group {
            if let url = URL(string: user.profilePic) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.1))
                                .frame(width: 36, height: 36)
                            
                            ProgressView()
                                .tint(Color(hex: "4B548D"))
                        }
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color(hex: "4B548D").opacity(0.1), lineWidth: 2)
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
                            Color(hex: "6B74A8").opacity(0.15)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 26, height: 26)
            
            Text(user.initials)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "4B548D"), Color(hex: "6B74A8")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
    
    private var userInfo: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(cryptoManager.decrypt(encryptedData: user.firstName) ?? "nil") \(cryptoManager.decrypt(encryptedData: user.lastName) ?? "nil")")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text(cryptoManager.decrypt(encryptedData: user.email) ?? "nil")
                        .font(.system(size: 8, weight: .regular))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    // Spacer()
                    
                    HStack(spacing: 6) {
                        Text("Recieved: \(user.noOfTransactionsReceived)")
                            .font(.system(size: 8, weight: .regular))
                            .foregroundColor(.black)
                            .lineLimit(1)
                        Text("Paid:\(user.noOfTransactions)")
                            .font(.system(size: 8, weight: .regular))
                            .foregroundColor(.black)
                            .lineLimit(1)
                    }
                }
            }
        }
    }
    
    private var Selectbutton: some View {
        ZStack {
            Text("Select")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Color(hex: "4B548D"))
        }
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(hex: "4B548D").opacity(0.05),
                                Color(hex: "6B74A8").opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

// MARK: - Custom Button Style
struct CardButtonStyle: ButtonStyle {
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
