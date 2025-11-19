
import UIKit
import Firebase
import FirebaseMessaging
import CommonCrypto
import SwiftUI
import FirebaseAuth

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

    @StateObject private var cryptoManager = CryptoManager.shared

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        print("🚀 App launching...")
        
        // Configure Firebase FIRST
        FirebaseApp.configure()
        print("✅ Firebase configured")
        
        // Set delegates
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        print("✅ Delegates set")
        
        // Request notification permissions
        requestNotificationPermissions(application)
        
        return true
    }

    private func requestNotificationPermissions(_ application: UIApplication) {
        print("📱 Requesting notification permissions...")
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("❌ Permission error: \(error.localizedDescription)")
                return
            }
            
            print("✅ Permission granted: \(granted)")
            
            if granted {
                DispatchQueue.main.async {
                    print("📲 Registering for remote notifications...")
                    application.registerForRemoteNotifications()
                }
            } else {
                print("⚠️ User denied notification permission")
            }
        }
    }

    // MARK: - APNs Token Registration
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
        print("🔐 Device Token Received: \(tokenString)")
        
        // Set APNs token for Firebase Auth
        Auth.auth().setAPNSToken(deviceToken, type: .unknown)
        print("✅ APNs token set for Firebase Auth")
        
        // Set APNs token for Firebase Messaging
        Messaging.messaging().apnsToken = deviceToken
        print("✅ APNs token set for Firebase Messaging")
        
        // Now request FCM token since APNs is ready
        print("🔄 Requesting FCM token now that APNs is ready...")
        requestFCMToken()
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
        print("💡 Tip: Make sure you're testing on a real device, not simulator")
    }

    // MARK: - FCM Token Request
    private func requestFCMToken() {
        Messaging.messaging().token { token, error in
            if let error = error {
                print("❌ Error getting FCM token: \(error.localizedDescription)")
                return
            }
            
            guard let token = token else {
                print("⚠️ FCM token is nil")
                return
            }
            
            print("🔑 FCM Token received: \(token)")
            
            // Save and upload
            self.handleFCMToken(token)
        }
    }

    // MARK: - MessagingDelegate
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken = fcmToken else {
            print("❌ FCM Token is nil in delegate")
            return
        }
        
        print("🔑 FCM Token refreshed: \(fcmToken)")
        handleFCMToken(fcmToken)
    }

    // MARK: - Handle FCM Token
    private func handleFCMToken(_ token: String) {
        print("💾 Processing FCM token...")
        
        // Update manager
        Task {
            await FCMTokenManager.shared.setToken(token)
        }
        
        // Upload to Firestore
        uploadFCMToken(token)
        
        // Notify observers
        NotificationCenter.default.post(
            name: NSNotification.Name("FCMTokenReceived"),
            object: nil,
            userInfo: ["token": token]
        )
    }

    func uploadFCMToken(_ token: String) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⚠️ No user logged in, saving token locally for later upload")
            // Save for later when user logs in
            UserDefaults.standard.set(token, forKey: "pendingFCMToken")
            return
        }
        
        print("📤 Uploading FCM token to Firestore for user: \(userId)")
        
        let db = Firestore.firestore()
        db.collection("users").document(userId).updateData([
            "fcmToken": token,
            "tokenUpdatedAt": FieldValue.serverTimestamp(),
            "platform": "iOS"
        ]) { error in
            if let error = error {
                print("❌ Failed to upload FCM token: \(error.localizedDescription)")
            } else {
                print("✅ FCM token uploaded successfully")
                UserDefaults.standard.removeObject(forKey: "pendingFCMToken")
            }
        }
    }

    // MARK: - Remote Notifications
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification notification: [AnyHashable : Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        
        if Auth.auth().canHandleNotification(notification) {
            completionHandler(.noData)
            return
        }
        
        print("📬 Remote notification: \(notification)")

        // Check if notification contains encrypted data and decrypt it
        if let encryptedPaymentDetails = notification["payment_details"] as? String {
            if let decryptedPaymentDetails = cryptoManager.decrypt(encryptedData: encryptedPaymentDetails) {
                print("Decrypted Payment Details: \(decryptedPaymentDetails)")
                // Optionally, you can update the notification content here or pass the decrypted data to a view
            } else {
                print("Failed to decrypt payment details.")
            }
        }
        
        completionHandler(.newData)
    }

    func application(_ application: UIApplication, open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        if Auth.auth().canHandle(url) {
            return true
        }
        return false
    }

    // MARK: - Foreground Notifications
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        var userInfo = notification.request.content.userInfo
        print("📬 Foreground notification: \(userInfo)")

        // Example: Decrypt encrypted payment details if present
        if let encryptedPaymentDetails = userInfo["payment_details"] as? String {
            if let decryptedPaymentDetails = cryptoManager.decrypt(encryptedData: encryptedPaymentDetails) {
                // Update userInfo with decrypted data
                userInfo["payment_details"] = decryptedPaymentDetails
                print("Decrypted Payment Details: \(decryptedPaymentDetails)")
            } else {
                print("Failed to decrypt payment details.")
            }
        }

        // You may now create a custom local notification or handle the decrypted content as needed
        // Present the notification with the decrypted content
        let newContent = UNMutableNotificationContent()
        newContent.title = notification.request.content.title
        newContent.body = "Payment received: \(userInfo["payment_details"] ?? "Unknown")"
        newContent.sound = .default

        // Create a new notification request with the updated content
        let request = UNNotificationRequest(
            identifier: notification.request.identifier,
            content: newContent,
            trigger: notification.request.trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to update notification: \(error.localizedDescription)")
            }
        }
        
        // Continue presenting the updated notification
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        var userInfo = response.notification.request.content.userInfo
        print("👆 Notification tapped: \(userInfo)")

        // Example: Decrypt encrypted payment details if present
        if let encryptedPaymentDetails = userInfo["payment_details"] as? String {
            if let decryptedPaymentDetails = cryptoManager.decrypt(encryptedData: encryptedPaymentDetails) {
                userInfo["payment_details"] = decryptedPaymentDetails
                print("Decrypted Payment Details: \(decryptedPaymentDetails)")
            } else {
                print("Failed to decrypt payment details.")
            }
        }

        if let type = userInfo["type"] as? String {
            handleNotificationAction(type: type, data: userInfo)
        }

        completionHandler()
    }

    private func handleNotificationAction(type: String, data: [AnyHashable: Any]) {
        print("🎯 Notification action: \(type)")

        NotificationCenter.default.post(
            name: NSNotification.Name("NotificationActionReceived"),
            object: nil,
            userInfo: data as? [String: Any]
        )
        
        switch type {
        case "message":
            print("📨 Opening messages")
        case "wallet":
            print("💰 Opening wallet")
        case "task":
            print("✅ Opening task")
        default:
            print("🤷‍♂️ Unknown type: \(type)")
        }
    }
}

