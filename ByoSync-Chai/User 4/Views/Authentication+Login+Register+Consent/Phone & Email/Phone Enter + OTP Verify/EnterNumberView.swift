import SwiftUI

struct EnterNumberView: View {
    @StateObject private var findUserByPhoneVM = FetchUserByPhoneNumberViewModel()
    @StateObject private var viewModel = PhoneOTPViewModel()

    @EnvironmentObject var router: Router
    @FocusState private var isPhoneFieldFocused: Bool
    @Environment(\.dismiss) var dismiss

    // ✅ New alerts
    @State private var showPhoneExistsAlert: Bool = false
    @State private var phoneExistsMessage: String = ""

    @State private var showLookupErrorAlert: Bool = false
    @State private var lookupErrorMessage: String = ""

    let countryCodes = ["+91"]

    private var isBusy: Bool {
        viewModel.isLoading || findUserByPhoneVM.isLoading
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("Enter your phone number")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("We'll send you a verification code via SMS")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 60)
                .padding(.bottom, 40)

                // Phone Number Input
                VStack(alignment: .leading, spacing: 12) {
                    Text("Phone Number")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        // Country Code Picker
                        Menu {
                            ForEach(countryCodes, id: \.self) { code in
                                Button {
                                    viewModel.selectedCountryCode = code
                                } label: {
                                    HStack {
                                        Text(code)
                                        if viewModel.selectedCountryCode == code {
                                            Spacer()
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(viewModel.selectedCountryCode)
                                    .fontWeight(.medium)
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                            }
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 16)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }

                        // Phone Number Field
                        TextField("6234567890", text: $viewModel.phoneNumber)
                            .keyboardType(.phonePad)
                            .focused($isPhoneFieldFocused)
                            .font(.body)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .onChange(of: viewModel.phoneNumber) { _, newValue in
                                let filtered = newValue.filter { $0.isNumber }
                                let clipped = String(filtered.prefix(10))
                                if viewModel.phoneNumber != clipped {
                                    viewModel.phoneNumber = clipped
                                }
                                viewModel.updatePhoneNumber(clipped)
                            }
                    }

                    Text("Enter 10 digit mobile number starting with 6-9")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                // Continue Button
                Button {
                    isPhoneFieldFocused = false
                    Task {
                        await handleContinueTapped()
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isBusy {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Send OTP")
                                .font(.headline)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        viewModel.isValidPhoneNumber && !isBusy
                        ? Color.black
                        : Color.gray
                    )
                    .cornerRadius(12)
                }
                .disabled(!viewModel.isValidPhoneNumber || isBusy)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .onTapGesture { isPhoneFieldFocused = false }

            if isBusy {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.primary)
                        .fontWeight(.medium)
                }
            }
        }

        // Existing OTP error
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "Something went wrong.")
        }

        // ✅ New: phone already exists
        .alert("Phone number already exists", isPresented: $showPhoneExistsAlert) {
            Button("OK", role: .cancel) {
                // optional: clear + refocus
                // viewModel.phoneNumber = ""
                // isPhoneFieldFocused = true
            }
        } message: {
            Text(phoneExistsMessage)
        }

        // ✅ New: lookup error (network/server)
        .alert("Error", isPresented: $showLookupErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(lookupErrorMessage)
        }

        .onChange(of: viewModel.otpSent) { _, sent in
            guard sent else { return }
            router.navigate(
                to: .otpVerification(
                    phoneNumber: viewModel.fullPhoneNumber,
                    viewModel: viewModel
                ),
                style: .push
            )
        }
    }

    // MARK: - Logic

    @MainActor
    private func handleContinueTapped() async {
        guard viewModel.isValidPhoneNumber else { return }

        let phone = viewModel.fullPhoneNumber

        // 1) Check if phone exists in backend
        await findUserByPhoneVM.fetch(phoneNumber: phone)

        // If found => block OTP
        if findUserByPhoneVM.userId != nil {
            phoneExistsMessage = "This phone number is already registered. Please use another number."
            showPhoneExistsAlert = true
            return
        }

        // Any error from lookup now means we can proceed to send OTP
        if let err = findUserByPhoneVM.errorText, !err.isEmpty {
            // Proceed despite error
            viewModel.sendOTP()
            return
        }

        // No userId and no error => treat as not found and proceed
        viewModel.sendOTP()
    }
}

#Preview {
    EnterNumberView()
}
