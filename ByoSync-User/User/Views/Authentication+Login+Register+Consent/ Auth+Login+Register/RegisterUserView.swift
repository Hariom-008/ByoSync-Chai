import SwiftUI

struct RegisterUserView: View {
    // ✅ Get crypto service from environment
    @EnvironmentObject var cryptoService: CryptoManager
    
    // ✅ ViewModel will be created with injected crypto service
    @StateObject private var viewModel: RegisterUserViewModel
    
    @Environment(\.dismiss) private var dismiss
    @Binding var phoneNumber: String
    @State private var shouldNavigateToMain = false
    
    // ✅ Custom initializer to inject crypto service into view model
    init(phoneNumber: Binding<String>) {
        self._phoneNumber = phoneNumber
        
        // Create a temporary crypto manager for initialization
        // The actual one from environment will be used when view appears
        let tempCrypto = CryptoManager()
        self._viewModel = StateObject(wrappedValue: RegisterUserViewModel(cryptoService: tempCrypto))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.97, green: 0.95, blue: 1.0),
                        Color(red: 0.95, green: 0.97, blue: 1.0)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L("create_account"))
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.indigo)
                        
                        Text(L("join_byosync_start"))
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 32)
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            FormField(
                                icon: "person.fill",
                                placeholder: L("first_name"),
                                text: $viewModel.firstName,
                                keyboardType: .default
                            )
                            
                            FormField(
                                icon: "person.fill",
                                placeholder: L("last_name"),
                                text: $viewModel.lastName,
                                keyboardType: .default
                            )
                            
                            FormField(
                                icon: "envelope",
                                placeholder: L("email"),
                                text: $viewModel.email,
                                keyboardType: .emailAddress
                            )
                            
                            FormField(
                                icon: "phone.fill",
                                placeholder: L("phone_number"),
                                text: $viewModel.phoneNumber,
                                keyboardType: .phonePad
                            )
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                    }
                    
                    Spacer()
                    
                    // Register Button with proper validation
                    Button(action: {
                        print("🔘 [VIEW] Register button tapped")
                        print("📋 [VIEW] Can submit: \(viewModel.canSubmit)")
                        print("📋 [VIEW] Fields filled: \(viewModel.allFieldsFilled)")
                        print("📋 [VIEW] Email valid: \(viewModel.isValidEmail)")
                        
                        // Hide keyboard
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        
                        viewModel.registerUser()
                    }) {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                Text("Registering...")
                                    .foregroundColor(.white)
                            } else {
                                Text(L("continue"))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            !viewModel.canSubmit || viewModel.isLoading
                            ? Color(hex: "4B548D").opacity(0.5)
                            : Color(hex: "4B548D")
                        )
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!viewModel.canSubmit || viewModel.isLoading)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.primary)
                    }
                }
            }
            .alert(L("error"), isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {
                    print("⚠️ [VIEW] Error alert dismissed")
                }
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
            .onChange(of: viewModel.navigateToMainTab) { oldValue, newValue in
                print("🔄 [VIEW] navigateToMainTab changed: \(oldValue) -> \(newValue)")
                if newValue {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        shouldNavigateToMain = true
                    }
                }
            }
            .onChange(of: viewModel.showError) { oldValue, newValue in
                print("🔄 [VIEW] showError changed: \(oldValue) -> \(newValue)")
            }
        }
        .onAppear {
            print("👀 [VIEW] RegisterUserView appeared")
            viewModel.phoneNumber = phoneNumber
            print("📱 [VIEW] Phone number set to: \(phoneNumber)")
        }
        .fullScreenCover(isPresented: $shouldNavigateToMain) {
            MainTabView()
                .environmentObject(cryptoService) // ✅ Pass crypto service down
                .onAppear {
                    print("✅ [VIEW] MainTabView presented successfully")
                }
        }
    }
}

// MARK: - Form Field Component
struct FormField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    let keyboardType: UIKeyboardType
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.indigo)
                    .frame(width: 24)
                
                TextField(placeholder, text: $text)
                    .font(.system(size: 16, weight: .regular, design: .default))
                    .keyboardType(keyboardType)
                    .autocapitalization(keyboardType == .emailAddress ? .none : .words)
                    .textContentType(contentTypeForKeyboard(keyboardType))
                    .focused($isFocused)
                
                if !text.isEmpty {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.green)
                        .transition(.scale)
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isFocused ?
                          Color.black
                        : Color.clear,
                        lineWidth: 0.5
                    )
            )
            .shadow(color: isFocused ? .indigo.opacity(0.1) : .clear, radius: 8, x: 0, y: 4)
            .animation(.easeInOut(duration: 0.2), value: isFocused)
        }
    }
    
    private func contentTypeForKeyboard(_ type: UIKeyboardType) -> UITextContentType? {
        switch type {
        case .emailAddress:
            return .emailAddress
        case .phonePad:
            return .telephoneNumber
        default:
            return nil
        }
    }
}
