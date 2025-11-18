import SwiftUI

struct AuthenticationView: View {
    @State var openEnterNumber: Bool = false
    @State var openRegister: Bool = false
    @State var openLoginSheet: Bool = false
    @Environment(\.dismiss) var dismiss
    
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
                        Button(action: { openLoginSheet.toggle() }) {
                            Text(L("login"))
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color(hex: "4B548D"))
                                .foregroundColor(.white)
                                .cornerRadius(16)
                                .shadow(color: Color(hex: "4B548D").opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        
                        Button(action: { openRegister.toggle() }) {
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
            }
            .sheet(isPresented: $openLoginSheet){
                LoginView()
            }
            .navigationBarBackButtonHidden(true)
            .navigationDestination(isPresented: $openRegister) {
                EnterNumberView()
            }
        }
    }
}
