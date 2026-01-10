import SwiftUI

struct FetchUserByPhoneView: View {
    @EnvironmentObject var router: Router
    @StateObject private var viewModel = FetchUserByPhoneNumberViewModel()
    
    @State private var phoneNumber: String = "+91"
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var alertTitle: String = ""
    @FocusState private var isPhoneFieldFocused: Bool
    
    @State var openAdminPanel: Bool = false
    @State private var showContent = false
    
    // Colors from the logo gradient (matching AuthenticationView)
    private let logoBlue = Color(red: 0.0, green: 0.0, blue: 1.0)
    private let logoPurple = Color(red: 0.478, green: 0.0, blue: 1.0)
    
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
                
                if showContent {
                    headerSection
                        .transition(.scale.combined(with: .opacity))
                    
                    Spacer()
                        .frame(height: 32)
                    
                    inputSection
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    
                    Spacer()
                    
                    bottomSection
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
            
            // Success overlay
            if viewModel.userId != nil && !viewModel.isLoading {
                successOverlay
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .navigationDestination(isPresented: $openAdminPanel) {
            AdminLoginView()
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: viewModel.userId)
        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: showContent)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    print("🔧 Admin button tapped")
                    openAdminPanel.toggle()
                } label: {
                    Text("Admin")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [logoBlue, logoPurple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
            }
        }
        .onAppear {
            print("📱 FetchUserByPhoneView appeared")
            
            // Show content with delay for smooth animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 1.0)) {
                    showContent = true
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 0) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 120, height: 120)
                    .shadow(color: .black.opacity(0.1), radius: 12, y: 6)
                
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [logoBlue.opacity(0.1), logoPurple.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .scaleEffect(viewModel.isLoading ? 1.1 : 1.0)
                        .opacity(viewModel.isLoading ? 0.5 : 1.0)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: viewModel.isLoading)
                    
                    Image(systemName: "person.text.rectangle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [logoBlue, logoPurple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            
            Spacer().frame(height: 24)
            
            // Title with logo gradient
            Text("Find User")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [logoBlue, logoPurple],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            Spacer().frame(height: 8)
            
            Text("Enter phone number to search")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(Color(red: 0.392, green: 0.455, blue: 0.545))
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Input Section
    
    private var inputSection: some View {
        VStack(spacing: 20) {
            // Phone input field
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "phone.fill")
                        .foregroundStyle(
                            LinearGradient(
                                colors: [logoBlue, logoPurple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .font(.system(size: 18))
                    
                    TextField("Enter phone number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .focused($isPhoneFieldFocused)
                        .disabled(viewModel.isLoading)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(red: 0.118, green: 0.161, blue: 0.231))
                    
                    if !phoneNumber.isEmpty && phoneNumber != "+91" {
                        Button {
                            print("🗑️ Clearing phone number")
                            phoneNumber = "+91"
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Color(red: 0.580, green: 0.639, blue: 0.722))
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
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
                            ) : LinearGradient(
                                colors: [.clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 2
                        )
                )
            }
            
            // Fetch button
            Button {
                print("🔍 Fetch button tapped with phone: \(phoneNumber)")
                isPhoneFieldFocused = false
                Task { await fetchUser() }
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)
                    } else {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    
                    Text(viewModel.isLoading ? "Searching..." : "Find User")
                        .font(.system(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Group {
                        if phoneNumber.isEmpty || phoneNumber == "+91" || viewModel.isLoading {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(red: 0.580, green: 0.639, blue: 0.722).opacity(0.3))
                        } else {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: [logoBlue, logoPurple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .shadow(color: logoBlue.opacity(0.3), radius: 12, y: 6)
                        }
                    }
                )
                .foregroundColor(.white)
            }
            .disabled(phoneNumber.isEmpty || phoneNumber == "+91" || viewModel.isLoading)
            .animation(.spring(response: 0.5, dampingFraction: 0.75), value: viewModel.isLoading)
            
            // Help text
            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 10))
                Text("This will help us locate whether you exist or not!")
                    .font(.system(size: 10, weight: .regular, design: .rounded))
            }
            .foregroundColor(Color(red: 0.580, green: 0.639, blue: 0.722))
        }
    }
    
    // MARK: - Bottom Section (matching AuthenticationView)
    
    private var bottomSection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Your data is encrypted and secure")
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundColor(Color(red: 0.580, green: 0.639, blue: 0.722))
                    .multilineTextAlignment(.center)
                
                // Policy link button
                Link(destination: URL(string: "https://www.byosync.com/policy")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 9))
                        Text("Privacy Policy")
                            .font(.system(size: 10, weight: .medium))
                            .underline()
                    }
                    .foregroundStyle(
                        LinearGradient(
                            colors: [logoBlue, logoPurple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .padding(.vertical, 4)
                }
                .onTapGesture {
                    print("🔗 Opening Privacy Policy at https://www.byosync.com/policy")
                }
            }
            
            HStack {
                Text("powered by")
                    .font(.system(size: 8))
                    .foregroundColor(Color(red: 0.580, green: 0.639, blue: 0.722))
                    .multilineTextAlignment(.center)
                Text("KAVION")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(red: 0.580, green: 0.639, blue: 0.722))
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Success Overlay
    
    private var successOverlay: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    print("🎯 Overlay dismissed by tap")
                    dismissOverlay()
                }
            
            // Success card
            VStack(spacing: 24) {
                // Success icon with animation
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green, .green.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .scaleEffect(1.0)
                .animation(.spring(response: 0.6, dampingFraction: 0.6), value: viewModel.userId)
                
                VStack(spacing: 8) {
                    Text("We Found You!")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [logoBlue, logoPurple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text("Ready to proceed with face scan")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(Color(red: 0.392, green: 0.455, blue: 0.545))
                }
                
                // User info cards
                VStack(spacing: 12) {
                    if let userId = viewModel.userId {
                        InfoRow(icon: "person.fill", title: "User ID", value: userId, logoBlue: logoBlue, logoPurple: logoPurple)
                    }
                    
                    InfoRow(icon: "faceid", title: "Face Records", value: "\(viewModel.faceIds.count)", logoBlue: logoBlue, logoPurple: logoPurple)
                    
                    if let deviceKeyHash = viewModel.deviceKeyHash {
                        InfoRow(icon: "key.fill", title: "Device Key", value: deviceKeyHash, logoBlue: logoBlue, logoPurple: logoPurple)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                )
                
                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        print("✅ Starting face scan")
                        guard let userId = viewModel.userId,
                              let deviceKeyHash = viewModel.deviceKeyHash else {
                            print("❌ Missing userId or deviceKeyHash")
                            return
                        }
                        
                        router.navigate(to: .mlScan(userId: userId, deviceKeyHash: deviceKeyHash))
                        dismissOverlay()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "camera.fill")
                            Text("Start Face Scan")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: [logoBlue, logoPurple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .shadow(color: logoBlue.opacity(0.3), radius: 12, y: 6)
                        )
                        .foregroundColor(.white)
                    }
                    
                    Button {
                        print("🔄 Dismissed overlay")
                        dismissOverlay()
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 15, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundColor(Color(red: 0.580, green: 0.639, blue: 0.722))
                    }
                }
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
            )
            .padding(.horizontal, 32)
        }
    }
    
    private func dismissOverlay() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
            viewModel.reset()
            phoneNumber = "+91"
        }
    }
    
    private func fetchUser() async {
        guard !phoneNumber.isEmpty else {
            print("❌ Phone number is empty")
            return
        }
        
        print("📞 Fetching user with phone: \(phoneNumber)")
        await viewModel.fetch(phoneNumber: phoneNumber)
        
        if let error = viewModel.errorText {
            print("❌ Error fetching user: \(error)")
            alertTitle = "Error"
            alertMessage = error
            showAlert = true
            return
        }
        
        guard viewModel.userId != nil, viewModel.deviceKeyHash != nil else {
            print("⚠️ User not found for phone: \(phoneNumber)")
            alertTitle = "Not Found"
            alertMessage = viewModel.message ?? "User not found with this phone number"
            showAlert = true
            return
        }
        
        print("✅ User found successfully - ID: \(viewModel.userId ?? "nil")")
    }
}

// MARK: - Helper view for info rows (Updated)

struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    let logoBlue: Color
    let logoPurple: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(
                    LinearGradient(
                        colors: [logoBlue, logoPurple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(Color(red: 0.580, green: 0.639, blue: 0.722))
                
                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(red: 0.118, green: 0.161, blue: 0.231))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.5))
        )
    }
}
