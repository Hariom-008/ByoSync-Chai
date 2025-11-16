//
//  GlobalPaymentOverlayView.swift
//  ByoSync-User
//
//  Created by Hari's Mac on 09.11.2025.
//

import Foundation
import SwiftUI

struct GlobalPaymentOverlayView: View {
    @ObservedObject var socketManager = SocketIOManager.shared
    @State var isShowing:Bool = false
    var body: some View {
        ZStack {
            // Show overlay when there's a current payment notification
            if socketManager.showPaymentOverlay,
               let notification = socketManager.currentPaymentNotification {
                PaymentNotificationOverlay(
                    notification: notification,
                    isShowing: $isShowing,
                    onDismiss: {
                        socketManager.dismissCurrentPayment()
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(9999)
            }
        }
        .allowsHitTesting(socketManager.showPaymentOverlay)
        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: socketManager.showPaymentOverlay)
    }
}
