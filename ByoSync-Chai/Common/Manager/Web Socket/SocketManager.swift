import Foundation
import SwiftUI
import SocketIO
import Combine

final class SocketIOManager: ObservableObject {
    static let shared = SocketIOManager()

    @Published var isConnected = false
    @Published var receivedMessages: [PaymentNotification] = []
    @Published var connectionStatus = "Disconnected"
    @Published var socketId: String = ""

    @Published var showPaymentOverlay = false
    @Published var currentPaymentNotification: PaymentNotification?

    private var manager: SocketManager!
    private var socket: SocketIOClient!
    private var isManualDisconnect = false

    private init(urlString: String = "https://backendapi.byosync.in") {
        setupSocket(urlString: urlString)
    }

    private func setupSocket(urlString: String) {
        guard let url = URL(string: urlString) else { return }

        manager = SocketManager(socketURL: url, config: [
            .log(false),
            .compress,
            .reconnects(true),
            .reconnectWait(2),
            .reconnectAttempts(-1)
        ])
        socket = manager.defaultSocket
        setupEventListeners()
    }

    private func setupEventListeners() {
        socket.on(clientEvent: .connect) { [weak self] _, _ in
            guard let self else { return }
            DispatchQueue.main.async {
                self.isConnected = true
                self.connectionStatus = "Connected"
                self.socketId = self.socket.sid ?? ""
                print("✅ Connected: \(self.socketId)")
                self.registerUser(userId: UserSession.shared.currentUser?.userId ?? "")
            }
        }

        socket.on(clientEvent: .disconnect) { [weak self] _, _ in
            guard let self else { return }
            DispatchQueue.main.async {
                self.isConnected = false
                self.connectionStatus = "Disconnected"
                print("❌ Disconnected")
            }
        }

        socket.on(clientEvent: .error) { [weak self] data, _ in
            DispatchQueue.main.async {
                self?.connectionStatus = "Error: \(data)"
                print("⚠️ Socket error: \(data)")
            }
        }

        socket.on(clientEvent: .reconnect) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.connectionStatus = "Reconnected"
                print("🔄 Reconnected to server")
            }
        }

        socket.on("paymentReceived") { [weak self] data, _ in
            self?.handlePaymentReceived(data)
        }

        socket.on("message") { data, _ in
            print("📨 Received message:", data)
        }
    }

    private func handlePaymentReceived(_ data: [Any]) {
        DispatchQueue.main.async {
            do {
                if let dict = data.first as? [String: Any] {
                    let jsonData = try JSONSerialization.data(withJSONObject: dict)
                    let response = try JSONDecoder().decode(PaymentReceivedResponse.self, from: jsonData)
                    let notification = PaymentNotification(
                        id: response.order.id,
                        amount: Double(response.order.coins),
                        currency: "Coins",
                        senderId: response.order.senderId,
                        timestamp: Date(),
                        transactionId: response.order.id,
                        message: response.message,
                        orderType: response.order.type
                    )
                    self.receivedMessages.append(notification)
                    self.currentPaymentNotification = notification
                    self.showPaymentOverlay = true
                    print("✅ Payment notification:", notification)
                }
            } catch {
                print("❌ Error parsing payment:", error)
            }
        }
    }

    func connect() {
        guard !isConnected else { return }
        print("🔌 Connecting socket…")
        isManualDisconnect = false
        connectionStatus = "Connecting..."
        socket.connect()
    }

    func connectIfNeeded() {
        if !isConnected && !isManualDisconnect {
            connect()
        }
    }

    func disconnect() {
        guard isConnected else { return }
        print("🔌 Disconnecting socket")
        isManualDisconnect = true
        socket.disconnect()
        isConnected = false
        connectionStatus = "Disconnected"
    }

    func registerUser(userId: String) {
        guard !userId.isEmpty else { return }
        socket.emit("registerUser", userId)
        print("📤 Registered user:", userId)
    }

    func sendMessage(_ message: String) {
        socket.emit("message", message)
        print("📤 Sent message:", message)
    }

    func emitEvent(event: String, data: Any) {
        socket.emit(event, data as! SocketData)
        print("📤 Emitted event '\(event)' with data:", data)
    }

    func dismissCurrentPayment() {
        withAnimation {
            showPaymentOverlay = false
            currentPaymentNotification = nil
        }
    }
}
