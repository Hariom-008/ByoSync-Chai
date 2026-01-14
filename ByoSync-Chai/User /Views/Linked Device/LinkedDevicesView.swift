import SwiftUI

struct LinkedDevicesView: View {
    @StateObject private var viewModel: LinkedDevicesViewModel
    @ObservedObject private var userSession = UserSession.shared
    @Namespace private var animation
    
    // Alert states
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showUnlinkConfirm = false
    @State private var deviceToUnlink: GetDeviceData?
    
    // MARK: - Initialization with Dependency Injection
    init(repository: UserDevicesRepository = UserDevicesRepository()) {
        _viewModel = StateObject(wrappedValue: LinkedDevicesViewModel(repository: repository))
        print("🏗️ [VIEW] LinkedDevicesView initialized")
    }
    
    private var sessionProvider: SessionProvider {
        SessionProvider(userSession: userSession)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if viewModel.isLoading && viewModel.devices.isEmpty {
                    ProgressView()

                } else if viewModel.devices.isEmpty && !viewModel.isLoading {
                    emptyStateView
                } else {
                    deviceListView
                }
                
                // Floating refresh indicator
                if viewModel.isLoading && !viewModel.devices.isEmpty {
                    floatingLoadingIndicator
                }
            }
            .navigationTitle("Devices")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                print("📱 [VIEW] LinkedDevicesView appeared")
                viewModel.fetchUserDevices()
            }
            .refreshable {
                HapticManager.impact(style: .light)
                await viewModel.fetchUserDevices()
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
            .alert("Unlink Device?", isPresented: $showUnlinkConfirm) {
                Button("Cancel", role: .cancel) {
                    HapticManager.impact(style: .light)
                }
                Button("Unlink", role: .destructive) {
                    HapticManager.notification(type: .warning)
                    if let device = deviceToUnlink {
                        print("🔗 [VIEW] Unlinking device: \(device.deviceName)")
                        viewModel.unlinkOtherDevice(deviceId: device.id)
                    }
                }
            } message: {
                if let device = deviceToUnlink {
                    Text("'\(device.deviceName)' will be removed. You'll need to sign in again on that device.")
                }
            }
            // ✅ Use onChange to react to success/error messages
            .onChange(of: viewModel.successMessage) { oldValue, newValue in
                if let message = newValue, !message.isEmpty {
                    print("✅ [VIEW] Success message received: \(message)")
                    HapticManager.notification(type: .success)
                    showMessageAlert(title: "Success", message: message)
                    // Clear the message after showing
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        viewModel.successMessage = nil
                    }
                }
            }
            .onChange(of: viewModel.errorMessage) { oldValue, newValue in
                if let message = newValue, !message.isEmpty {
                    print("❌ [VIEW] Error message received: \(message)")
                    HapticManager.notification(type: .error)
                    showMessageAlert(title: "Error", message: message)
                    // Clear the message after showing
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        viewModel.errorMessage = nil
                    }
                }
            }
        }
    }
    
    // MARK: - Device List View
    private var deviceListView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Current Device Hero Section
                if let currentDevice = viewModel.devices.first(where: { sessionProvider.isCurrentDevice($0) }) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("This Device")
                                .font(.title3)
                                .fontWeight(.bold)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        
                        CurrentDeviceHeroCard(
                            device: currentDevice,
                            isPrimary: currentDevice.isPrimary
                        )
                        .padding(.horizontal, 20)
                    }
                }
                
                // Other Devices Section
                let otherDevices = viewModel.devices.filter { !sessionProvider.isCurrentDevice($0) }
                if !otherDevices.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Other Devices")
                                .font(.title3)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            Text("\(otherDevices.count)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(minWidth: 28, minHeight: 28)
                                .background(
                                    Circle()
                                        .fill(Color.blue)
                                )
                        }
                        .padding(.horizontal, 20)
                        
                        VStack(spacing: 12) {
                            ForEach(otherDevices) { device in
                                OtherDeviceCard(
                                    device: device,
                                    isThisDevicePrimary: sessionProvider.isThisDevicePrimary(),
                                    onMakePrimary: {
                                        HapticManager.impact(style: .medium)
                                        print("🔄 [VIEW] Making device primary: \(device.deviceName)")
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                            viewModel.changePrimaryDevice(to: device.id)
                                        }
                                    },
                                    onUnlink: {
                                        HapticManager.impact(style: .light)
                                        print("🔗 [VIEW] Preparing to unlink device: \(device.deviceName)")
                                        deviceToUnlink = device
                                        showUnlinkConfirm = true
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                
                // Info Card
                SecurityInfoCard()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
            .padding(.vertical, 20)
        }
    }
    
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            ZStack {
                // Animated circles
                ForEach(0..<3) { index in
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 140 + CGFloat(index * 40), height: 140 + CGFloat(index * 40))
                        .opacity(0.3 - Double(index) * 0.1)
                }
                
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 140, height: 140)
                    
                    Image(systemName: "iphone.and.ipad")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                }
            }
            .frame(height: 220)
            
            VStack(spacing: 12) {
                Text("No Devices Yet")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Sign in on other devices to see them here.\nManage and secure all your devices from one place.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Floating Loading Indicator
    private var floatingLoadingIndicator: some View {
        VStack {
            HStack(spacing: 12) {
                ProgressView()
                    .tint(.white)
                Text("Updating...")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "4B548D")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
            )
            .shadow(color: .black.opacity(0.2), radius: 15, y: 8)
            
            Spacer()
        }
        .padding(.top, 16)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    // MARK: - Helper Methods
    private func showMessageAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}

#Preview {
    LinkedDevicesView()
}
