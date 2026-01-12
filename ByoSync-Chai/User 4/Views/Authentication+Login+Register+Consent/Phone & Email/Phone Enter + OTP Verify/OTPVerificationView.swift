import SwiftUI

struct OTPVerificationView: View {
    @State var phoneNumber: String
    @ObservedObject var viewModel: PhoneOTPViewModel
    @EnvironmentObject var router: Router
    
    @State private var otpCode: [String] = ["", "", "", "", "", ""]
    @FocusState private var focusedField: Int?
    @State private var hasError: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Text("Enter verification code")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("We sent a code to")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(formatDisplayPhoneNumber(phoneNumber))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.indigo)
            }
            .padding(.top, 60)
            .padding(.bottom, 40)
            
            // OTP Input Fields
            HStack(spacing: 12) {
                ForEach(0..<6, id: \.self) { index in
                    CodeDigitField(
                        text: $otpCode[index],
                        isFocused: focusedField == index,
                        hasError: hasError
                    )
                    .focused($focusedField, equals: index)
                    .onChange(of: otpCode[index]) { oldValue, newValue in
                        handleOTPChange(at: index, oldValue: oldValue, newValue: newValue)
                    }
                }
            }
            .padding(.horizontal, 24)
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 12)
            }
            
            // Resend Code
            HStack(spacing: 4) {
                Text("Didn't receive the code?")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if viewModel.canResend {
                    Button("Resend") {
                        #if DEBUG
                        print("📱 Resending OTP to: \(phoneNumber)")
                        #endif
                        viewModel.resendOTP()
                        clearOTP()
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.indigo)
                } else {
                    Text("Resend in \(viewModel.resendCountdown)s")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 24)
            
            Spacer()
            
            // Verify Button
            Button(action: verifyOTP) {
                HStack(spacing: 8) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Verify")
                            .font(.headline)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(isOTPComplete && !viewModel.isLoading ? Color.black : Color.gray)
                .cornerRadius(12)
            }
            .disabled(!isOTPComplete || viewModel.isLoading)
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
            
            // Back to edit number
            Button(action: { router.pop() }) {
                Text("Change phone number")
                    .font(.subheadline)
                    .foregroundColor(.indigo)
            }
            .padding(.bottom, 40)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { router.pop() }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.primary)
                        .fontWeight(.medium)
                }
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {
                hasError = false
                clearOTP()
            }
        } message: {
            Text(viewModel.errorMessage ?? "Something went wrong.")
        }
        .onChange(of: viewModel.isAuthenticated) { _, newValue in
            if newValue {
                #if DEBUG
                print("✅ OTP verified successfully, navigating to registration")
                #endif
                router.navigate(to: .registerUser(phoneNumber: phoneNumber), style: .push)
            }
        }
        .onAppear {
            #if DEBUG
            print("📱 OTP View appeared for number: \(phoneNumber)")
            print("🔐 Masked display: \(formatDisplayPhoneNumber(phoneNumber))")
            #endif
            
            viewModel.selectedCountryCode = "+91"
            viewModel.phoneNumber = phoneNumber.replacingOccurrences(of: "+91", with: "").filter { $0.isNumber }
            focusedField = 0
        }
    }
    
    // MARK: - Computed Properties
    private var isOTPComplete: Bool { otpCode.allSatisfy { !$0.isEmpty } }
    private var otpString: String { otpCode.joined() }
    
    // MARK: - Methods
    private func handleOTPChange(at index: Int, oldValue: String, newValue: String) {
        if newValue.count > 1 {
            otpCode[index] = String(newValue.last ?? Character(""))
        }
        
        if !newValue.isEmpty && index < 5 {
            focusedField = index + 1
        }
        
        if isOTPComplete {
            #if DEBUG
            print("🔢 OTP complete: \(otpString)")
            #endif
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                verifyOTP()
            }
        }
    }
    
    private func verifyOTP() {
        guard isOTPComplete else { return }
        #if DEBUG
        print("✅ Verifying OTP: \(otpString)")
        #endif
        hasError = false
        viewModel.verifyOTP(code: otpString)
    }
    
    private func clearOTP() {
        #if DEBUG
        print("🗑️ Clearing OTP fields")
        #endif
        otpCode = ["", "", "", "", "", ""]
        focusedField = 0
    }
    
    private func formatDisplayPhoneNumber(_ number: String) -> String {
        let digitsOnly = number.replacingOccurrences(of: "+91", with: "").filter { $0.isNumber }
        
        #if DEBUG
        print("📱 Original number: \(number)")
        print("📱 Digits only: \(digitsOnly)")
        #endif
        
        guard digitsOnly.count >= 10 else {
            return "+91 " + digitsOnly
        }
        
        let lastThree = String(digitsOnly.suffix(3))
        let masked = "+91 XXXX XXX \(lastThree)"
        
        #if DEBUG
        print("📱 Masked display: \(masked)")
        #endif
        
        return masked
    }
}

// MARK: - CodeDigitField
struct CodeDigitField: View {
    @Binding var text: String
    let isFocused: Bool
    let hasError: Bool
    
    private let logoBlue = Color(red: 0.0, green: 0.0, blue: 1.0)
    private let logoPurple = Color(red: 0.478, green: 0.0, blue: 1.0)
    
    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 12)
                .fill(isFocused ?
                       LinearGradient(
                        colors: [logoBlue, logoPurple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                       ):
                        LinearGradient(
                            colors: [Color.gray.opacity(0.5), Color.gray.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                )
                .frame(width: 50, height: 60)
            
            // Border - gradient when focused, red on error, clear otherwise
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    hasError ?
                    LinearGradient(
                        colors: [.red, .red],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ) :
                        isFocused ?
                    LinearGradient(
                        colors: [logoBlue.opacity(0.5), logoPurple.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ) :
                        LinearGradient(
                            colors: [.clear, .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                    lineWidth: 2
                )
                .frame(width: 50, height: 60)
            
            // Text field
            TextField("", text: $text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.title2)
                .fontWeight(.semibold)
                .frame(width: 50, height: 60)
                .background(Color.clear)
        }
    }
}
