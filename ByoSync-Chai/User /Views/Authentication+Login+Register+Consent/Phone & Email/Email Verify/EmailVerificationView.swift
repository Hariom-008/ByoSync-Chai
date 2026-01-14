//
//  EmailVerificationView.swift
//  ByoSync
//
//  Created by Hari's Mac on 22.10.2025.
//

import SwiftUI

struct EmailVerificationView: View {
    @StateObject private var viewModel = EmailVerificationViewModel()
    @Environment(\.dismiss) var dismiss
    
    // State to handle automatic dismissal
    @State private var shouldDismiss = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Form {
                    // Email Display Section
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                Image(systemName: "envelope.fill")
                                    .foregroundColor(Color(hex: "4B548D"))
                                    .font(.system(size: 20))
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Verification Email")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text(UserSession.shared.currentUser?.email ?? "No email")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                }
                            }
                            .padding(.vertical, 4)
                            
                            if !viewModel.otpSent {
                                Text("Tap 'Send OTP' to receive a verification code")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } header: {
                        Text("Email Address")
                    }
                    
                    // Send OTP Section
                    if !viewModel.otpSent {
                        Section {
                            Button(action: {
                                print("📤 [VIEW] Send OTP button tapped")
                                viewModel.sendOTP()
                            }) {
                                HStack {
                                    Spacer()
                                    if viewModel.isSendingOTP {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle())
                                    } else {
                                        Label("Send Verification Code", systemImage: "paperplane.fill")
                                            .fontWeight(.semibold)
                                    }
                                    Spacer()
                                }
                            }
                            .disabled(viewModel.isLoading)
                        }
                    }
                    
                    // OTP Entry Section (only show after OTP is sent)
                    if viewModel.otpSent {
                        Section {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Enter the 6-digit code sent to your email")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.bottom, 4)
                            
                            HStack(spacing: 12) {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(Color(hex: "4B548D"))
                                    .frame(width: 24)
                                
                                TextField("Enter 6-digit OTP", text: $viewModel.otp)
                                    .keyboardType(.numberPad)
                                    .disabled(viewModel.isLoading)
                                    .font(.system(size: 17, weight: .medium, design: .monospaced))
                                    .onChange(of: viewModel.otp) { oldValue, newValue in
                                        // Limit to 6 digits
                                        if newValue.count > 6 {
                                            viewModel.otp = String(newValue.prefix(6))
                                        }
                                        // Remove non-numeric characters
                                        viewModel.otp = newValue.filter { $0.isNumber }
                                    }
                                
                                if viewModel.isOTPValid {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                            .padding(.vertical, 8)
                        } header: {
                            Text("Verification Code")
                        }
                        
                        Section {
                            // Verify Button
                            Button(action: {
                                print("✅ [VIEW] Verify OTP button tapped")
                                viewModel.verifyOTP()
                            }) {
                                HStack {
                                    Spacer()
                                    if viewModel.isVerifyingOTP {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle())
                                    } else {
                                        Label("Verify Email", systemImage: "checkmark.shield.fill")
                                            .fontWeight(.semibold)
                                    }
                                    Spacer()
                                }
                            }
                            .disabled(!viewModel.isOTPValid || viewModel.isLoading)
                            
                            // Resend OTP Button
                            Button(action: {
                                print("🔄 [VIEW] Resend OTP button tapped")
                                viewModel.resendOTP()
                            }) {
                                HStack {
                                    Spacer()
                                    if viewModel.canResendOTP {
                                        Label("Resend Code", systemImage: "arrow.clockwise")
                                            .foregroundColor(Color(hex: "4B548D"))
                                    } else {
                                        HStack(spacing: 8) {
                                            Image(systemName: "clock.fill")
                                            Text("Resend in \(viewModel.resendTimer)s")
                                        }
                                        .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                            }
                            .disabled(!viewModel.canResendOTP || viewModel.isLoading)
                        }
                    }
                }
                
                // Loading overlay
                if viewModel.isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        
                        Text(viewModel.isVerifyingOTP ? "Verifying..." :
                             viewModel.isSendingOTP ? "Sending..." : "Processing...")
                            .foregroundColor(.white)
                            .fontWeight(.semibold)
                            .font(.headline)
                    }
                    .padding(32)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(hex: "4B548D"))
                            .shadow(color: .black.opacity(0.3), radius: 20)
                    )
                }
            }
            .navigationTitle("Email Verification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        print("❌ [VIEW] Cancel button tapped")
                        dismiss()
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .alert(viewModel.alertTitle, isPresented: $viewModel.showAlert) {
                Button("OK", role: .cancel) {
                    // Auto-dismiss on success
                    if viewModel.emailVerified {
                        shouldDismiss = true
                    }
                }
            } message: {
                Text(viewModel.alertMessage)
            }
            // ✅ React to emailVerified state change
            .onChange(of: viewModel.emailVerified) { oldValue, newValue in
                if newValue {
                    print("✅ [VIEW] Email verified, scheduling dismissal")
                    // Wait a bit for the alert to be dismissed
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        shouldDismiss = true
                    }
                }
            }
            // ✅ Handle automatic dismissal
            .onChange(of: shouldDismiss) { oldValue, newValue in
                if newValue {
                    print("👋 [VIEW] Dismissing view after successful verification")
                    dismiss()
                }
            }
        }
        .onAppear {
            print("📱 [VIEW] EmailVerificationView appeared")
            // Auto-send OTP when view appears if not already sent
            if !viewModel.otpSent && !viewModel.email.isEmpty {
                print("📤 [VIEW] Auto-sending OTP on appear")
                viewModel.sendOTP()
            }
        }
    }
}

#Preview {
    EmailVerificationView()
}
