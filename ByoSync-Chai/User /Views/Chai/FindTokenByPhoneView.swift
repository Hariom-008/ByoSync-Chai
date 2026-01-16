import Foundation
import SwiftUI

struct FindTokenByPhoneView: View {
    @StateObject private var viewModel = FindUserTokenByPhoneNumberViewModel()
    @Environment(\.dismiss) private var dismiss
    
    @State private var phoneNumber: String = ""
    @FocusState private var isPhoneFieldFocused: Bool
    @State private var showCopiedAlert: Bool = false

    
    
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
                
                VStack(spacing: 28) {
                    Spacer().frame(height: 20)
                    
                    // Header with icon
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 80, height: 80)
                                .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
                            
                            Image(systemName: "phone.circle.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [logoBlue, logoPurple],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                        
                        Text("Find User Token")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [logoBlue, logoPurple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        Text("Enter phone number to retrieve token")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    // Phone Input Card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Phone Number")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.leading, 4)
                        
                        HStack(spacing: 12) {
                            // Country code prefix
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
                            
                            // Phone number input
                            HStack(spacing: 8) {
                                Image(systemName: "phone.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                
                                TextField("10-digit number", text: $phoneNumber)
                                    .keyboardType(.numberPad)
                                    .focused($isPhoneFieldFocused)
                                    .disabled(viewModel.isLoading)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color(red: 0.118, green: 0.161, blue: 0.231))
                                    .onChange(of: phoneNumber) { _, newValue in
                                        let digitsOnly = newValue.filter(\.isNumber)
                                        if digitsOnly != newValue { phoneNumber = digitsOnly }
                                        if phoneNumber.count > 10 { phoneNumber = String(phoneNumber.prefix(10)) }
                                        
                                        #if DEBUG
                                        print("📱 [FindTokenByPhoneView] Phone number: +91\(phoneNumber)")
                                        #endif
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
                                        isPhoneFieldFocused ?
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
                        
                        // Character count
                        if !phoneNumber.isEmpty {
                            Text("\(phoneNumber.count)/10 digits")
                                .font(.system(size: 11))
                                .foregroundColor(phoneNumber.count == 10 ? .green : .secondary)
                                .padding(.leading, 4)
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // Fetch Button
                    Button(action: {
                        #if DEBUG
                        print("🔍 [FindTokenByPhoneView] Fetch button tapped for +91\(phoneNumber)")
                        #endif
                        
                        isPhoneFieldFocused = false
                        let fullNumber = "+91\(phoneNumber)"
                        Task {
                            await viewModel.fetch(phoneNumber: fullNumber)
                        }
                    }) {
                        HStack(spacing: 8) {
                            if viewModel.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Fetch Token")
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
                    
                    // Result Display
                    if let token = viewModel.token {
                        // Success Card
                        VStack(spacing: 20) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 56))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.green, .green.opacity(0.7)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                            
                            VStack(spacing: 10) {
                                Text("Token Found")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                Text("\(token)")
                                    .font(.system(size: 48, weight: .bold, design: .rounded))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [logoBlue, logoPurple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            }
                            
                            // Copy Button
                            Button(action: {
                                UIPasteboard.general.string = "\(token)"
                                showCopiedAlert = true
                                
                                #if DEBUG
                                print("📋 [FindTokenByPhoneView] Token copied: \(token)")
                                #endif
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    showCopiedAlert = false
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: showCopiedAlert ? "checkmark" : "doc.on.doc")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text(showCopiedAlert ? "Copied!" : "Copy Token")
                                        .font(.system(size: 15, weight: .semibold))
                                }
                                .foregroundColor(showCopiedAlert ? .green : logoBlue)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(showCopiedAlert ? Color.green : logoBlue, lineWidth: 2)
                                )
                            }
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showCopiedAlert)
                            
                            if let message = viewModel.message, !message.isEmpty {
                                Text(message)
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.top, 4)
                            }
                        }
                        .padding(28)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white)
                                .shadow(color: .green.opacity(0.15), radius: 12, y: 6)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.green.opacity(0.2), lineWidth: 1)
                        )
                        .padding(.horizontal, 24)
                        .transition(.scale.combined(with: .opacity))
                        
                    } else if let error = viewModel.errorText {
                        // Error Card
                        VStack(spacing: 20) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 56))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.red, .orange],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                            
                            VStack(spacing: 10) {
                                Text("Error")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                Text(error)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(28)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white)
                                .shadow(color: .red.opacity(0.15), radius: 12, y: 6)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.red.opacity(0.2), lineWidth: 1)
                        )
                        .padding(.horizontal, 24)
                        .transition(.scale.combined(with: .opacity))
                    }
                    
                    Spacer()
                }
                .padding(.top, 16)
            }
            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                ToolbarItem(placement: .navigationBarLeading) {
//                    Button {
//                        #if DEBUG
//                        print("❌ [FindTokenByPhoneView] Close button tapped")
//                        #endif
//                        dismiss()
//                    } label: {
//                        Image(systemName: "xmark.circle.fill")
//                            .font(.system(size: 20))
//                            .foregroundColor(.secondary)
//                    }
//                }
//                
//                ToolbarItem(placement: .navigationBarTrailing) {
//                    Button {
//                        #if DEBUG
//                        print("🧹 [FindTokenByPhoneView] Reset button tapped")
//                        #endif
//                        
//                        phoneNumber = ""
//                        viewModel.reset()
//                        showCopiedAlert = false
//                        isPhoneFieldFocused = true
//                    } label: {
//                        Text("Reset")
//                            .font(.system(size: 16, weight: .medium))
//                            .foregroundStyle(
//                                LinearGradient(
//                                    colors: [logoBlue, logoPurple],
//                                    startPoint: .leading,
//                                    endPoint: .trailing
//                                )
//                            )
//                    }
//                    .disabled(viewModel.isLoading)
//                }
//            }
            .animation(.spring(response: 0.5, dampingFraction: 0.75), value: viewModel.token)
            .animation(.spring(response: 0.5, dampingFraction: 0.75), value: viewModel.errorText)
        }
    }
    
    private var isButtonEnabled: Bool {
        phoneNumber.count == 10 && !viewModel.isLoading
    }
}

#Preview {
    FindTokenByPhoneView()
}
