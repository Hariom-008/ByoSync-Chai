import SwiftUI

struct RegisterUserView: View {
    @EnvironmentObject var cryptoService: CryptoManager
    @EnvironmentObject var router: Router
    @StateObject private var viewModel: RegisterUserViewModel
    @Binding var phoneNumber: String
    @EnvironmentObject var faceAuthManager: FaceAuthManager
    
    init(phoneNumber: Binding<String>) {
        self._phoneNumber = phoneNumber
        // Use a shared / consistent crypto instance instead of a new one
        _viewModel = StateObject(wrappedValue: RegisterUserViewModel(cryptoService: CryptoManager.shared))
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
                            keyboardType: .default
                        )
                        
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                }
                
                Spacer()
                
                Button(action: {
                    print("🔘 [VIEW] Register button tapped")
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    // ✅ Set mode in shared manager
                    faceAuthManager.setRegistrationMode()
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
        .onAppear {
            print("👀 [VIEW] RegisterUserView appeared")
            viewModel.phoneNumber = phoneNumber
        }
        .onChange(of: viewModel.navigateToMainTab) { _, newValue in
            if newValue {
                print("✅ [VIEW] navigateToMainTab = true → routing to MainTab")
                router.navigate(to: .mainTab, style: .push)
            }
        }
    }
}
