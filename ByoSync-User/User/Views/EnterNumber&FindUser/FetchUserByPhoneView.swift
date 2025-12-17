import SwiftUI

struct FetchUserByPhoneView: View {
    @EnvironmentObject var router: Router

    @StateObject private var viewModel = FetchUserByPhoneNumberViewModel()

    @State private var phoneNumber: String = "+91"
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var alertTitle: String = ""

    @FocusState private var isPhoneFieldFocused: Bool

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "person.text.rectangle")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                        .scaleEffect(viewModel.isLoading ? 0.8 : 1.0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: viewModel.isLoading)

                    Text("Find User")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Enter phone number to fetch userId + deviceKeyHash")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)

                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "phone.fill").foregroundColor(.blue)

                        TextField("Phone Number", text: $phoneNumber)
                            .keyboardType(.phonePad)
                            .focused($isPhoneFieldFocused)
                            .disabled(viewModel.isLoading)
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(12)

                    Button {
                        isPhoneFieldFocused = false
                        Task { await fetchUser() }
                    } label: {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.85)
                            } else {
                                Image(systemName: "magnifyingglass")
                            }

                            Text(viewModel.isLoading ? "Fetching..." : "Fetch User")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(phoneNumber.isEmpty ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(phoneNumber.isEmpty || viewModel.isLoading)
                }
                .padding(.horizontal)

                Spacer()
            }

            if viewModel.userId != nil && !viewModel.isLoading {
                successOverlay
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                        viewModel.reset()
                        phoneNumber = ""
                    }
                }

            VStack(spacing: 18) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 74))
                    .foregroundColor(.green)

                Text("User Found!")
                    .font(.title2)
                    .fontWeight(.bold)

                VStack(alignment: .leading, spacing: 10) {
                    if let userId = viewModel.userId {
                        HStack {
                            Text("User ID:").fontWeight(.medium)
                            Text(userId)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }

                    HStack {
                        Text("Face Records:").fontWeight(.medium)
                        Text("\(viewModel.faceIds.count)")
                            .foregroundColor(.secondary)
                    }

                    if let deviceKeyHash = viewModel.deviceKeyHash {
                        HStack {
                            Text("DeviceKeyHash:").fontWeight(.medium)
                            Text(deviceKeyHash)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)

                Button {
                    guard let userId = viewModel.userId,
                          let deviceKeyHash = viewModel.deviceKeyHash else { return }

                    router.navigate(to: .mlScan(userId: userId, deviceKeyHash: deviceKeyHash))

                    // optional: clear UI so when you come back it’s fresh
                    viewModel.reset()
                    phoneNumber = ""
                } label: {
                    Text("Start Face Scan")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            .padding(28)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(24)
            .shadow(radius: 18)
            .padding(36)
        }
    }

    private func fetchUser() async {
        guard !phoneNumber.isEmpty else { return }

        await viewModel.fetch(phoneNumber: phoneNumber)

        if let error = viewModel.errorText {
            alertTitle = "Error"
            alertMessage = error
            showAlert = true
            return
        }

        guard viewModel.userId != nil, viewModel.deviceKeyHash != nil else {
            alertTitle = "Not Found"
            alertMessage = viewModel.message ?? "User not found with this phone number"
            showAlert = true
            return
        }
    }
}
