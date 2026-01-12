import SwiftUI

struct AdminLoginView: View {
    @StateObject private var viewModel = AdminLoginViewModel()
    @Environment(\.dismiss) private var dismiss
    
    @FocusState private var focusedField: Field?
    
    // Animation states
    @State private var showContent = false
    @State private var currentFeature = 0
    
    @State var openDeleteFaceData: Bool = false
    
    // Colors from the logo gradient
    private let logoBlue = Color(red: 0.0, green: 0.0, blue: 1.0)
    private let logoPurple = Color(red: 0.478, green: 0.0, blue: 1.0)
    
    private let features: [(icon: String, title: String, subtitle: String)] = [
        ("lock.shield.fill", "Secure", "Admin access only"),
        ("bolt.fill", "Fast", "Quick authentication"),
        ("checkmark.seal.fill", "Trusted", "Encrypted credentials")
    ]
    
    enum Field {
        case email, password
    }
    
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
            
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 60)
                
                // Logo and title section
                if showContent {
                    logoSection
                        .transition(.scale.combined(with: .opacity))
                }
                
                Spacer()
                
                // Login form section
                if showContent {
                    loginFormSection
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
                    Text("Authenticating…")
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
            print("🔐 [AdminLoginView] appeared")
            
            // Show content with delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 1.0)) {
                    showContent = true
                }
            }
            
            // Auto-focus email field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                focusedField = .email
            }
            
            // Start feature rotation
            Timer.scheduledTimer(withTimeInterval: 3.5, repeats: true) { _ in
                withAnimation(.spring(response: 0.8, dampingFraction: 0.85)) {
                    currentFeature = (currentFeature + 1) % features.count
                }
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
        .onChange(of: viewModel.adminUser) { _, newValue in
            if newValue != nil {
                print("✅ [AdminLoginView] Admin login successful")
                handleSuccess()
            }
        }
        .fullScreenCover(isPresented: $openDeleteFaceData){
            NavigationStack{
                DeleteFaceDatabyNumberView()
            }
        }
    }
    
    // MARK: - Logo Section
    
    private var logoSection: some View {
        VStack(spacing: 0) {
            // Admin icon circle
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 140, height: 140)
                    .shadow(color: .black.opacity(0.1), radius: 12, y: 6)
                
                Image(systemName: "person.badge.key.fill")
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
            
            // Title with gradient
            Text("Admin Login")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [logoBlue, logoPurple],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            Spacer().frame(height: 8)
            
            Text("Administrative access portal")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(Color(red: 0.392, green: 0.455, blue: 0.545))
            
            Spacer().frame(height: 28)
            
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Login Form Section
    
    private var loginFormSection: some View {
        VStack(spacing: 16) {
            // Email field
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: "envelope.fill")
                        .foregroundStyle(
                            LinearGradient(
                                colors: [logoBlue.opacity(0.7), logoPurple.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 20)
                    
                    TextField("Email", text: $viewModel.email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .focused($focusedField, equals: .email)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(red: 0.118, green: 0.161, blue: 0.231))
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .password
                        }
                        .onChange(of: viewModel.email) { _, newValue in
                            print("📧 [AdminLoginView] Email: \(newValue.count) chars")
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
                            focusedField == .email ?
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
            
            // Password field
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(
                            LinearGradient(
                                colors: [logoBlue.opacity(0.7), logoPurple.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 20)
                    
                    SecureField("Password", text: $viewModel.password)
                        .textContentType(.password)
                        .focused($focusedField, equals: .password)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(red: 0.118, green: 0.161, blue: 0.231))
                        .submitLabel(.go)
                        .onSubmit {
                            handleLogin()
                        }
                        .onChange(of: viewModel.password) { _, newValue in
                            print("🔑 [AdminLoginView] Password: \(newValue.count) chars")
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
                            focusedField == .password ?
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
            
            // Login button
            GlassButton(
                text: "Login",
                icon: "",
                isPrimary: true,
                logoBlue: isButtonEnabled ? logoBlue : Color.gray,
                logoPurple: isButtonEnabled ? logoPurple : Color.white
            ) {
                handleLogin()
            }
            .disabled(!isButtonEnabled || viewModel.isLoading)
            .opacity(viewModel.isLoading || !isButtonEnabled ? 0.6 : 1.0)
            
            HStack {
                Text("Admin access is logged and monitored")
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
        let emailValid = !viewModel.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let passwordValid = !viewModel.password.isEmpty
        return emailValid && passwordValid
    }
    
    // MARK: - Actions
    
    private func handleLogin() {
        guard isButtonEnabled else {
            print("⚠️ [AdminLoginView] Login blocked - invalid credentials")
            return
        }
        
        focusedField = nil
        
        print("🚀 [AdminLoginView] Attempting admin login")
        print("📧 [AdminLoginView] Email length: \(viewModel.email.count)")
        print("🔑 [AdminLoginView] Password length: \(viewModel.password.count)")
        
        viewModel.login()
    }
    
    private func handleSuccess() {
        guard let admin = viewModel.adminUser else { return }
        
        print("🎉 [AdminLoginView] Login successful")
        print("👤 [AdminLoginView] Admin user: \(admin)")
        print("💬 [AdminLoginView] Message: \(viewModel.successMessage ?? "none")")
        openDeleteFaceData.toggle()
        // TODO: Navigate to admin dashboard
        // Example:
        // router.navigate(to: .adminDashboard(user: admin))
    }
}

#Preview {
    AdminLoginView()
}
