import SwiftUI

struct EnterNumberToSearchUserView: View {
    @EnvironmentObject var faceAuthManager: FaceAuthManager
    @StateObject private var viewModel = FetchUserByPhoneNumberViewModel()
    @Environment(\.dismiss) private var dismiss
    
    @State private var phoneNumber: String = ""
    @FocusState private var isPhoneFieldFocused: Bool
    
    // Animation states
    @State private var showContent = false
    @State private var currentFeature = 0
    
    @State var openMLScan:Bool = false
    @State var openChaiClaimView:Bool = false
    @State var openAdminLoginView:Bool = false
    
    // Colors from the logo gradient
    private let logoBlue = Color(red: 0.0, green: 0.0, blue: 1.0)
    private let logoPurple = Color(red: 0.478, green: 0.0, blue: 1.0)
    
    private let features: [(icon: String, title: String, subtitle: String)] = [
        ("phone.fill", "Secure", "Encrypted communication"),
        ("bolt.fill", "Fast", "Quick verification"),
        ("checkmark.seal.fill", "Verified", "Real-time validation")
    ]
    
    var body: some View {
        ZStack {
            // Background gradient matching AuthenticationView
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
            
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 60)
                
                // Logo and title section
                if showContent {
                    logoSection
                        .transition(.scale.combined(with: .opacity))
                }
                
                Spacer()
                
                // Phone input section
                if showContent {
                    phoneInputSection
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                Spacer()
                
                // Bottom button section
                if showContent {
                    bottomSection
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
            
            // Loading overlay
            if viewModel.isLoading {
                Color.black.opacity(0.15)
                    .ignoresSafeArea()
                
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Verifying number…")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(red: 0.118, green: 0.161, blue: 0.231))
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 24)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.1), radius: 12, y: 6)
                )
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear {
            print("📱 [EnterPhoneNumberScreen] appeared")
            
            // Show content with delay for smooth animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 1.0)) {
                    showContent = true
                }
            }
            
            // Auto-focus keyboard after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isPhoneFieldFocused = true
            }
            
            // Start feature rotation
            Timer.scheduledTimer(withTimeInterval: 3.5, repeats: true) { _ in
                withAnimation(.spring(response: 0.8, dampingFraction: 0.85)) {
                    currentFeature = (currentFeature + 1) % features.count
                }
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorText != nil)) {
            Button("OK") {
                viewModel.reset()
            }
        } message: {
            if let error = viewModel.errorText {
                Text(error)
            }
        }
        .onChange(of: viewModel.userId) { _, newValue in
            if newValue != nil {
                print("✅ [EnterPhoneNumberScreen] User fetched successfully")
                handleSuccess()
            }
        }
        .navigationDestination(isPresented: $openMLScan) {
            MLScanView(onDone:{
                // 1) pop MLScanView (because navigationDestination is controlled by openMLScan)
                openMLScan = false

                // 2) present ClaimChaiView after pop completes
                DispatchQueue.main.async {
                    openChaiClaimView = true
                }
            }, userId: viewModel.userId ?? "", deviceKeyHash: viewModel.deviceKeyHash ?? "")
        }
        .fullScreenCover(isPresented: $openChaiClaimView) {
            ClaimChaiView(
                userId: Binding<String>(
                    get: { viewModel.userId ?? "" },
                    set: { newValue in viewModel.userId = newValue.isEmpty ? nil : newValue }
                ),
                deviceKeyHash: Binding<String>(
                    get: { viewModel.deviceKeyHash ?? "" },
                    set: { newValue in viewModel.deviceKeyHash = newValue.isEmpty ? nil : newValue }
                ),
                onDone: {
                    openChaiClaimView = false   // ✅ this returns to EnterNumberToSearchUserView
                }
            )
        }

        .navigationDestination(isPresented: $openAdminLoginView) {
            AdminLoginView()
        }
        .toolbar{
            Button{
                openAdminLoginView.toggle()
            }label: {
                Text("Admin")
            }
        }
    }
    
    // MARK: - Logo Section
    
    private var logoSection: some View {
        VStack(spacing: 0) {
            // Phone icon circle
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 140, height: 140)
                    .shadow(color: .black.opacity(0.1), radius: 12, y: 6)
                
                Image(systemName: "phone.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [logoBlue, logoPurple],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            
            Spacer().frame(height: 28)
            
            // Title with logo gradient
            Text("Enter Phone Number")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [logoBlue, logoPurple],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            Spacer().frame(height: 8)
            
            Text("We'll verify your account")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(Color(red: 0.392, green: 0.455, blue: 0.545))
            
            Spacer().frame(height: 28)
            
            // Rotating feature pill
            FeaturePill(
                icon: features[currentFeature].icon,
                title: features[currentFeature].title,
                subtitle: features[currentFeature].subtitle,
                logoBlue: logoBlue,
                logoPurple: logoPurple
            )
            .id(currentFeature)
            .transition(.asymmetric(
                insertion: .scale(scale: 0.9).combined(with: .opacity),
                removal: .scale(scale: 0.9).combined(with: .opacity)
            ))
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: currentFeature)
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Phone Input Section
    
    private var phoneInputSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Country code
                HStack(spacing: 6) {
                    Text("🇮🇳")
                        .font(.system(size: 24))
                    Text("+91")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(red: 0.118, green: 0.161, blue: 0.231))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
                )
                
                // Phone number input
                HStack(spacing: 12) {
                    Image(systemName: "phone")
                        .foregroundStyle(
                            LinearGradient(
                                colors: [logoBlue.opacity(0.7), logoPurple.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 20)
                    
                    TextField("Phone number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .focused($isPhoneFieldFocused)
                        .textContentType(.telephoneNumber)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(red: 0.118, green: 0.161, blue: 0.231))
                        .onChange(of: phoneNumber) { _, newValue in
                            print("📝 [EnterPhoneNumberScreen] Phone: \(newValue.count) chars")
                        }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isPhoneFieldFocused ?
                            LinearGradient(
                                colors: [logoBlue, logoPurple],
                                startPoint: .leading,
                                endPoint: .trailing
                            ) :
                            LinearGradient(
                                colors: [Color.clear, Color.clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 2
                        )
                )
            }
        }
    }
    
    // MARK: - Bottom Section
    
    private var bottomSection: some View {
        VStack(spacing: 10) {
            Spacer().frame(height: 8)
            
            // Proceed button
            GlassButton(
                text: "Proceed",
                icon: "",
                isPrimary: true,
                logoBlue: isButtonEnabled ? logoBlue : Color.gray,
                logoPurple: isButtonEnabled ? logoPurple : Color.white
            ) {
                handleProceed()
            }
            .disabled(!isButtonEnabled || viewModel.isLoading)
            .opacity(viewModel.isLoading || !isButtonEnabled ? 0.6 : 1.0)
            
            HStack {
                Text("Your data is encrypted and secure")
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundColor(Color(red: 0.580, green: 0.639, blue: 0.722))
                    .multilineTextAlignment(.center)
            }
            
            HStack {
                Text("powered by")
                    .font(.system(size: 8))
                    .foregroundColor(Color(red: 0.580, green: 0.639, blue: 0.722))
                Text("KAVION")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(red: 0.580, green: 0.639, blue: 0.722))
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var isButtonEnabled: Bool {
        !phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Actions
    
    private func handleProceed() {
        let fullPhoneNumber = "+91\(phoneNumber)"
        let trimmed = fullPhoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            print("⚠️ [EnterPhoneNumberScreen] Empty phone number")
            return
        }
        
        isPhoneFieldFocused = false
        
        print("🚀 [EnterPhoneNumberScreen] Fetching user for phone number")
        Task {
            await viewModel.fetch(phoneNumber: trimmed)
        }
    }
    
    private func handleSuccess() {
        print("🎉 [EnterPhoneNumberScreen] Success - userId: \(viewModel.userId ?? "nil")")
        print("📊 [EnterPhoneNumberScreen] Face IDs count: \(viewModel.faceIds.count)")
        
        openMLScan.toggle()
    }
}

#Preview {
    EnterNumberToSearchUserView()
}

