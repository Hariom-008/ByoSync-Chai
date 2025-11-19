import SwiftUI

struct RegisterUserView: View {
    @EnvironmentObject var cryptoService: CryptoManager
    @EnvironmentObject var router: Router
    @StateObject private var viewModel: RegisterUserViewModel
    @Binding var phoneNumber: String
    
    init(phoneNumber: Binding<String>) {
        self._phoneNumber = phoneNumber
        let tempCrypto = CryptoManager()
        self._viewModel = StateObject(wrappedValue: RegisterUserViewModel(cryptoService: tempCrypto))
    }
    
    var body: some View {
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
                
                Button(action: {
                    print("🔘 [VIEW] Register button tapped")
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
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    print("⬅️ [VIEW] Back button tapped")
                    router.pop()
                }) {
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
        .onChange(of: viewModel.navigateToMainTab) { _, newValue in
            if newValue {
                print("✅ [VIEW] Registration successful, navigating to main tab")
                router.popToRoot()
                router.navigate(to: .mainTab, style: .push)
            }
        }
        .onAppear {
            print("👀 [VIEW] RegisterUserView appeared")
            viewModel.phoneNumber = phoneNumber
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
