import Foundation
import SwiftUI

struct DeleteFaceDatabyNumberView: View {
    @StateObject private var viewModel = AdminDeleteFaceIdViewModel()
    @Environment(\.dismiss) private var dismiss
    
    @State private var phoneNumber: String = ""
    @FocusState private var isPhoneFieldFocused: Bool
    
    
    // Animation states
    @State private var showContent = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var alertMessage = ""
    
    // Colors from the logo gradient
    private let logoBlue = Color(red: 0.0, green: 0.0, blue: 1.0)
    private let logoPurple = Color(red: 0.478, green: 0.0, blue: 1.0)
    private let dangerRed = Color(red: 0.937, green: 0.267, blue: 0.267)
    
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
            if viewModel.state == .loading {
                Color.black.opacity(0.15)
                    .ignoresSafeArea()
                
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Deleting face data…")
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
        .navigationBarHidden(false) // iOS 15-
        .toolbar(.visible, for: .navigationBar) // iOS 16+
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    print("⬅️ [AdminDeleteFaceDataView] Back tapped")
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 16))
                    }
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
            
            // Show content with delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 1.0)) {
                    showContent = true
                }
            }
            
            // Auto-focus phone field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isPhoneFieldFocused = true
            }
        }
        .onChange(of: viewModel.state) { _, newState in
            handleStateChange(newState)
        }
        .alert("Success", isPresented: $showSuccessAlert) {
            Button("OK") {
                print("✅ [AdminDeleteFaceDataView] Success alert dismissed")
                // Reset form
                phoneNumber = ""
                viewModel.reset()
            }
        } message: {
            Text(alertMessage)
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") {
                print("❌ [AdminDeleteFaceDataView] Error alert dismissed")
                viewModel.reset()
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 0) {
            // Warning icon circle
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 140, height: 140)
                    .shadow(color: .black.opacity(0.1), radius: 12, y: 6)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [dangerRed, dangerRed.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            
            Spacer().frame(height: 28)
            
            // Title
            Text("Delete Face Data")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [logoBlue, logoPurple],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            Spacer().frame(height: 8)
            
            Text("This action cannot be undone")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(dangerRed)
            
            Spacer().frame(height: 20)
            
            // Warning card
            HStack(spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(dangerRed)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Admin Action")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(red: 0.118, green: 0.161, blue: 0.231))
                    
                    Text("All face verification data associated with this phone number will be permanently removed")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(Color(red: 0.392, green: 0.455, blue: 0.545))
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(dangerRed.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(dangerRed.opacity(0.3), lineWidth: 1)
            )
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
                            print("📝 [AdminDeleteFaceDataView] Phone: \(newValue.count) chars")
                        }
                        .onChange(of: phoneNumber) { _,newValue in
                        if newValue.count > 10 {
                            phoneNumber = String(newValue.prefix(10))
                        }
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
            
            // Helper text
            HStack(spacing: 4) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 9))
                Text("Enter the user's phone number to delete their face data")
                    .font(.system(size: 10, weight: .regular, design: .rounded))
            }
            .foregroundColor(Color(red: 0.580, green: 0.639, blue: 0.722))
        }
    }
    
    // MARK: - Bottom Section
    
    private var bottomSection: some View {
        VStack(spacing: 10) {
            Spacer().frame(height: 8)
            
            // Delete button
            Button {
                handleDelete()
            } label: {
                HStack(spacing: 12) {
                    if viewModel.state == .loading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 16, weight: .semibold))
                        
                        Text("Delete Face Data")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        colors: isButtonEnabled ? [dangerRed, dangerRed.opacity(0.8)] : [Color.gray.opacity(0.5), Color.gray.opacity(0.3)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: isButtonEnabled ? dangerRed.opacity(0.3) : Color.clear, radius: 12, y: 6)
            }
            .disabled(!isButtonEnabled || viewModel.state == .loading)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isButtonEnabled)
            
            HStack {
                Text("This action is permanent and irreversible")
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundColor(dangerRed)
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
    
    private func handleDelete() {
        let fullPhoneNumber = "+91\(phoneNumber)"
        let trimmed = fullPhoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            print("⚠️ [AdminDeleteFaceDataView] Empty phone number")
            return
        }
        
        isPhoneFieldFocused = false
        
        // Hash the phone number
        let phoneHash = HMACGenerator.generateHMAC(jsonString: trimmed)
        viewModel.deleteFaceId(phoneNumberHash: phoneHash)
    }
    
    private func handleStateChange(_ state: AdminDeleteFaceIdViewModel.UIState) {
        switch state {
        case .idle:
            print("💤 [AdminDeleteFaceDataView] State: idle")
            
        case .loading:
            print("⏳ [AdminDeleteFaceDataView] State: loading")
            
        case .success(let message):
            print("✅ [AdminDeleteFaceDataView] State: success - \(message)")
            alertMessage = message
            showSuccessAlert = true
            
        case .failure(let error):
            print("❌ [AdminDeleteFaceDataView] State: failure - \(error)")
            alertMessage = error
            showErrorAlert = true
        }
    }
}

#Preview {
    NavigationStack {
        DeleteFaceDatabyNumberView()
    }
}
