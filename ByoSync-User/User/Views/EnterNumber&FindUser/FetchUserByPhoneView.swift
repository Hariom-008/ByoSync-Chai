// FetchUserByPhoneView.swift

import SwiftUI

struct FetchUserByPhoneView: View {
    @StateObject private var viewModel = FetchUserByPhoneNumberViewModel()
    @StateObject private var userByIdViewModel = UserDataByIdViewModel()
    @State private var phoneNumber: String = ""
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var alertTitle: String = ""
    @State private var navigateToUpdateChai: Bool = false
    @FocusState private var isPhoneFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "person.text.rectangle")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                            .scaleEffect(viewModel.isLoading || userByIdViewModel.isLoading ? 0.8 : 1.0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: viewModel.isLoading)
                        
                        Text("Find User")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Enter phone number to fetch user details")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                    
                    // Phone Number Input Card
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: "phone.fill")
                                .foregroundColor(.blue)
                            
                            TextField("Phone Number", text: $phoneNumber)
                                .keyboardType(.phonePad)
                                .focused($isPhoneFieldFocused)
                                .disabled(viewModel.isLoading || userByIdViewModel.isLoading)
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                        
                        // Fetch Button
                        Button(action: {
                            print("📞 Fetch button tapped for: \(phoneNumber)")
                            isPhoneFieldFocused = false
                            Task {
                                await fetchUser()
                            }
                        }) {
                            HStack {
                                if viewModel.isLoading || userByIdViewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "magnifyingglass")
                                }
                                
                                Text(viewModel.isLoading ? "Fetching User..." : userByIdViewModel.isLoading ? "Checking Chai..." : "Fetch User")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(phoneNumber.isEmpty ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(phoneNumber.isEmpty || viewModel.isLoading || userByIdViewModel.isLoading)
                        .scaleEffect(viewModel.isLoading || userByIdViewModel.isLoading ? 0.95 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.isLoading)
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
                
                // Success Overlay
                if viewModel.userId != nil && !viewModel.isLoading && !userByIdViewModel.isLoading {
                    successOverlay
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK", role: .cancel) {
                    print("❌ Alert dismissed")
                }
            } message: {
                Text(alertMessage)
            }
            .navigationDestination(isPresented: $navigateToUpdateChai) {
                if let id = viewModel.userId {
                    ChaiUpdateView(userId: .constant(id))
                } else {
                    // Fallback UI if somehow navigated without a userId
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.yellow)
                        Text("Missing user ID")
                            .font(.headline)
                        Button("Go Back") {
                            navigateToUpdateChai = false
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            }
            .onAppear {
                print("👀 FetchUserByPhoneView appeared")
            }
        }
    }
    
    // MARK: - Success Overlay
    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    // Dismiss overlay
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                        viewModel.reset()
                        userByIdViewModel.reset()
                        phoneNumber = ""
                    }
                }
            
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
                
                Text("User Found!")
                    .font(.title2)
                    .fontWeight(.bold)
                
                if let user = userByIdViewModel.user {
                    Text("\(user.firstName) \(user.lastName)")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                
                if let message = viewModel.message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    if let userId = viewModel.userId {
                        HStack {
                            Text("User ID:")
                                .fontWeight(.medium)
                            Text(userId)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    
                    HStack {
                        Text("Face Records:")
                            .fontWeight(.medium)
                        Text("\(viewModel.faceIds.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "cup.and.saucer.fill")
                            .foregroundColor(.brown)
                        Text("Chai Count:")
                            .fontWeight(.medium)
                        Text("\(userByIdViewModel.chai)/5")
                            .foregroundColor(userByIdViewModel.chai < 5 ? .green : .red)
                    }
                    
                    HStack {
                        Image(systemName: "dollarsign.circle.fill")
                            .foregroundColor(.green)
                        Text("Wallet:")
                            .fontWeight(.medium)
                        Text("\(Int(userByIdViewModel.wallet)) coins")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
                
                Button(action: {
                    print("✅ Continue button tapped")
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                        viewModel.reset()
                        userByIdViewModel.reset()
                        phoneNumber = ""
                    }
                }) {
                    Text("Continue")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            .padding(32)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(24)
            .shadow(radius: 20)
            .padding(40)
        }
    }
    
    // MARK: - Fetch User
    private func fetchUser() async {
        guard !phoneNumber.isEmpty else {
            print("⚠️ Phone number is empty")
            return
        }
        
        print("🔍 Starting fetch for phone: \(phoneNumber)")
        await viewModel.fetch(phoneNumber: phoneNumber)
        
        // Check for errors
        if let error = viewModel.errorText {
            print("❌ Fetch error: \(error)")
            alertTitle = "Error"
            alertMessage = error
            showAlert = true
            return
        }
        
        // Check if user was found
        guard let userId = viewModel.userId, let deviceKeyHash = viewModel.deviceKeyHash else {
            print("⚠️ User not found")
            alertTitle = "Not Found"
            alertMessage = viewModel.message ?? "User not found with this phone number"
            showAlert = true
            return
        }
        
        print("✅ User found with ID: \(userId)")
        print("📊 Face records: \(viewModel.faceIds.count)")
        print("🔑 DeviceKeyHash: \(deviceKeyHash)")
        
        // Now fetch user details by ID to check chai
        print("🔍 Fetching user details by ID...")
        await userByIdViewModel.fetch(userId: userId, deviceKeyHash: deviceKeyHash)
        
        // Check for errors in fetchUserByID
        if let error = userByIdViewModel.errorText {
            print("❌ FetchUserByID error: \(error)")
            alertTitle = "Error"
            alertMessage = error
            showAlert = true
            return
        }
        
        // Check chai value
        let chaiCount = userByIdViewModel.chai
        print("☕️ User chai count: \(chaiCount)")
        
        if chaiCount <= 5 {
            print("✅ Chai available! Navigating to UpdateChaiView...")
            
            
            // Navigate to UpdateChaiView
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                navigateToUpdateChai = true
            }
        } else {
            print("⚠️ All chai claimed")
            alertTitle = "Chai Limit Reached"
            alertMessage = "You have claimed all your chai! Come back later."
            showAlert = true
            
            // Reset the view
            viewModel.reset()
            userByIdViewModel.reset()
        }
    }
}

#Preview {
    FetchUserByPhoneView()
}
