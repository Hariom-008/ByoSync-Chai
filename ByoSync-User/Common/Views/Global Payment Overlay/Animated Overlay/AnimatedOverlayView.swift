import Foundation
import SwiftUI
import Combine

struct PaymentNotification: Identifiable, Codable {
    let id: String
    let amount: Double
    let currency: String
    let senderId: String
    let timestamp: Date
    let transactionId: String
    let message: String?
    let orderType: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case amount
        case currency
        case senderId = "senderId"
        case timestamp
        case transactionId = "transaction_id"
        case message
        case orderType = "order_type"
    }
}

struct PaymentReceivedResponse: Codable {
    let message: String
    let order: OrderDetails
    
    struct OrderDetails: Codable {
        let id: String
        let type: String
        let receiverId: String
        let senderId: String
        let senderDeviceId: String
        let coins: Int
        let status: String
        let createdAt: String
        let updatedAt: String
        
        enum CodingKeys: String, CodingKey {
            case id = "_id"
            case type
            case receiverId
            case senderId
            case senderDeviceId
            case coins
            case status
            case createdAt
            case updatedAt
        }
    }
}


struct PaymentNotificationOverlay: View {
    let cryptoManager = CryptoManager.shared
    let notification: PaymentNotification
    @Binding var isShowing: Bool
    var onDismiss: (() -> Void)? = nil
    
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    
    // Brand & semantic colors
    private let brandColor = Color(hex: "4B548D")
    private let accentGreen = Color.green
    
    var body: some View {
        VStack {
            notificationCard
                .padding(.horizontal, 16)
                .padding(.top, 44)
                .offset(y: dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation.height < 0 {
                                isDragging = true
                                dragOffset = value.translation.height
                            }
                        }
                        .onEnded { value in
                            if value.translation.height < -50 {
                                dismissNotification()
                            } else {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    dragOffset = 0
                                    isDragging = false
                                }
                            }
                        }
                )
            
            Spacer()
        }
        .ignoresSafeArea(edges: .top)
        .onAppear {
            AudioManager.shared.playSound(named: "coin_recieve.mp3")
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                if isShowing {
                    print("🔔 Auto-dismiss timer fired")
                    dismissNotification()
                }
            }
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    private var notificationCard: some View {
        let decrypted = cryptoManager.decryptPaymentMessage(notification.message)
        let messageText = decrypted.isEmpty ? (notification.message ?? "") : decrypted
        let formattedAmount = String(format: "%.2f", notification.amount)
        
        return VStack(alignment: .leading, spacing: 0) {
            // Header with icon and close button
            HStack(alignment: .center, spacing: 12) {
                // Success icon with animated background
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.25),
                                    Color.white.opacity(0.12)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.green)
                }
                .frame(width: 40, height: 40)
                
                // Title and subtitle
                VStack(alignment: .leading, spacing: 3) {
                    if !messageText.isEmpty {
                        Text(messageText)
                            .font(.system(size: 16, weight: .semibold, design: .default))
                            .foregroundColor(.white)
                            .tracking(0.3)
                    }
                    
                    Text("Just now")
                        .font(.system(size: 12, weight: .regular, design: .default))
                        .foregroundColor(.white.opacity(0.65))
                }
                
                Spacer()
                
                // Close button with improved interaction
                Button(action: {
                    print("🔔 Manual dismiss triggered")
                    dismissNotification()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.10))
                            .background(Circle().fill(Color.white.opacity(0.04)))
                        
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.75))
                    }
                }
                .frame(width: 32, height: 32)
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            
            // Divider for visual separation
            Divider()
                .background(Color.white.opacity(0.12))
                .padding(.horizontal, 18)
            
            // Amount and message section
            VStack(alignment: .leading, spacing: 10) {
                // Amount display with currency
                HStack(alignment: .center, spacing: 6) {
                    Text(notification.currency)
                        .font(.system(size: 12, weight: .medium, design: .default))
                        .foregroundColor(.white.opacity(0.7))
                        .tracking(0.5)
                    
                    Text(formattedAmount)
                        .font(.system(size: 22, weight: .bold, design: .default))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                .padding(.top, 2)
                // Transaction ID badge (subtle)
                HStack(spacing: 4) {
                    Text("Txn Id: \(notification.transactionId)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                }
                .foregroundColor(.white.opacity(0.5))
                .padding(.top, 8)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
        .background(
            ZStack {
                // Base gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        brandColor,
                        brandColor.opacity(0.88)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Animated shine effect
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.12),
                        Color.clear,
                        Color.clear
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blendMode(.screen)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: brandColor.opacity(0.4), radius: 20, x: 0, y: 12)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.25),
                            Color.white.opacity(0.05)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
    
    private func dismissNotification() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            isShowing = false
        }
        onDismiss?()
    }
}
