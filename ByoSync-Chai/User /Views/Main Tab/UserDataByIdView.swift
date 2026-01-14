import SwiftUI

// MARK: - Color Palette
private let logoBlue = Color(red: 0.0, green: 0.0, blue: 1.0)
private let logoPurple = Color(red: 0.478, green: 0.0, blue: 1.0)
private let backgroundStart = Color(red: 0.972, green: 0.980, blue: 0.988)
private let backgroundMid = Color(red: 0.937, green: 0.965, blue: 1.0)
private let backgroundEnd = Color(red: 0.929, green: 0.929, blue: 1.0)
private let cardBackground = Color.white
private let textPrimary = Color(red: 0.118, green: 0.161, blue: 0.231)
private let textSecondary = Color(red: 0.392, green: 0.455, blue: 0.545)
private let accentGold = Color(red: 1.0, green: 0.72, blue: 0.30)

struct UserDataByIdView: View {
    enum Mode {
        case live
#if DEBUG
        case mockContent
        case mockLoading
        case mockError
#endif
    }

    private let mode: Mode

    @StateObject private var viewModel: UserDataByIdViewModel
    @StateObject private var userSession: UserSession = UserSession.shared
    @Environment(\.dismiss) private var dismiss
    let cryptoManager = CryptoManager.shared

    @MainActor
    init(mode: Mode = .live, viewModel: UserDataByIdViewModel? = nil) {
        self.mode = mode
        if let vm = viewModel {
            _viewModel = StateObject(wrappedValue: vm)
        } else {
            _viewModel = StateObject(wrappedValue: UserDataByIdViewModel())
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [backgroundStart, backgroundMid, backgroundEnd],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // ✅ Prevent "No data" flash: show loading before first attempt
            if viewModel.isLoading {
                loadingView
            } else if let error = viewModel.errorText {
                errorView(error)
            } else if let user = viewModel.user {
                userContentView(user: user)
            } else if viewModel.hasAttemptedLoad {
                emptyStateView
            } else {
                loadingView
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("ByoSync")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [logoBlue, logoPurple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Link(destination: URL(string: "https://www.byosync.com/policy")!) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [logoBlue, logoPurple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                .onTapGesture {
                    print("🔗 Opening Privacy Policy")
                }
            }
        }
        .onAppear {
            print("👁️ UserDataByIdView appeared")

            switch mode {
            case .live:
                fetchUserData()

#if DEBUG
            case .mockContent:
                viewModel.loadMock()
            case .mockLoading:
                viewModel.loadMockLoading()
            case .mockError:
                viewModel.loadMockError()
#endif
            }
        }
        // ✅ When data arrives, update session (no async needed)
        .onChange(of: viewModel.user) { newUser in
            guard let user = newUser else { return }
            updateUserSession(with: user)
        }
        // SwiftUI requires async here, but we call sync refresh inside.
        .refreshable {
            print("🔄 Pull to refresh triggered")
            refreshUserData()
        }
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(logoBlue)

            Text("Loading your profile...")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(textSecondary)
        }
    }

    // MARK: - Error View
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 20) {
            ModernCard {
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.1))
                            .frame(width: 70, height: 70)

                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.red)
                    }

                    Text("Unable to Load Profile")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(textPrimary)

                    Text(error)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(32)
            }

            Button(action: {
                print("🔄 Retry button tapped")
                fetchUserData()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Retry")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [logoBlue, logoPurple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(14)
                .shadow(color: logoBlue.opacity(0.3), radius: 8, y: 4)
            }
            .padding(.horizontal, 24)
        }
        .padding(24)
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(logoBlue.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 50))
                    .foregroundColor(logoBlue.opacity(0.5))
            }

            Text("No profile data available")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(textSecondary)
        }
    }

    // MARK: - User Content View
    private func userContentView(user: UserByIdDTO) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                profileHeaderView(user: user)
                chaiBalanceCard
                userDetailsCard(user: user)
                logoutButton
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Profile Header
    private func profileHeaderView(user: UserByIdDTO) -> some View {
        ModernCard {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [logoBlue, logoPurple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 94, height: 94)

                    if let profilePicUrl = user.profilePic, !profilePicUrl.isEmpty {
                        AsyncImage(url: URL(string: profilePicUrl)) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            ZStack {
                                Circle().fill(logoBlue.opacity(0.1))
                                Image(systemName: "person.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(logoBlue.opacity(0.5))
                            }
                        }
                        .frame(width: 88, height: 88)
                        .clipShape(Circle())
                    } else {
                        ZStack {
                            Circle()
                                .fill(logoBlue.opacity(0.1))
                                .frame(width: 88, height: 88)

                            Image(systemName: "person.fill")
                                .font(.system(size: 40))
                                .foregroundColor(logoBlue.opacity(0.5))
                        }
                    }
                }

                VStack(spacing: 6) {
                    Text("\(cryptoManager.decrypt(encryptedData: user.firstName) ?? "User") \(cryptoManager.decrypt(encryptedData: user.lastName) ?? "")")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [logoBlue, logoPurple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                        Text("Certified Member")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(textSecondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(logoBlue.opacity(0.1))
                    .cornerRadius(20)
                }
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Chai Balance Card
    private var chaiBalanceCard: some View {
        ModernCard {
            VStack(spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Chai Balance")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(textSecondary)

                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(viewModel.chai)")
                                .font(.system(size: 48, weight: .bold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [logoBlue, logoPurple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )

                            Text("/ 5")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(textSecondary)
                        }
                    }

                    Spacer()

                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [logoBlue.opacity(0.2), logoPurple.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 64, height: 64)

                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [logoBlue, logoPurple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(logoBlue.opacity(0.1))
                            .frame(height: 12)

                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [logoBlue, logoPurple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * CGFloat(viewModel.chai) / 5.0, height: 12)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewModel.chai)
                    }
                }
                .frame(height: 12)
            }
            .padding(24)
        }
    }

    // MARK: - User Details Card
    private func userDetailsCard(user: UserByIdDTO) -> some View {
        ModernCard {
            VStack(spacing: 20) {
                HStack {
                    Text("Account Details")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(textPrimary)
                    Spacer()
                }

                VStack(spacing: 16) {
                    DetailRow(
                        icon: "envelope.fill",
                        iconColor: logoBlue,
                        label: "Email",
                        value: cryptoManager.decrypt(encryptedData: user.email) ?? "Not available"
                    )

                    Divider()
                        .background(logoBlue.opacity(0.1))

                    if !user.phoneNumber.isEmpty {
                        DetailRow(
                            icon: "phone.fill",
                            iconColor: logoPurple,
                            label: "Phone",
                            value: cryptoManager.decrypt(encryptedData: user.phoneNumber) ?? "Not available"
                        )
                    }
                }
            }
            .padding(24)
        }
    }

    // MARK: - Detail Row Component
    private func DetailRow(icon: String, iconColor: Color, label: String, value: String) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(textSecondary)

                Text(value)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(textPrimary)
                    .lineLimit(1)
            }

            Spacer()
        }
    }

    // MARK: - Logout Button
    private var logoutButton: some View {
        Button(action: handleLogout) {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 18, weight: .semibold))

                Text("Logout")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                LinearGradient(
                    colors: [Color.red, Color.red.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(14)
            .shadow(color: Color.red.opacity(0.3), radius: 8, y: 4)
        }
    }

    // MARK: - Modern Card Component
    private struct ModernCard<Content: View>: View {
        let content: Content
        init(@ViewBuilder content: () -> Content) { self.content = content() }

        var body: some View {
            content
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(cardBackground)
                        .shadow(color: Color.black.opacity(0.06), radius: 12, y: 4)
                )
        }
    }

    // MARK: - Fetch User Data (SYNC kickoff)
    private func fetchUserData() {
        print("🔍 Starting to fetch user data...")

        let deviceKey = DeviceIdentity.resolve()
        let deviceKeyHash = HMACGenerator.generateHMAC(jsonString: deviceKey)
        print("✅ Device Key Hash resolved: \(deviceKeyHash)")

        let userId = ""
        guard !userId.isEmpty else {
            print("❌ No userId found in UserSession")
            viewModel.setError("No user session found. Please log in again.")
            return
        }

        // ✅ update UI immediately
        viewModel.beginLoading(clearOldData: true)

        // ✅ completion-based fetch
        viewModel.fetch(userId: userId, deviceKeyHash: deviceKeyHash)
    }

    // MARK: - Refresh User Data (SYNC kickoff)
    private func refreshUserData() {
        print("🔄 Refreshing user data...")

        let deviceKey = DeviceIdentity.resolve()
        let deviceKeyHash = HMACGenerator.generateHMAC(jsonString: deviceKey)

        let userId = ""
        guard !userId.isEmpty else {
            print("❌ No userId found in UserSession")
            viewModel.setError("No user session found. Please log in again.")
            return
        }

        // keep existing profile visible during refresh
        viewModel.beginLoading(clearOldData: false)
        viewModel.fetch(userId: userId, deviceKeyHash: deviceKeyHash)
    }

    // MARK: - Update UserSession
    private func updateUserSession(with userData: UserByIdDTO) {
        print("💾 Updating UserSession with fetched data...")

        userSession.setUserWallet(userData.wallet)
        userSession.setEmailVerified(userData.emailVerified)

        if let profilePic = userData.profilePic {
            userSession.setProfilePicture(profilePic)
        }

        if let device = viewModel.device {
            userSession.setThisDevicePrimary(device.isPrimary)
            userSession.setCurrentDeviceID(device.id)
        }

        let updatedUser = User(
            firstName: userData.firstName,
            lastName: userData.lastName,
            email: userData.email,
            phoneNumber: userData.phoneNumber,
            deviceKey: viewModel.device?.deviceKey,
            deviceName: viewModel.device?.deviceName,
            fcmToken: userSession.currentUser?.fcmToken,
            refferalCode: userData.referralCode,
            userId: userData.id,
            userDeviceId: viewModel.device?.id
        )

        userSession.saveUser(updatedUser)
        print("🎉 UserSession update complete!")
    }

    // MARK: - Handle Logout
    private func handleLogout() {
        print("🚪 Logout button tapped")
        userSession.clearUser()
        dismiss()
        dismiss()
    }
}

#Preview {
    NavigationStack {
        UserDataByIdView()
    }
}
