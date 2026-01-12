import SwiftUI

struct ChaiDashBoardView: View {
    @StateObject private var viewModel = UserDataByIdViewModel()
    @Environment(\.dismiss) private var dismiss
    
    // Animation states
    @State private var showContent = false
    @State private var animateChaiCups = false
    
    @Binding var userId: String
    @Binding var deviceKeyHash:String
    
    // Colors
    private let logoBlue = Color(red: 0.0, green: 0.0, blue: 1.0)
    private let logoPurple = Color(red: 0.478, green: 0.0, blue: 1.0)
    private let chaiOrange = Color(red: 0.961, green: 0.576, blue: 0.212)
    private let chaiGold = Color(red: 0.957, green: 0.761, blue: 0.278)
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.972, green: 0.980, blue: 0.988),
                    Color(red: 0.937, green: 0.965, blue: 1.0),
                    Color(red: 0.929, green: 0.929, blue: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Animated background blobs
            AnimatedBackgroundBlobs(
                visible: showContent,
                logoBlue: logoBlue,
                logoPurple: logoPurple
            )
            
            if viewModel.isLoading {
                loadingView
            } else if let errorText = viewModel.errorText {
                errorView(errorText)
            } else if viewModel.hasAttemptedLoad {
                contentView
            }
        }
        .onAppear {
            print("☕ [ChaiDashBoardView] appeared")
            loadUserData()
            
            // Show content with delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 1.0)) {
                    showContent = true
                }
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading your chai dashboard…")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(red: 0.392, green: 0.455, blue: 0.545))
        }
    }
    
    // MARK: - Error View
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.red, Color.red.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            Text("Error")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Color(red: 0.118, green: 0.161, blue: 0.231))
            
            Text(error)
                .font(.system(size: 14))
                .foregroundColor(Color(red: 0.392, green: 0.455, blue: 0.545))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button {
                print("🔄 [ChaiDashBoardView] Retry tapped")
                loadUserData()
            } label: {
                Text("Retry")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 120, height: 44)
                    .background(
                        LinearGradient(
                            colors: [logoBlue, logoPurple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Content View
    
    private var contentView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer().frame(height: 60)
                
                if showContent {
                    // Welcome section
                    welcomeSection
                        .transition(.scale.combined(with: .opacity))
                    
                    Spacer().frame(height: 32)
                    
                    // Stats cards
                    statsSection
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    
                    Spacer().frame(height: 32)
                    
                    // Close button
                    closeButton
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                Spacer().frame(height: 32)
            }
            .padding(.horizontal, 24)
        }
    }
    
    // MARK: - Welcome Section
    
    private var welcomeSection: some View {
        VStack(spacing: 0) {
            // Chai cup icon
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 100, height: 100)
                    .shadow(color: chaiOrange.opacity(0.3), radius: 12, y: 6)
                
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [chaiOrange, chaiGold],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            Spacer().frame(height: 24)
            
            // User name
            if let user = viewModel.user {
                let firstName = CryptoManager.shared.decrypt(encryptedData: "\(user.firstName)")
                let lastName =  CryptoManager.shared.decrypt(encryptedData: "\(user.lastName)")
                Text("Welcome, \(firstName ?? "nil") \(lastName ?? "nil")")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [logoBlue, logoPurple],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .multilineTextAlignment(.center)
            } else {
                Text("Welcome!")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [logoBlue, logoPurple],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            
            Spacer().frame(height: 8)
            
            Text("Your Chai Dashboard")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(Color(red: 0.392, green: 0.455, blue: 0.545))
        }
    }
    
    // MARK: - Stats Section
    
    private var statsSection: some View {
        VStack(spacing: 16) {
            // Today's Chai Card
            chaiStatCard(
                title: "Today's Claimed Chai",
                value: "\(viewModel.user?.todayChaiCount ?? 0)",
                subtitle: "out of 2 available",
                icon: "calendar.badge.clock",
                colors: [chaiOrange, chaiGold],
                isToday: true
            )
            
            // Total Chai Card
            chaiStatCard(
                title: "Total Chai Claimed",
                value: "\(viewModel.chai)",
                subtitle: "all time",
                icon: "cup.and.saucer.fill",
                colors: [logoBlue, logoPurple],
                isToday: false
            )
        }
    }
    
    private func chaiStatCard(
        title: String,
        value: String,
        subtitle: String,
        icon: String,
        colors: [Color],
        isToday: Bool
    ) -> some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    // Title
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(red: 0.392, green: 0.455, blue: 0.545))
                    
                    // Value with animated cups
                    HStack(spacing: 8) {
                        Text(value)
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: colors,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        if isToday {
                            // Animated chai cups for today's count
                            HStack(spacing: 4) {
                                ForEach(0..<2, id: \.self) { index in
                                    Image(systemName: index < (viewModel.user?.todayChaiCount ?? 0) ? "cup.and.saucer.fill" : "cup.and.saucer")
                                        .font(.system(size: 20))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: index < (viewModel.user?.todayChaiCount ?? 0) ? colors : [Color.gray.opacity(0.3), Color.gray.opacity(0.3)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .scaleEffect(animateChaiCups ? 1.0 : 0.8)
                                        .animation(
                                            .spring(response: 0.5, dampingFraction: 0.6)
                                            .delay(Double(index) * 0.1),
                                            value: animateChaiCups
                                        )
                                }
                            }
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    animateChaiCups = true
                                }
                            }
                        }
                    }
                    
                    // Subtitle
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(red: 0.580, green: 0.639, blue: 0.722))
                }
                
                Spacer()
                
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: colors.map { $0.opacity(0.15) },
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 70, height: 70)
                    
                    Image(systemName: icon)
                        .font(.system(size: 32))
                        .foregroundStyle(
                            LinearGradient(
                                colors: colors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .padding(20)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
        )
    }
    
    // MARK: - Close Button
    
    private var closeButton: some View {
        Button {
            print("✅ [ChaiDashBoardView] Close tapped")
            dismiss()
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                
                Text("Done")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: [logoBlue, logoPurple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: logoBlue.opacity(0.3), radius: 12, y: 6)
        }
    }
    
    // MARK: - Actions
    
    private func loadUserData() {
        guard !userId.isEmpty else {
            viewModel.setError("User not logged in")
            return
        }
        
        let deviceKeyHash = deviceKeyHash
        
        
        viewModel.beginLoading(clearOldData: true)
        viewModel.fetch(userId: userId, deviceKeyHash: deviceKeyHash)
    }
}
