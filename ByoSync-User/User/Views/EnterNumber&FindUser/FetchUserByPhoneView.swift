import SwiftUI

struct FetchUserByPhoneView: View {
    @EnvironmentObject var router: Router
    @StateObject private var viewModel = FetchUserByPhoneNumberViewModel()
    
    @State private var phoneNumber: String = "+91"
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var alertTitle: String = ""
    @FocusState private var isPhoneFieldFocused: Bool
    
    var body: some View {
        ZStack {
            // Clean background
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 32) {
                    // Header section
                    VStack(spacing: 16) {
                        // Icon with subtle pulse animation
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 100, height: 100)
                                .scaleEffect(viewModel.isLoading ? 1.1 : 1.0)
                                .opacity(viewModel.isLoading ? 0.5 : 1.0)
                                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: viewModel.isLoading)
                            
                            Image(systemName: "person.text.rectangle.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .blue.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .padding(.top, 20)
                        
                        VStack(spacing: 6) {
                            Text("Find User")
                                .font(.system(size: 32, weight: .bold))
                            
                            Text("Enter phone number to search")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        // Debug info - styled as a subtle badge
                        if let decryptedPhone = CryptoManager.shared.decrypt(encryptedData: "6b3395f74de703c82a0106bf11f6a5a5:77ffbfd0a28865208a35a1a144b6007e") {
                            Text("Debug: \(decryptedPhone)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.top, 40)
                    
                    // Input card
                    VStack(spacing: 20) {
                        // Phone input field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Phone Number")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 12) {
                                Image(systemName: "phone.fill")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 18))
                                
                                TextField("Enter phone number", text: $phoneNumber)
                                    .keyboardType(.phonePad)
                                    .focused($isPhoneFieldFocused)
                                    .disabled(viewModel.isLoading)
                                    .font(.body)
                                
                                if !phoneNumber.isEmpty && phoneNumber != "+91" {
                                    Button {
                                        phoneNumber = "+91"
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding()
                            .background(Color(UIColor.tertiarySystemGroupedBackground))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isPhoneFieldFocused ? Color.blue : Color.clear, lineWidth: 2)
                            )
                        }
                        
                        // Fetch button
                        Button {
                            print("🔍 Fetch button tapped")
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
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                Group {
                                    if phoneNumber.isEmpty || phoneNumber == "+91" || viewModel.isLoading {
                                        Color.secondary.opacity(0.3)
                                    } else {
                                        LinearGradient(
                                            colors: [.blue, .blue.opacity(0.8)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    }
                                }
                            )
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .shadow(color: (phoneNumber.isEmpty || phoneNumber == "+91" || viewModel.isLoading) ? .clear : .blue.opacity(0.3), radius: 8, y: 4)
                        }
                        .disabled(phoneNumber.isEmpty || phoneNumber == "+91" || viewModel.isLoading)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.isLoading)
                    }
                    .padding(24)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
                    .padding(.horizontal, 20)
                    
                    // Help text
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle.fill")
                                .font(.caption)
                            Text("This will fetch the user's ID and device key hash")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 40)
                }
            }
            
            // Success overlay
            if viewModel.userId != nil && !viewModel.isLoading {
                successOverlay
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: viewModel.userId)
    }
    
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
                    Text("User Found!")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Ready to proceed with face scan")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // User info cards
                VStack(spacing: 12) {
                    if let userId = viewModel.userId {
                        InfoRow(icon: "person.fill", title: "User ID", value: userId)
                    }
                    
                    InfoRow(icon: "faceid", title: "Face Records", value: "\(viewModel.faceIds.count)")
                    
                    if let deviceKeyHash = viewModel.deviceKeyHash {
                        InfoRow(icon: "key.fill", title: "Device Key", value: deviceKeyHash)
                    }
                }
                .padding(16)
                .background(Color(UIColor.tertiarySystemGroupedBackground))
                .cornerRadius(16)
                
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
                        HStack {
                            Image(systemName: "camera.fill")
                            Text("Start Face Scan")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [.blue, .blue.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
                    }
                    
                    Button {
                        print("🔄 Dismissed overlay")
                        dismissOverlay()
                    } label: {
                        Text("Cancel")
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
                    .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
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

// Helper view for info rows
struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(10)
    }
}
