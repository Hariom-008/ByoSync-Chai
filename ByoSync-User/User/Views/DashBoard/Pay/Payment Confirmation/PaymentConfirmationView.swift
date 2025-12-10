import SwiftUI

struct PaymentConfirmationView: View {
    @EnvironmentObject var cryptoManager: CryptoManager
    @StateObject private var createOrderVM: CreateOrderViewModel
    
    @State private var navigateToRecieptView = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showContent = false
    @State private var amountScale: CGFloat = 0.8
    @State private var showSuccessAnimation = false
    @Environment(\.dismiss) var dismiss
    
    @Binding var hideTabBar: Bool
    @Binding var selectedUser: UserData
    let amount: String
    @Binding var popToHome: Bool
    
    init(
        hideTabBar: Binding<Bool>,
        selectedUser: Binding<UserData>,
        amount: String,
        popToHome: Binding<Bool>
    ) {
        self._hideTabBar = hideTabBar
        self._selectedUser = selectedUser
        self._popToHome = popToHome
        self.amount = amount

        let tempCrypto = CryptoManager()
        self._createOrderVM = StateObject(
            wrappedValue: CreateOrderViewModel(cryptoService: tempCrypto)
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Modern gradient background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "1a1f3a"),
                        Color(hex: "2d3561"),
                        Color(hex: "4B548D")
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                // Floating particles effect
                GeometryReader { geometry in
                    ForEach(0..<8, id: \.self) { index in
                        Circle()
                            .fill(Color.white.opacity(0.05))
                            .frame(width: CGFloat.random(in: 20...60))
                            .position(
                                x: CGFloat.random(in: 0...geometry.size.width),
                                y: CGFloat.random(in: 0...geometry.size.height)
                            )
                            .blur(radius: 10)
                    }
                }
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    headerSection
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 28) {
                            amountDisplaySection
                            recipientCardSection
                            transactionDetailsSection
                            securityBadgeSection
                            actionButtonsSection
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $navigateToRecieptView) {
                ReceiptView(
                    hideTabBar: $hideTabBar,
                    selectedUser: $selectedUser,
                    orderId: $createOrderVM.orderId,
                    popToHome: $popToHome,
                    amount: Int(amount) ?? 0
                )
                .environmentObject(cryptoManager)
            }
            .alert("Payment Failed", isPresented: $showErrorAlert) {
                Button("Retry") {
                    print("🔄 Retry payment")
                    handleConfirmPayment()
                }
                Button("Cancel", role: .cancel) {
                    print("❌ Cancel payment")
                    dismiss()
                    hideTabBar = false
                }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                hideTabBar = true
                print("💳 PaymentConfirmationView appeared")
                print("👤 User: \(selectedUser.firstName) \(selectedUser.lastName)")
                print("💰 Amount: \(amount) coins")
                
                withAnimation(.spring(response: 0.7, dampingFraction: 0.75).delay(0.1)) {
                    showContent = true
                }
                
                withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.2)) {
                    amountScale = 1.0
                }
            }
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        HStack(spacing: 16) {
            Button(action: {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                print("🔙 Close payment")
                dismiss()
                hideTabBar = false
            }) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            
            Spacer()
            
            VStack(spacing: 4) {
                Text("Confirm Payment")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Review & verify")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            // Balance spacer
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : -30)
    }

    // MARK: - Amount Display (Hero Section)
    private var amountDisplaySection: some View {
        VStack(spacing: 16) {
            // Coin icon with glow effect
            ZStack {
                // Glow layers
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 70
                        )
                    )
                    .frame(width: 120, height: 120)
                    .blur(radius: 20)
                
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.2),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 90, height: 90)
                
                Image("byosync_coin")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
            }
            .animation(.spring(response: 1.2, dampingFraction: 0.5).repeatForever(autoreverses: true), value: amountScale)
            
            // Amount
            VStack(spacing: 8) {
                Text(amount)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                
                Text("ByoSync Coins")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                    .tracking(1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .opacity(showContent ? 1 : 0)
        .scaleEffect(showContent ? 1 : 0.8)
    }

    // MARK: - Recipient Card
    private var recipientCardSection: some View {
        VStack(spacing: 0) {
            // Card header with improved styling
            HStack {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "4B548D").opacity(0.15), Color(hex: "6B74A8").opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "4B548D"), Color(hex: "6B74A8")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                Text("Recipient")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(hex: "4B548D"))
                    .tracking(0.5)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 18)
            .background(
                Rectangle()
                    .fill(Color(hex: "F8F9FD"))
            )
            
            Divider()
                .background(Color(hex: "E5E7F0"))
            
            // User info with enhanced design
            HStack(spacing: 16) {
                // Profile picture with animated ring
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(hex: "4B548D").opacity(0.2),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 30,
                                endRadius: 50
                            )
                        )
                        .frame(width: 80, height: 80)
                    
                    // Animated gradient ring
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(hex: "4B548D"),
                                    Color(hex: "7B84B8"),
                                    Color(hex: "6B74A8")
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 72, height: 72)
                    
                    Group {
                        if let url = URL(string: selectedUser.profilePic ?? "") {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    profilePlaceholder
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 64, height: 64)
                                        .clipShape(Circle())
                                case .failure:
                                    profilePlaceholder
                                @unknown default:
                                    profilePlaceholder
                                }
                            }
                        } else {
                            profilePlaceholder
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(cryptoManager.decrypt(encryptedData: selectedUser.firstName) ?? "") \(cryptoManager.decrypt(encryptedData: selectedUser.lastName) ?? "")")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(Color(hex: "1A1F36"))
                    
                    Text(cryptoManager.decrypt(encryptedData: selectedUser.email) ?? "")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "6B7280"))
                        .lineLimit(1)
                    
                    // Enhanced verified badge
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Verified")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "4CAF50"), Color(hex: "45a049")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: Color(hex: "4CAF50").opacity(0.3), radius: 6, x: 0, y: 3)
                }
                
                Spacer()
                
                // Status indicator
                VStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: "4CAF50"))
                        .frame(width: 8, height: 8)
                        .shadow(color: Color(hex: "4CAF50").opacity(0.5), radius: 4, x: 0, y: 0)
                    
                    Text("Active")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color(hex: "4CAF50"))
                }
            }
            .padding(20)
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.white)
                .shadow(color: Color(hex: "4B548D").opacity(0.12), radius: 24, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(hex: "E5E7F0"),
                            Color(hex: "F0F1F7")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 30)
        .animation(.spring(response: 0.7, dampingFraction: 0.75).delay(0.15), value: showContent)
    }
    
    private var profilePlaceholder: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "4B548D").opacity(0.15),
                            Color(hex: "6B74A8").opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 64, height: 64)
            
            Text(selectedUser.initials)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "4B548D"), Color(hex: "6B74A8")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }

    // MARK: - Transaction Details
    private var transactionDetailsSection: some View {
        VStack(spacing: 14) {
            modernDetailRow(
                icon: "calendar",
                iconColor: Color(hex: "FF9500"),
                iconBg: Color(hex: "FF9500").opacity(0.12),
                title: "Date & Time",
                value: formattedDateTime
            )
            
            Divider()
                .background(Color(hex: "F0F1F7"))
            
            modernDetailRow(
                icon: "bolt.fill",
                iconColor: Color(hex: "4CAF50"),
                iconBg: Color(hex: "4CAF50").opacity(0.12),
                title: "Processing Speed",
                value: "Instant Transfer"
            )
            
            Divider()
                .background(Color(hex: "F0F1F7"))
            
            modernDetailRow(
                icon: "dollarsign.circle.fill",
                iconColor: Color(hex: "007AFF"),
                iconBg: Color(hex: "007AFF").opacity(0.12),
                title: "Transaction Fee",
                value: "Free"
            )
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(.white)
                .shadow(color: Color(hex: "4B548D").opacity(0.1), radius: 20, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    Color(hex: "E5E7F0"),
                    lineWidth: 1
                )
        )
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 30)
        .animation(.spring(response: 0.7, dampingFraction: 0.75).delay(0.2), value: showContent)
    }
    
    private func modernDetailRow(icon: String, iconColor: Color, iconBg: Color, title: String, value: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(iconBg)
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "6B7280"))
                
                Text(value)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(hex: "1A1F36"))
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(Color(hex: "4CAF50"))
        }
    }

    // MARK: - Security Badge
    private var securityBadgeSection: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "4CAF50").opacity(0.2), Color(hex: "45a049").opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "4CAF50"), Color(hex: "45a049")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text("Secure Transaction")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                
                Text("End-to-end encrypted • Bank-level security")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "4CAF50").opacity(0.2),
                            Color(hex: "45a049").opacity(0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "4CAF50").opacity(0.4), Color(hex: "45a049").opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .shadow(color: Color(hex: "4CAF50").opacity(0.2), radius: 12, x: 0, y: 6)
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 30)
        .animation(.spring(response: 0.7, dampingFraction: 0.75).delay(0.25), value: showContent)
    }

    // MARK: - Action Buttons
    private var actionButtonsSection: some View {
        VStack(spacing: 14) {
            // Confirm button with enhanced design
            Button(action: {
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                print("💳 Confirm payment tapped")
                handleConfirmPayment()
            }) {
                HStack(spacing: 12) {
                    if createOrderVM.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.0)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22, weight: .bold))
                    }
                    
                    Text(createOrderVM.isLoading ? "Processing Payment..." : "Confirm Payment")
                        .font(.system(size: 18, weight: .bold))
                        .tracking(0.3)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .foregroundColor(.white)
                .background(
                    Group {
                        if createOrderVM.isLoading {
                            RoundedRectangle(cornerRadius: 18)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(hex: "6B74A8").opacity(0.8),
                                            Color(hex: "7B84B8").opacity(0.8)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        } else {
                            RoundedRectangle(cornerRadius: 18)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(hex: "4B548D"),
                                            Color(hex: "6B74A8"),
                                            Color(hex: "7B84B8")
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        }
                    }
                )
                .shadow(color: Color(hex: "4B548D").opacity(0.5), radius: 20, x: 0, y: 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.2), Color.white.opacity(0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                )
            }
            .disabled(createOrderVM.isLoading)
            .scaleEffect(createOrderVM.isLoading ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: createOrderVM.isLoading)

            // Cancel button with refined style
            Button(action: {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                print("❌ Cancel payment")
                dismiss()
                hideTabBar = false
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 18, weight: .semibold))
                    
                    Text("Cancel")
                        .font(.system(size: 17, weight: .semibold))
                        .tracking(0.2)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .foregroundColor(.white.opacity(0.95))
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                )
            }
            .disabled(createOrderVM.isLoading)
            .opacity(createOrderVM.isLoading ? 0.5 : 1.0)
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 30)
        .animation(.spring(response: 0.7, dampingFraction: 0.75).delay(0.3), value: showContent)
    }

    private var formattedDateTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, yyyy • hh:mm a"
        return formatter.string(from: Date())
    }

    // MARK: - Confirm Action
    private func handleConfirmPayment() {
        print("✅ [VIEW] Confirm payment initiated")
        print("👤 Receiver: \(selectedUser.id)")
        print("💰 Amount: \(amount) coins")

        createOrderVM.createOrder(
            receiverId: selectedUser.id,
            amount: Int(amount) ?? 0
        )
        
        navigateToRecieptView = true
    }
}
