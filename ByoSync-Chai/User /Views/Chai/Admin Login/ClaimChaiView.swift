import SwiftUI

struct ClaimChaiView: View {
    @StateObject private var viewModel = ChaiViewModel()
    @Environment(\.dismiss) private var dismiss
    
    @State private var showChaiDashboard = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    // Animation states
    @State private var showContent = false
    @State private var pulseAnimation = false
    
    @Binding var userId:String
    @Binding var deviceKeyHash:String
    
    let onDone: () -> Void
    
    
    // Colors from the logo gradient
    private let logoBlue = Color(red: 0.0, green: 0.0, blue: 1.0)
    private let logoPurple = Color(red: 0.478, green: 0.0, blue: 1.0)
    private let chaiOrange = Color(red: 0.961, green: 0.576, blue: 0.212)
    private let chaiGold = Color(red: 0.957, green: 0.761, blue: 0.278)
    
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
                  print("🎯 [ClaimChaiView] Background tapped - dismissing any active keyboard")
                  UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
              }
              .ignoresSafeArea(.keyboard, edges: .bottom)
            
            // Animated background blobs
            AnimatedBackgroundBlobs(
                visible: showContent,
                logoBlue: logoBlue,
                logoPurple: logoPurple
            )
            
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 60)
                
                // Chai icon section
                if showContent {
                    chaiIconSection
                        .transition(.scale.combined(with: .opacity))
                }
                
                Spacer()
                
                // Buttons section
                if showContent {
                    buttonsSection
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
                    Text("Processing order…")
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
        .onAppear {
            print("☕ [ClaimChaiView] appeared")
            
            // Force dismiss any keyboard from previous screen
            print("⌨️ [ClaimChaiView] Force dismissing keyboard on appear")
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            
            // Show content with delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 1.0)) {
                    showContent = true
                }
            }
            
            // Start pulse animation
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
        }
        .onChange(of: viewModel.successfullyUpdateChai) { _, success in
            if success {
                print("✅ [ClaimChaiView] Chai order successful")
                handleSuccess()
            }
        }
        .onChange(of: viewModel.lastError) { _, error in
            if let error = error {
                print("❌ [ClaimChaiView] Error: \(error)")
                errorMessage = error
                showErrorAlert = true
            }
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") {
                print("❌ [ClaimChaiView] Error alert dismissed")
            }
        } message: {
            Text(errorMessage)
        }
        .fullScreenCover(isPresented: $showChaiDashboard) {
            ChaiDashBoardView(userId: $userId,deviceKeyHash:$deviceKeyHash, onDone: {
                showChaiDashboard = false
                // Dismiss ClaimChaiView and return to EnterNumberToSearchUserView
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onDone()  // This will dismiss ClaimChaiView
                }
            })
        }
    }
    
    // MARK: - Chai Icon Section
    
    private var chaiIconSection: some View {
        VStack(spacing: 0) {
            // Animated chai cup circle
            ZStack {
                // Outer glow ring
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                chaiOrange.opacity(0.3),
                                chaiOrange.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 60,
                            endRadius: 90
                        )
                    )
                    .frame(width: 180, height: 180)
                    .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                
                // Main circle
                Circle()
                    .fill(Color.white)
                    .frame(width: 140, height: 140)
                    .shadow(color: chaiOrange.opacity(0.3), radius: 20, y: 8)
                
                // Chai cup icon
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [chaiOrange, chaiGold],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .rotationEffect(.degrees(pulseAnimation ? -5 : 5))
            }
            
            Spacer().frame(height: 40)
            
            // Title
            Text("Claim Your Chai")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [logoBlue, logoPurple],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            Spacer().frame(height: 12)
            
            Text("Ready to enjoy a complimentary chai")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(Color(red: 0.392, green: 0.455, blue: 0.545))
                .multilineTextAlignment(.center)
            
            Spacer().frame(height: 32)
            
            // Info card
            HStack(spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [chaiOrange, chaiGold],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Free Chai Offer")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(red: 0.118, green: 0.161, blue: 0.231))
                    
                    Text("Claim your complimentary chai and enjoy it at your convenience")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(Color(red: 0.392, green: 0.455, blue: 0.545))
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(chaiOrange.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(chaiOrange.opacity(0.3), lineWidth: 1)
            )
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Buttons Section
    
    private var buttonsSection: some View {
        VStack(spacing: 16) {
            // Claim Chai button
            Button {
                handleClaimChai()
            } label: {
                HStack(spacing: 12) {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 16, weight: .semibold))
                        
                        Text("Claim Chai")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        colors: [chaiOrange, chaiGold],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: chaiOrange.opacity(0.4), radius: 12, y: 6)
            }
            .disabled(viewModel.isLoading)
            
            // Cancel button
            Button {
                handleCancel()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text("Cancel")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundStyle(
                    LinearGradient(
                        colors: [logoBlue, logoPurple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [logoBlue.opacity(0.3), logoPurple.opacity(0.3)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1.5
                        )
                )
            }
            .disabled(viewModel.isLoading)
            
            Spacer().frame(height: 8)
            
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
    
    // MARK: - Actions
    
    private func handleClaimChai() {
        guard !viewModel.isLoading else {
            print("⚠️ [ClaimChaiView] Already processing")
            return
        }
        
        print("☕ [ClaimChaiView] Claim Chai tapped")
        
        guard !userId.isEmpty else {
            errorMessage = "User not logged in"
            showErrorAlert = true
            return
        }
        
        print("🔑 [ClaimChaiView] User ID: \(userId)")
        
        Task {
            await viewModel.updateChai(userId: userId)
        }
    }
    
    private func handleCancel() {
        print("❌ [ClaimChaiView] Cancel tapped")
        dismiss()
    }
    
    private func handleSuccess() {
        showChaiDashboard.toggle()
        
        // Small delay for smooth transition
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showChaiDashboard = true
        }
    }
}

