import SwiftUI

struct ReceiptView: View {
    @EnvironmentObject var cryptoManager: CryptoManager
    
    @Environment(\.dismiss) var dismiss
    @State private var isAnimating = false
    @State private var showContent = false
    @State private var showButton = false
    @Binding var hideTabBar: Bool
    @Binding var selectedUser: UserData
    @Binding var orderId: String

    var amount: Int

    var cashback: String {
        "\((Int(amount)) * 10 / 100)"
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "F8F9FD"), Color.white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    VStack(spacing: 24) {
                        successAnimationView.frame(height: 200)
                        successTextView
                    }
                    .padding(.top, 40)
                    .padding(.bottom, 32)

                    amountCardView
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)

                    recipientCardView
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)

                    transactionDetailsCardView
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                    actionButtonsView
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            withAnimation { isAnimating = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeOut(duration: 0.6)) { showContent = true }
                AudioManager.shared.playPaymentSuccessSound()
                print("🎶 Payment Success Sound is Played")
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation { showButton = true }
            }
        }
    }
    
    // MARK: - Success Animation
    private var successAnimationView: some View {
        ZStack {
            ForEach(0..<3) { index in
                Circle()
                    .stroke(Color(hex: "4B548D").opacity(0.2), lineWidth: 2)
                    .frame(width: 120 + CGFloat(index * 30), height: 120 + CGFloat(index * 30))
                    .scaleEffect(isAnimating ? 1.3 : 0.8)
                    .opacity(isAnimating ? 0 : 0.6)
                    .animation(
                        Animation.easeOut(duration: 1.8)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.2),
                        value: isAnimating
                    )
            }
            
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "4B548D"), Color(hex: "5E68A6")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .shadow(color: Color(hex: "4B548D").opacity(0.3), radius: 20, x: 0, y: 10)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 50, weight: .bold))
                    .foregroundColor(.white)
            }
            .scaleEffect(isAnimating ? 1.0 : 0)
            .animation(.spring(response: 0.6, dampingFraction: 0.6), value: isAnimating)
        }
    }
    
    // MARK: - Success Text
    private var successTextView: some View {
        VStack(spacing: 8) {
            Text(String(localized: "receipt.payment_successful"))
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.primary)
            
            Text(String(localized: "receipt.transaction_completed"))
                .font(.system(size: 15))
                .foregroundColor(.secondary)
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
        .animation(.easeOut(duration: 0.5).delay(0.2), value: showContent)
    }
    
    // MARK: - Amount Card
    private var amountCardView: some View {
        VStack(spacing: 16) {
            Text(String(localized: "receipt.amount_paid"))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            HStack{
                Image("byosync_coin")
                    .resizable()
                    .interpolation(.high)  // Better quality interpolation
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())  // If it's a circular coin
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)  // Adds depth
                Text("\(amount)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 6)
        )
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 30)
        .animation(.easeOut(duration: 0.5).delay(0.3), value: showContent)
    }
    
    // MARK: - Recipient Card
    private var recipientCardView: some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "4B548D"))
                Text("Paid To")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
            }
            
            HStack(spacing: 14) {
                // Profile Image or Initials
                Group {
                    if let url = URL(string: selectedUser.profilePic), !selectedUser.profilePic.isEmpty {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(width: 54, height: 54)
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 54, height: 54)
                                    .clipShape(Circle())
                            case .failure:
                                userInitialsView
                            @unknown default:
                                userInitialsView
                            }
                        }
                    } else {
                        userInitialsView
                    }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(cryptoManager.decrypt(encryptedData: selectedUser.firstName) ?? "nil") \(cryptoManager.decrypt(encryptedData: selectedUser.lastName) ?? "nil")")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text(cryptoManager.decrypt(encryptedData: selectedUser.email) ?? "nil")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    if !selectedUser.phoneNumber.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: String(localized: "icon.phone_fill"))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Text((cryptoManager.decrypt(encryptedData: selectedUser.phoneNumber) ?? "nil"))
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 2)
        )
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
        .animation(.easeOut(duration: 0.5).delay(0.4), value: showContent)
    }
    
    private var userInitialsView: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "4B548D").opacity(0.15))
                .frame(width: 54, height: 54)
            
            Text(selectedUser.initials)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color(hex: "4B548D"))
        }
    }
    
    // MARK: - Transaction Details Card
    private var transactionDetailsCardView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: String(localized: "icon.doc_text_fill"))
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "4B548D"))
                Text(String(localized: "receipt.transaction_details"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            VStack(spacing: 14) {
                txnDetailRow(
                    icon: String(localized: "icon.calendar"),
                    label: String(localized: "receipt.date_time"),
                    value: formattedDateTime,
                    delay: 0.5
                )
                
                Divider().padding(.vertical, 2)
                
                txnDetailRow(
                    icon: "number",
                    label: "OrderId",
                    value: orderId,
                    delay: 0.6,
                    isMonospaced: true
                )
                
                Divider().padding(.vertical, 2)
                
                txnDetailRow(
                    icon: String(localized: "icon.creditcard_fill"),
                    label: String(localized: "receipt.payment_method"),
                    value: "ByoSync",
                    delay: 0.7
                )
                
                Divider().padding(.vertical, 2)
                
                txnDetailRow(
                    icon: "checkmark.shield.fill",
                    label: String(localized: "receipt.status"),
                    value: String(localized: "receipt.status_completed"),
                    valueColor: Color(hex: "4CAF50"),
                    delay: 0.8
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 2)
        )
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
        .animation(.easeOut(duration: 0.5).delay(0.5), value: showContent)
    }
    
    // MARK: - Buttons
    private var actionButtonsView: some View {
        VStack(spacing: 12) {
            Button(action: {
                // TODO: Implement share functionality
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                    Text(String(localized: "receipt.share_receipt"))
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(Color(hex: "4B548D"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
                )
            }
            
            Button(action: {
                dismiss()
                dismiss()
                hideTabBar = false
            }) {
                Text(String(localized: "receipt.back_to_home"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "4B548D"), Color(hex: "5E68A6")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: Color(hex: "4B548D").opacity(0.3), radius: 12, x: 0, y: 6)
            }
        }
        .opacity(showButton ? 1 : 0)
        .offset(y: showButton ? 0 : 20)
        .animation(.easeOut(duration: 0.5).delay(0.8), value: showButton)
    }
    
    // MARK: - Transaction Row
    private func txnDetailRow(
        icon: String,
        label: String,
        value: String,
        valueColor: Color = .primary,
        delay: Double,
        isMonospaced: Bool = false
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .frame(width: 18)
            
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(isMonospaced ?
                      .system(size: 13, weight: .semibold, design: .monospaced) :
                      .system(size: 14, weight: .semibold))
                .foregroundColor(valueColor)
        }
    }
    
    private var formattedDateTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = String(localized: "date.format.full")
        return formatter.string(from: Date())
    }
}
