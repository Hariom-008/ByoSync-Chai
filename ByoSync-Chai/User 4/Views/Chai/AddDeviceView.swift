import SwiftUI

struct AddDeviceView: View {
    @StateObject private var viewModel = AddDeviceViewModel()
    
    @EnvironmentObject var faceAuthManager: FaceAuthManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var deviceName: String = ""
    @FocusState private var isDeviceNameFocused: Bool
    
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var alertMessage = ""
    @State private var successDeviceId: String? = nil // Store device ID for keychain save
    
    // Animation states
    @State private var showContent = false
    
    @State var openEnterNumberToFetchUser:Bool = false
    
    // Colors from the logo gradient
    private let logoBlue = Color(red: 0.0, green: 0.0, blue: 1.0)
    private let logoPurple = Color(red: 0.478, green: 0.0, blue: 1.0)
    
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
                
                // Header section
                if showContent {
                    headerSection
                        .transition(.scale.combined(with: .opacity))
                }
                
                Spacer()
                
                // Device name input section
                if showContent {
                    deviceNameInputSection
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
            if viewModel.state == .loading {
                Color.black.opacity(0.15)
                    .ignoresSafeArea()
                
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Adding device…")
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
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .fullScreenCover(isPresented: $openEnterNumberToFetchUser){
            EnterNumberToSearchUserView()
        }
        .onAppear {
            print("📱 [AddDeviceView] appeared")
            
            // Show content with delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 1.0)) {
                    showContent = true
                }
            }
            
            // Auto-focus device name field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isDeviceNameFocused = true
            }
        }
        .onChange(of: viewModel.state) { _, newState in
            handleStateChange(newState)
        }
        .alert("Success", isPresented: $showSuccessAlert) {
            Button("OK") {
                print("✅ [AddDeviceView] Success alert dismissed")
                
                // Save to keychain now (triggers navigation)
                if let deviceId = successDeviceId {
                    print("💾 [AddDeviceView] Saving device ID to keychain: \(deviceId)")
                    KeychainHelper.shared.save(deviceId, forKey: "chaiDeviceId")
                    print("🚀 [AddDeviceView] Navigation to EnterNumberToSearchUserView will occur now")
                }
                
                deviceName = ""
                successDeviceId = nil
                viewModel.reset()
            }
        } message: {
            Text(alertMessage)
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") {
                print("❌ [AddDeviceView] Error alert dismissed")
                viewModel.reset()
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 0) {
            // Device icon circle
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 140, height: 140)
                    .shadow(color: .black.opacity(0.1), radius: 12, y: 6)
                
                Image(systemName: "plus.circle.fill")
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
            
            // Title
            Text("Add Device")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [logoBlue, logoPurple],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            Spacer().frame(height: 8)
            
            Text("Register a new device")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(Color(red: 0.392, green: 0.455, blue: 0.545))
            
            Spacer().frame(height: 20)
            
            // Info card
            HStack(spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [logoBlue, logoPurple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Device Registration")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(red: 0.118, green: 0.161, blue: 0.231))
                    
                    Text("Enter a unique name to identify this device in your account")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(Color(red: 0.392, green: 0.455, blue: 0.545))
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(logoBlue.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(logoBlue.opacity(0.2), lineWidth: 1)
            )
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Device Name Input Section
    
    private var deviceNameInputSection: some View {
        VStack(spacing: 12) {
            // Device name input
            HStack(spacing: 12) {
                Image(systemName: "iphone")
                    .foregroundStyle(
                        LinearGradient(
                            colors: [logoBlue.opacity(0.7), logoPurple.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 20)
                
                TextField("Device name", text: $deviceName)
                    .textContentType(.name)
                    .autocapitalization(.words)
                    .focused($isDeviceNameFocused)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(red: 0.118, green: 0.161, blue: 0.231))
                    .submitLabel(.done)
                    .onSubmit {
                        handleAddDevice()
                    }
                    .onChange(of: deviceName) { _, newValue in
                        print("📝 [AddDeviceView] Device name: \(newValue.count) chars")
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
                        isDeviceNameFocused ?
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
    
    // MARK: - Bottom Section
    
    private var bottomSection: some View {
        VStack(spacing: 10) {
            Spacer().frame(height: 8)
            
            // Add Device button
            GlassButton(
                text: "Add Device",
                icon: "plus.circle.fill",
                isPrimary: true,
                logoBlue: isButtonEnabled ? logoBlue : Color.gray,
                logoPurple: isButtonEnabled ? logoPurple : Color.white
            ) {
                handleAddDevice()
            }
            .disabled(!isButtonEnabled || viewModel.state == .loading)
            .opacity(viewModel.state == .loading || !isButtonEnabled ? 0.6 : 1.0)
            
            HStack {
                Text("Device will be registered securely")
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
        !deviceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Actions
    
    private func handleAddDevice() {
        let trimmed = deviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            print("⚠️ [AddDeviceView] Empty device name")
            return
        }
        
        isDeviceNameFocused = false
        
        print("🚀 [AddDeviceView] Adding device")
        print("📱 [AddDeviceView] Device name: \(trimmed)")
        
        // Get device key
        let deviceKey = DeviceIdentity.resolve()
        guard !deviceKey.isEmpty else {
            print("❌ [AddDeviceView] Failed to resolve device key")
            alertMessage = "Failed to resolve device key"
            showErrorAlert = true
            return
        }
        
        print("🔑 [AddDeviceView] Device key resolved")
        
        // Hash device key
        let deviceKeyHash = HMACGenerator.generateHMAC(jsonString: deviceKey)
        print("🔐 [AddDeviceView] Device key hash generated")
        
        // Optional device data
        let deviceData: [String: AnyEncodable] = [
            "platform": AnyEncodable("iOS"),
            "model": AnyEncodable(UIDevice.current.model),
            "systemVersion": AnyEncodable(UIDevice.current.systemVersion)
        ]
        
        print("📊 [AddDeviceView] Device data: \(deviceData)")
        
        viewModel.addDevice(
            deviceKey: deviceKey,
            deviceKeyHash: deviceKeyHash,
            deviceName: trimmed,
            deviceData: deviceData
        )
    }
    
    private func handleStateChange(_ state: AddDeviceViewModel.State) {
        switch state {
        case .idle:
            print("💤 [AddDeviceView] State: idle")
            
        case .loading:
            print("⏳ [AddDeviceView] State: loading")
            
        case .success(let message, let deviceId):
            print("✅ [AddDeviceView] State: success - \(message)")
            print("🆔 [AddDeviceView] Device ID received: \(deviceId)")
            print("⏸️ [AddDeviceView] Device ID stored temporarily, will save to keychain after alert dismissal")
            
            successDeviceId = deviceId
//            alertMessage = message
           // showSuccessAlert = true
            
            openEnterNumberToFetchUser.toggle()
            
        case .failure(let message):
            print("❌ [AddDeviceView] State: failure - \(message)")
            alertMessage = message
            showErrorAlert = true
        }
    }
}

#Preview {
    NavigationStack {
        AddDeviceView()
    }
}
