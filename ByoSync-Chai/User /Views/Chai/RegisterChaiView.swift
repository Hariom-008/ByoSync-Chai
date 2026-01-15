import SwiftUI

struct RegisterChaiView: View {
    @StateObject private var viewModel = RegisterFromChaiAppViewModel()
    @Environment(\.dismiss) private var dismiss
    
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var email: String = ""
    @State private var phoneNumber: String = ""
    @State var openMLScan:Bool = false
    
    @FocusState private var focusedField: Field?
    
    enum Field: Hashable {
        case firstName, lastName, email, phoneNumber
    }
    
    // Colors matching the main app theme
    private let logoBlue = Color(red: 0.0, green: 0.0, blue: 1.0)
    private let logoPurple = Color(red: 0.478, green: 0.0, blue: 1.0)
    
    var body: some View {
        NavigationView {
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
                
                ScrollView {
                    VStack(spacing: 28) {
                        Spacer().frame(height: 20)
                        
                        // Header with icon
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 80, height: 80)
                                    .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
                                
                                Image(systemName: "person.crop.circle.fill.badge.plus")
                                    .font(.system(size: 40))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [logoBlue, logoPurple],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            }
                            
                            Text("Register New User")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [logoBlue, logoPurple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            
                            Text("Fill in the details to create account")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        
                        // Form Fields
                        VStack(spacing: 16) {
                            // First Name
                            InputField(
                                title: "First Name",
                                placeholder: "Enter first name",
                                text: $firstName,
                                icon: "person.fill",
                                isSecure: false,
                                keyboardType: UIKeyboardType.alphabet,
                                focusedField: $focusedField,
                                field: .firstName,
                                logoBlue: logoBlue,
                                logoPurple: logoPurple,
                                isDisabled: viewModel.isLoading
                            )
                            
                            // Last Name
                            InputField(
                                title: "Last Name",
                                placeholder: "Enter last name",
                                text: $lastName,
                                icon: "person.fill",
                                isSecure: false,
                                keyboardType: .default,
                                focusedField: $focusedField,
                                field: .lastName,
                                logoBlue: logoBlue,
                                logoPurple: logoPurple,
                                isDisabled: viewModel.isLoading
                            )
                            
                            // Email
                            InputField(
                                title: "Email",
                                placeholder: "Enter email address",
                                text: $email,
                                icon: "envelope.fill",
                                isSecure: false,
                                keyboardType: .emailAddress,
                                focusedField: $focusedField,
                                field: .email,
                                logoBlue: logoBlue,
                                logoPurple: logoPurple,
                                isDisabled: viewModel.isLoading
                            )
                            .textInputAutocapitalization(.never)
                            
                            // Phone Number with +91
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Phone Number")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 4)
                                
                                HStack(spacing: 12) {
                                    // Country code
                                    HStack(spacing: 6) {
                                        Image(systemName: "globe")
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                        
                                        Text("+91")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(Color(red: 0.118, green: 0.161, blue: 0.231))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 14)
                                    .background(Color(.systemGray5))
                                    .cornerRadius(12)
                                    
                                    // Phone input
                                    HStack(spacing: 8) {
                                        Image(systemName: "phone.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                        
                                        TextField("10-digit number", text: $phoneNumber)
                                            .keyboardType(.numberPad)
                                            .focused($focusedField, equals: .phoneNumber)
                                            .disabled(viewModel.isLoading)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(Color(red: 0.118, green: 0.161, blue: 0.231))
                                            .onChange(of: phoneNumber) { _, newValue in
                                                let digitsOnly = newValue.filter(\.isNumber)
                                                if digitsOnly != newValue { phoneNumber = digitsOnly }
                                                if phoneNumber.count > 10 { phoneNumber = String(phoneNumber.prefix(10)) }
                                            }
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 14)
                                    .background(Color.white)
                                    .cornerRadius(12)
                                    .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(
                                                focusedField == .phoneNumber ?
                                                LinearGradient(
                                                    colors: [logoBlue, logoPurple],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                ) :
                                                LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing),
                                                lineWidth: 2
                                            )
                                    )
                                }
                                
                                if !phoneNumber.isEmpty {
                                    Text("\(phoneNumber.count)/10 digits")
                                        .font(.system(size: 11))
                                        .foregroundColor(phoneNumber.count == 10 ? .green : .secondary)
                                        .padding(.leading, 4)
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        // Success Message
                        if let user = viewModel.newUser {
                            VStack(spacing: 16) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.green)
                                
                                VStack(spacing: 8) {
                                    Text("Registration Successful!")
                                        .font(.system(size: 18, weight: .bold))
                                    
                                    Text("Token: \(user.token)")
                                        .font(.system(size: 24, weight: .bold, design: .rounded))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [logoBlue, logoPurple],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                    
                                    Text("User ID: \(user.id)")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                
                                if let message = viewModel.message {
                                    Text(message)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                            }
                            .padding(24)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white)
                                    .shadow(color: .green.opacity(0.2), radius: 12, y: 6)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
                            )
                            .padding(.horizontal, 24)
                            .transition(.scale.combined(with: .opacity))
                        }
                        
                        // Error Message
                        if let error = viewModel.errorText {
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.red)
                                
                                Text(error)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(20)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white)
                                    .shadow(color: .red.opacity(0.2), radius: 12, y: 6)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                            )
                            .padding(.horizontal, 24)
                            .transition(.scale.combined(with: .opacity))
                        }
                        
                        Spacer().frame(height: 20)
                    }
                    .padding(.top, 16)
                }
                .scrollDismissesKeyboard(.interactively)
                
                // Register Button at bottom
                VStack {
                    Spacer()
                    
                    Button(action: {
                        #if DEBUG
                        print("📝 [RegisterUserView] Register button tapped")
                        print("   First: \(firstName)")
                        print("   Last: \(lastName)")
                        print("   Email: \(email)")
                        print("   Phone: +91\(phoneNumber)")
                        #endif
                        
                        focusedField = nil
                        
                        let fullPhoneNumber = "+91\(phoneNumber)"
                        Task {
                            await viewModel.register(
                                firstName: firstName,
                                lastName: lastName,
                                email: email,
                                phoneNumber: fullPhoneNumber,
                                deviceId: KeychainHelper.shared.read(forKey: "chaiDeviceId") ?? ""
                            )
                        }
                        FaceAuthManager.shared.setRegistrationMode()
                        openMLScan.toggle()
                    }) {
                        HStack(spacing: 8) {
                            if viewModel.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "person.badge.plus")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Register")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            isButtonEnabled ?
                            LinearGradient(
                                colors: [logoBlue, logoPurple],
                                startPoint: .leading,
                                endPoint: .trailing
                            ) :
                            LinearGradient(colors: [Color.gray], startPoint: .leading, endPoint: .trailing)
                        )
                        .foregroundColor(.white)
                        .cornerRadius(14)
                        .shadow(color: isButtonEnabled ? logoBlue.opacity(0.3) : .clear, radius: 8, y: 4)
                    }
                    .disabled(!isButtonEnabled || viewModel.isLoading)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        #if DEBUG
                        print("❌ [RegisterUserView] Close button tapped")
                        #endif
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        #if DEBUG
                        print("🧹 [RegisterUserView] Reset button tapped")
                        #endif
                        
                        firstName = ""
                        lastName = ""
                        email = ""
                        phoneNumber = ""
                        viewModel.reset()
                        focusedField = .firstName
                    } label: {
                        Text("Reset")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [logoBlue, logoPurple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            //.animation(.spring(response: 0.5, dampingFraction: 0.75), value: viewModel.newUser)
            .animation(.spring(response: 0.5, dampingFraction: 0.75), value: viewModel.errorText)
        }
        .fullScreenCover(isPresented: $openMLScan){
            if let user = viewModel.newUser {
                MLScanView(onDone: {
                    dismiss()
                    dismiss()
                }, userId: user.id, deviceKeyHash: HMACGenerator.generateHMAC(jsonString: DeviceIdentity.resolve()),token: user.token)
            }
        }
    }
    
    private var isButtonEnabled: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        isValidEmail(email) &&
        phoneNumber.count == 10 &&
        !viewModel.isLoading
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
}

// MARK: - Reusable Input Field Component

struct InputField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let icon: String
    let isSecure: Bool
    let keyboardType: UIKeyboardType
    @FocusState.Binding var focusedField: RegisterChaiView.Field?
    let field: RegisterChaiView.Field
    let logoBlue: Color
    let logoPurple: Color
    let isDisabled: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.leading, 4)
            
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(width: 20)
                
                if isSecure {
                    SecureField(placeholder, text: $text)
                        .focused($focusedField, equals: field)
                        .disabled(isDisabled)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(red: 0.118, green: 0.161, blue: 0.231))
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                        .focused($focusedField, equals: field)
                        .disabled(isDisabled)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(red: 0.118, green: 0.161, blue: 0.231))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        focusedField == field ?
                        LinearGradient(
                            colors: [logoBlue, logoPurple],
                            startPoint: .leading,
                            endPoint: .trailing
                        ) :
                        LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing),
                        lineWidth: 2
                    )
            )
        }
    }
}
