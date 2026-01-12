import SwiftUI

struct RegisterUserView: View {
    @EnvironmentObject var cryptoService: CryptoManager
    @EnvironmentObject var router: Router
    @StateObject private var viewModel: RegisterUserViewModel
    @Binding var phoneNumber: String
    @EnvironmentObject var faceAuthManager: FaceAuthManager
    
    // Colors matching Android
    private let primaryBlue = Color(hex: "4B548D")
    private let textPrimary = Color(hex: "1F2937")
    private let textSecondary = Color(hex: "6B7280")
    private let borderColor = Color(hex: "E5E7EB")
    private let backgroundColor = Color(hex: "F9FAFB")
    
    init(phoneNumber: Binding<String>) {
        self._phoneNumber = phoneNumber
        _viewModel = StateObject(wrappedValue: RegisterUserViewModel(cryptoService: CryptoManager.shared))
    }
    
    var body: some View {
        ZStack {
            // White background like Android
            Color.white
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header section
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("create_account"))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(primaryBlue)
                    
                    Text(L("join_byosync_start"))
                        .font(.system(size: 15))
                        .foregroundColor(textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 24)
                
                // Form fields in scroll view
                ScrollView {
                    VStack(spacing: 16) {
                        // First Name
                        ModernTextField(
                            value: $viewModel.firstName,
                            label: L("first_name"),
                            keyboardType: .default,
                            primaryBlue: primaryBlue,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            borderColor: borderColor
                        )
                        
                        // Last Name
                        ModernTextField(
                            value: $viewModel.lastName,
                            label: L("last_name"),
                            keyboardType: .default,
                            primaryBlue: primaryBlue,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            borderColor: borderColor
                        )
                        
                        // Email
                        ModernTextField(
                            value: $viewModel.email,
                            label: L("email"),
                            keyboardType: .emailAddress,
                            primaryBlue: primaryBlue,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            borderColor: borderColor
                        )
                        
                        // Phone Number (disabled)
                        DisabledPhoneField(
                            phoneNumber: viewModel.phoneNumber,
                            label: L("phone_number"),
                            primaryBlue: primaryBlue,
                            textSecondary: textSecondary,
                            borderColor: borderColor,
                            backgroundColor: backgroundColor
                        )
                    }
                    .padding(.horizontal, 24)
                }
                
                Spacer()
                
                // Submit Button
                Button(action: {
                    print("🔘 Register button tapped")
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                    faceAuthManager.setRegistrationMode()
                    viewModel.registerUser()
                }) {
                    HStack(spacing: 8) {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.9)
                        } else {
                            Text(L("continue"))
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        (!viewModel.canSubmit || viewModel.isLoading)
                        ? primaryBlue.opacity(0.5)
                        : primaryBlue
                    )
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!viewModel.canSubmit || viewModel.isLoading)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    print("⬅️ Back button tapped")
                    router.pop()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 17))
                    }
                    .foregroundColor(primaryBlue)
                }
            }
        }
        .alert(L("error"), isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {
                print("⚠️ Error alert dismissed")
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
        .onAppear {
            print("👀 RegisterUserView appeared")
            viewModel.phoneNumber = phoneNumber
        }
        .onChange(of: viewModel.navigateToMainTab) { _, newValue in
            if newValue {
                print("✅ navigateToMainTab = true → routing to MainTab")
                router.navigate(to: .mainTab, style: .push)
            }
        }
    }
}

// MARK: - Modern TextField Component

struct ModernTextField: View {
    @Binding var value: String
    let label: String
    let keyboardType: UIKeyboardType
    let primaryBlue: Color
    let textPrimary: Color
    let textSecondary: Color
    let borderColor: Color
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .leading) {
                // Border
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isFocused ? primaryBlue : borderColor, lineWidth: 1)
                    .frame(height: 56)
                
                // Content
                HStack {
                    TextField("", text: $value)
                        .font(.system(size: 16))
                        .foregroundColor(textPrimary)
                        .keyboardType(keyboardType)
                        .autocapitalization(keyboardType == .emailAddress ? .none : .words)
                        .focused($isFocused)
                        .padding(.horizontal, 16)
                        .padding(.top, value.isEmpty && !isFocused ? 0 : 8)
                }
                .frame(height: 56)
                
                // Floating Label
                Text(label)
                    .font(.system(size: value.isEmpty && !isFocused ? 16 : 12))
                    .foregroundColor(isFocused ? primaryBlue : textSecondary)
                    .padding(.horizontal, value.isEmpty && !isFocused ? 16 : 20)
                    .background(
                        (value.isEmpty && !isFocused) ? Color.clear : Color.white
                    )
                    .offset(y: value.isEmpty && !isFocused ? 0 : -28)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isFocused)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: value.isEmpty)
                    .allowsHitTesting(false)
            }
        }
    }
}

// MARK: - Disabled Phone Field Component

struct DisabledPhoneField: View {
    let phoneNumber: String
    let label: String
    let primaryBlue: Color
    let textSecondary: Color
    let borderColor: Color
    let backgroundColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .leading) {
                // Border and Background
                RoundedRectangle(cornerRadius: 14)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(borderColor, lineWidth: 1)
                    )
                    .frame(height: 56)
                
                // Content
                HStack {
                    Text(phoneNumber)
                        .font(.system(size: 16))
                        .foregroundColor(textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                }
                .frame(height: 56)
                
                // Floating Label
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(textSecondary)
                    .padding(.horizontal, 20)
                    .background(
                        Color.white
                            .padding(.horizontal, 4)
                    )
                    .offset(y: -28)
            }
        }
    }
}
