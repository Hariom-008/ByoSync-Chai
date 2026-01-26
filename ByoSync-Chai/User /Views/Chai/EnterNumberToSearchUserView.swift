import SwiftUI

struct EnterNumberToSearchUserView: View {
    @EnvironmentObject var faceAuthManager: FaceAuthManager
    @StateObject private var viewModel = FetchUserByTokenViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var tokenText: String = ""
    @FocusState private var isTokenFieldFocused: Bool

    @State private var showContent = false
    @State private var currentFeature = 0

    @State var openMLScan: Bool = false
    @State var openChaiClaimView: Bool = false
    @State var openAdminLoginView: Bool = false
    @State var openFindTokenView: Bool = false
    @State var openRegisterChaiView: Bool = false
    
    @State private var fetchTask: Task<Void, Never>?

    private let logoBlue = Color(red: 0.0, green: 0.0, blue: 1.0)
    private let logoPurple = Color(red: 0.478, green: 0.0, blue: 1.0)

    private let features: [(icon: String, title: String, subtitle: String)] = [
        ("lock.fill", "Secure", "Encrypted communication"),
        ("bolt.fill", "Fast", "Quick verification"),
        ("checkmark.seal.fill", "Verified", "Real-time validation")
    ]

    var body: some View {
        ZStack {
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
            .onTapGesture {
                print("🎯 [EnterTokenScreen] Background tapped - dismissing keyboard")
                isTokenFieldFocused = false
            }

            AnimatedBackgroundBlobs(
                visible: showContent,
                logoBlue: logoBlue,
                logoPurple: logoPurple
            )

            VStack(spacing: 0) {
                Spacer().frame(height: 60)

                if showContent {
                    logoSection
                        .transition(.scale.combined(with: .opacity))
                }

                Spacer()

                if showContent {
                    tokenInputSection
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer()

                if showContent {
                    bottomSection
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)

            if viewModel.isLoading {
                Color.black.opacity(0.15)
                    .ignoresSafeArea()

                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Verifying token…")
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
            print("🔢 [EnterTokenScreen] appeared")

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 1.0)) {
                    showContent = true
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTokenFieldFocused = true
            }

            Timer.scheduledTimer(withTimeInterval: 3.5, repeats: true) { _ in
                withAnimation(.spring(response: 0.8, dampingFraction: 0.85)) {
                    currentFeature = (currentFeature + 1) % features.count
                }
            }
        }
        .onDisappear {
            print("👋 [EnterTokenScreen] disappeared - cancelling fetch task")
            fetchTask?.cancel()
            fetchTask = nil
        }
        .alert("Error", isPresented: .constant(viewModel.errorText != nil)) {
            Button("OK") { viewModel.reset() }
        } message: {
            if let error = viewModel.errorText { Text(error) }
        }
        .onChange(of: viewModel.fetchCompleted) { _, completed in
            guard completed else { return }
            handleFetchCompletedBackup()
        }
        .navigationDestination(isPresented: $openMLScan) {
            MLScanView(
                onDone: {
                    print("✅ [EnterTokenScreen] MLScan completed")
                    openMLScan = false
                    DispatchQueue.main.async { openChaiClaimView = true }
                },
                userId: viewModel.userId ?? "",
                deviceKeyHash: viewModel.deviceKeyHash ?? "",
                token: viewModel.token
            )
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
                    print("✅ [EnterTokenScreen] ClaimChai completed")
                    openChaiClaimView = false
                }
            )
        }
        .navigationDestination(isPresented: $openAdminLoginView) {
            AdminLoginView()
        }
        .sheet(isPresented: $openFindTokenView) {
            FindTokenByPhoneView()
        }
        .fullScreenCover(isPresented: $openRegisterChaiView) {
            RegisterChaiView()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    print("📝 [EnterTokenScreen] Register button tapped")
                    openRegisterChaiView.toggle()
                } label: {
                    Text("Register")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        print("🔍 [EnterTokenScreen] Opening Find Token view")
                        openFindTokenView = true
                    } label: {
                        Label("Find Token", systemImage: "magnifyingglass")
                    }
                    
                    Button {
                        print("👤 [EnterTokenScreen] Opening Admin Login")
                        openAdminLoginView = true
                    } label: {
                        Label("Admin Login", systemImage: "person.circle")
                    }
                } label: {
                    Text("More")
                        .font(.system(size: 16, weight: .medium))
                }
            }
            
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button {
                    print("✅ [EnterTokenScreen] Keyboard Done button tapped")
                    isTokenFieldFocused = false
                } label: {
                    Text("Done")
                        .font(.system(size: 16, weight: .semibold))
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
    }

    private var logoSection: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 140, height: 140)
                    .shadow(color: .black.opacity(0.1), radius: 12, y: 6)

                Image(systemName: "number.circle.fill")
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

            Text("Enter Token")
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

    private var tokenInputSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "number")
                        .foregroundStyle(
                            LinearGradient(
                                colors: [logoBlue.opacity(0.7), logoPurple.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 20)

                    TextField("Token (numbers only)", text: $tokenText)
                        .keyboardType(.numberPad)
                        .focused($isTokenFieldFocused)
                        .textContentType(.oneTimeCode)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(red: 0.118, green: 0.161, blue: 0.231))
                        .onChange(of: tokenText) { _, newValue in
                            let digitsOnly = newValue.filter(\.isNumber)
                            if digitsOnly != newValue { tokenText = digitsOnly }
                            if tokenText.count > 8 { tokenText = String(tokenText.prefix(8)) }
                        }
                        .submitLabel(.done)
                        .onSubmit {
                            print("⌨️ [EnterTokenScreen] TextField submit pressed")
                            isTokenFieldFocused = false
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
                            isTokenFieldFocused ?
                            LinearGradient(
                                colors: [logoBlue, logoPurple],
                                startPoint: .leading,
                                endPoint: .trailing
                            ) :
                            LinearGradient(colors: [Color.clear, Color.clear], startPoint: .leading, endPoint: .trailing),
                            lineWidth: 2
                        )
                )
            }
        }
    }

    private var bottomSection: some View {
        VStack(spacing: 10) {
            Spacer().frame(height: 8)

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

    private var isButtonEnabled: Bool {
        let enabled = Int(tokenText.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
        return enabled
    }

    private func handleProceed() {
        print("🔘 [EnterTokenScreen] Proceed button tapped")
        
        let trimmed = tokenText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let token = Int(trimmed) else {
            print("⚠️ [EnterTokenScreen] Invalid token: '\(trimmed)'")
            return
        }

        print("🚀 [EnterTokenScreen] Starting fetch for token: \(token)")
        
        fetchTask?.cancel()
        
        fetchTask = Task { @MainActor in
            print("📱 [EnterTokenScreen] Task started - dismissing keyboard")
            isTokenFieldFocused = false
            
            await viewModel.fetch(token: token)
            
            print("✅ [EnterTokenScreen] Fetch completed in Task")
            print("📊 userId: \(viewModel.userId ?? "nil")")
            print("📊 errorText: \(viewModel.errorText ?? "nil")")
            
            guard viewModel.userId != nil, viewModel.errorText == nil else {
                print("⚠️ [EnterTokenScreen] Fetch completed but no userId or has error")
                return
            }
            
            print("🎯 [EnterTokenScreen] Valid fetch - preparing navigation")
            
            if viewModel.faceIds.isEmpty {
                print("📸 No face data - Registration mode")
                faceAuthManager.setRegistrationMode()
            } else {
                print("🔐 Face data exists - Verification mode")
                faceAuthManager.setVerificationMode()
            }
            
            try? await Task.sleep(nanoseconds: 100_000_000)
            
            print("🚀 [EnterTokenScreen] Setting openMLScan = true")
            openMLScan = true
        }
    }

    private func handleFetchCompletedBackup() {
        print("🔄 [EnterTokenScreen] handleFetchCompletedBackup (onChange backup)")
        
        guard viewModel.userId != nil, viewModel.errorText == nil, !openMLScan else {
            print("⏭️ [EnterTokenScreen] Backup skipped - already handled or error present")
            return
        }
        
        print("🎯 [EnterTokenScreen] Backup navigation triggered")
        
        if viewModel.faceIds.isEmpty {
            faceAuthManager.setRegistrationMode()
        } else {
            faceAuthManager.setVerificationMode()
        }
        
        openMLScan = true
    }
}

#Preview {
    EnterNumberToSearchUserView()
}
