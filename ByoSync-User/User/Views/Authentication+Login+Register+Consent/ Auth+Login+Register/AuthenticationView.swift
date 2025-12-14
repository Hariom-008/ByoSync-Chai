import SwiftUI

struct AuthenticationView: View {
    @State private var openEnterNumber: Bool = false
    @State private var openLoginSheet: Bool = false
    @Environment(\.dismiss) var dismiss
    
    // 🔍 Device registration check VM
    @StateObject private var deviceRegistrationVM = DeviceRegistrationViewModel()
    
    // Only used to know this change came from "Register" button
    @State private var didTapRegister: Bool = false
    
    // Alert only for “already registered” case
    @State private var showDeviceAlert: Bool = false
    @State private var deviceAlertMessage: String = ""
    
    // Same key we used in RegisterUserViewModel
    private let deviceKeyUserDefaultKey = "deviceKey"
    @State var openTestingView:Bool = false
    
    var body: some View {
    NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(hex: "4B548D").opacity(0.05),
                        Color(hex: "4B548D").opacity(0.02)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack {
                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 300, height: 300)
                        .opacity(0.08)
                        .offset(y: -100)
                }
                .zIndex(0)
                
                VStack(spacing: 12) {
                    Spacer()
                    
                    VStack(spacing: 8) {
                        Text(L("welcome_to"))
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Text("ByoSync")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(Color(hex: "4B548D"))
                        
                        Text(L("make_payments_easier"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                    .padding(.bottom, 50)
                    
                    VStack(spacing: 16) {
                        // LOGIN
                        Button(action: { openLoginSheet.toggle() }) {
                            Text(L("login"))
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color(hex: "4B548D"))
                                .foregroundColor(.white)
                                .cornerRadius(16)
                                .shadow(
                                    color: Color(hex: "4B548D").opacity(0.3),
                                    radius: 8, x: 0, y: 4
                                )
                        }
                        
                        // REGISTER
                        Button(action: {
                            guard !deviceRegistrationVM.isLoading else { return }
                            didTapRegister = true
                            
                            // 1️⃣ Try to read deviceKey
                            let deviceKey = UserSession.shared.deviceKey ?? ""
                            if !deviceKey.isEmpty {
                                print("🔐 Using deviceKey from UserDefaults for registration check")
                                deviceRegistrationVM.checkDeviceRegistration(deviceKey: deviceKey)
                            } else {
                                // 2️⃣ No deviceKey stored → probably first time: just proceed
                                print("⚠️ No deviceKey in User Defaults, proceeding to EnterNumberView directly")
                                openEnterNumber = true
                            }
                        }) {
                            HStack {
                                Image(systemName: "person.badge.plus.fill")
                                Text(L("create_account"))
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color(hex: "4B548D"), lineWidth: 2)
                            )
                            .foregroundColor(Color(hex: "4B548D"))
                        }
                    }
                    .padding(.horizontal, 32)
                    
                    HStack(spacing: 8) {
                        Text(L("powered_by"))
                            .font(.caption2)
                            .foregroundColor(.gray.opacity(0.7))
                        Text("Kavion")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.gray)
                    }
                    .padding(.bottom, 32)
                }
                .zIndex(1)
                
                // Optional loading overlay while checking device registration
                if deviceRegistrationVM.isLoading {
                    Color.black.opacity(0.15)
                        .ignoresSafeArea()
                    ProgressView("Checking device…")
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(.thinMaterial)
                        .cornerRadius(14)
                }
            }
            .sheet(isPresented: $openLoginSheet) {
                LoginView()
            }
            .navigationBarBackButtonHidden(true)
            .navigationDestination(isPresented: $openEnterNumber) {
                EnterNumberView()
            }
            .navigationDestination(isPresented: $openTestingView, destination: {
                MLScanView {
                    print("😌 Face Detection is complete you can now LOGIN")
                }
            })
            .alert(deviceAlertMessage, isPresented: $showDeviceAlert) {
                Button("OK", role: .cancel) { }
            }
            .toolbar{
                Button{
                    openTestingView.toggle()
                }label: {
                    Text("Testing")
                }
            }
            
            // 🔁 Decide what to do when API call finishes
            .onChange(of: deviceRegistrationVM.isLoading) { isLoading in
                guard !isLoading, didTapRegister else { return }
                didTapRegister = false
                
                // 👉 ONLY BLOCK if backend clearly says: device is already registered
                if deviceRegistrationVM.isDeviceRegistered {
                    deviceAlertMessage =
                    "This device is already registered with an existing ByoSync account. You can't register a new account from this device."
                    showDeviceAlert = true
                    print("⛔️ Device already registered – blocking registration flow")
                } else {
                    // ✅ For ALL other cases (not registered, API error, decode error):
                    // proceed to registration flow
                    print("✅ Device not registered or API failed – proceeding to EnterNumberView")
                    openEnterNumber = true
                }
            }
        }
    }
}
