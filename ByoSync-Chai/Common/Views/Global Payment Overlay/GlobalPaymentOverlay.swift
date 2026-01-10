//
//  GlobalPaymentOverlayView.swift
//  ByoSync-User
//
//  Created by Hari's Mac on 09.11.2025.
//

import Foundation
import SwiftUI

import Foundation
import SwiftUI

struct GlobalPaymentOverlayView: View {
    @ObservedObject var socketManager = SocketIOManager.shared
    
    var body: some View {
        ZStack {
            // Show overlay when there's a current payment notification
            if socketManager.showPaymentOverlay,
               let notification = socketManager.currentPaymentNotification {
                PaymentNotificationOverlay(
                    notification: notification,
                    isShowing: $socketManager.showPaymentOverlay,
                    onDismiss: {
                        print("🔔 Payment overlay dismissed by user or auto-dismiss timer")
                        socketManager.dismissCurrentPayment()
                    }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(9999)
            }
        }
        .allowsHitTesting(socketManager.showPaymentOverlay)
        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: socketManager.showPaymentOverlay)
    }
}
