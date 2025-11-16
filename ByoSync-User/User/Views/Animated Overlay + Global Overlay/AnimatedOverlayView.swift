import Foundation
import SwiftUI
import Combine

struct PaymentNotification: Identifiable, Codable {
    let id: String
    let amount: Double
    let currency: String
    let senderName: String
    let timestamp: Date
    let transactionId: String
    let message: String?
    let orderType: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case amount
        case currency
        case senderName = "sender_name"
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
    let notification: PaymentNotification
    @Binding var isShowing: Bool
    var onDismiss: (() -> Void)? = nil
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    
    private let primaryGreen = Color.green
    
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
        .onAppear {
            // 👇 Automatically dismiss after 4 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                if isShowing { // avoid double-dismiss
                    dismissNotification()
                }
            }
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    private var notificationCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(notification.message ?? "Nil")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.top, 2)
                }
                
                Spacer(minLength: 12)
                
                Button(action: dismissNotification) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.12))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                    }
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [primaryGreen, primaryGreen]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Color.white.opacity(0.03)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .shadow(color: primaryGreen.opacity(0.25), radius: 24, x: 0, y: 12)
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.25),
                            Color.white.opacity(0.08)
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


// MARK: - Notification Manager
class PaymentNotificationManager: ObservableObject {
    @Published var currentNotification: PaymentNotification?
    @Published var isShowing: Bool = false
    private var dismissWorkItem: DispatchWorkItem?
    
    func showNotification(_ notification: PaymentNotification) {
        // Cancel any pending dismiss
        dismissWorkItem?.cancel()
        
        currentNotification = notification
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            isShowing = true
        }
        
        // Auto-dismiss after 5 seconds
        let workItem = DispatchWorkItem { [weak self] in
            self?.dismissNotification()
        }
        dismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: workItem)
    }
    
    func dismissNotification() {
        dismissWorkItem?.cancel()
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            isShowing = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            self.currentNotification = nil
        }
    }
}
