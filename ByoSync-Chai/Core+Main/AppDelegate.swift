import UIKit
import Firebase
import FirebaseMessaging
import CommonCrypto
import SwiftUI
import FirebaseAuth

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

    private let cryptoManager = CryptoManager.shared

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        #if DEBUG
        print("🚀 App launching...")
        #endif

        FirebaseApp.configure()

        #if DEBUG
        print("✅ Firebase configured")
        #endif

        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self

        #if DEBUG
        print("✅ Delegates set")
        #endif

        requestNotificationPermissions(application)
        return true
    }

    private func requestNotificationPermissions(_ application: UIApplication) {
        #if DEBUG
        print("📱 Requesting notification permissions...")
        #endif

        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in

                if let error = error {
                    #if DEBUG
                    print("❌ Permission error: \(error.localizedDescription)")
                    #endif
                    return
                }

                #if DEBUG
                print("✅ Permission granted: \(granted)")
                #endif

                if granted {
                    DispatchQueue.main.async {
                        #if DEBUG
                        print("📲 Registering for remote notifications...")
                        #endif
                        application.registerForRemoteNotifications()
                    }
                } else {
                    #if DEBUG
                    print("⚠️ User denied notification permission")
                    #endif
                }
            }
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()

        #if DEBUG
        print("🔐 Device Token Received: \(tokenString)")
        #endif

        Auth.auth().setAPNSToken(deviceToken, type: .unknown)

        #if DEBUG
        print("✅ APNs token set for Firebase Auth")
        #endif

        Messaging.messaging().apnsToken = deviceToken

        #if DEBUG
        print("✅ APNs token set for Firebase Messaging")
        print("🔄 Requesting FCM token now that APNs is ready...")
        #endif

        requestFCMToken()
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        #if DEBUG
        print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
        print("💡 Tip: Test on a real device, not simulator")
        #endif
    }

    private func requestFCMToken() {
        Messaging.messaging().token { token, error in
            if let error = error {
                #if DEBUG
                print("❌ Error getting FCM token: \(error.localizedDescription)")
                #endif
                return
            }

            guard let token = token else {
                #if DEBUG
                print("⚠️ FCM token is nil")
                #endif
                return
            }

            #if DEBUG
            print("🔑 FCM Token received: \(token)")
            #endif

            self.handleFCMToken(token)
        }
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken = fcmToken else {
            #if DEBUG
            print("❌ FCM Token is nil in delegate")
            #endif
            return
        }

        #if DEBUG
        print("🔑 FCM Token refreshed: \(fcmToken)")
        #endif

        handleFCMToken(fcmToken)
    }

    private func handleFCMToken(_ token: String) {
        #if DEBUG
        print("💾 Processing FCM token...")
        #endif

        FCMTokenManager.shared.setToken(token)
        uploadFCMToken(token)

        NotificationCenter.default.post(
            name: NSNotification.Name("FCMTokenReceived"),
            object: nil,
            userInfo: ["token": token]
        )
    }

    func uploadFCMToken(_ token: String) {
        guard let userId = Auth.auth().currentUser?.uid else {
            #if DEBUG
            print("⚠️ No user logged in, saving token locally")
            #endif
            UserDefaults.standard.set(token, forKey: "pendingFCMToken")
            return
        }

        #if DEBUG
        print("📤 Uploading FCM token for user: \(userId)")
        #endif

        let db = Firestore.firestore()
        db.collection("users").document(userId).updateData([
            "fcmToken": token,
            "tokenUpdatedAt": FieldValue.serverTimestamp(),
            "platform": "iOS"
        ]) { error in
            if let error = error {
                #if DEBUG
                print("❌ Failed to upload FCM token: \(error.localizedDescription)")
                #endif
            } else {
                #if DEBUG
                print("✅ FCM token uploaded successfully")
                #endif
                UserDefaults.standard.removeObject(forKey: "pendingFCMToken")
            }
        }
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification notification: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        if Auth.auth().canHandleNotification(notification) {
            completionHandler(.noData)
            return
        }

        #if DEBUG
        print("📬 Remote notification: \(notification)")
        #endif

        if let encryptedPaymentDetails = notification["payment_details"] as? String {
            if let decrypted = cryptoManager.decrypt(encryptedData: encryptedPaymentDetails) {
                #if DEBUG
                print("Decrypted Payment Details: \(decrypted)")
                #endif
            } else {
                #if DEBUG
                print("Failed to decrypt payment details")
                #endif
            }
        }

        completionHandler(.newData)
    }

    func application(
        _ application: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        Auth.auth().canHandle(url)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let content = notification.request.content
        let userInfo = content.userInfo

        #if DEBUG
        print("📬 Foreground notification: \(userInfo)")
        print("📨 Original title = \(content.title)")
        print("📨 Original body  = \(content.body)")
        #endif

        let decryptedBody = decryptPaymentBodyIfNeeded(content.body)

        let newContent = UNMutableNotificationContent()
        newContent.title = content.title
        newContent.body = decryptedBody
        newContent.sound = .defaultCritical
        newContent.userInfo = userInfo

        let request = UNNotificationRequest(
            identifier: notification.request.identifier + "-decrypted",
            content: newContent,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            #if DEBUG
            if let error = error {
                print("❌ Failed to show decrypted notification: \(error.localizedDescription)")
            } else {
                print("✅ Decrypted foreground notification scheduled")
            }
            #endif
        }

        completionHandler([])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        var userInfo = response.notification.request.content.userInfo

        #if DEBUG
        print("👆 Notification tapped: \(userInfo)")
        #endif

        if let encrypted = userInfo["payment_details"] as? String,
           let decrypted = cryptoManager.decrypt(encryptedData: encrypted) {
            userInfo["payment_details"] = decrypted

            #if DEBUG
            print("Decrypted Payment Details: \(decrypted)")
            #endif
        }

        if let type = userInfo["type"] as? String {
            handleNotificationAction(type: type, data: userInfo)
        }

        completionHandler()
    }

    private func decryptPaymentBodyIfNeeded(_ body: String) -> String {
        let decrypted = cryptoManager.decryptPaymentMessage(body)

        #if DEBUG
        print("🔍 INPUT  = \(body)")
        print("🔍 OUTPUT = \(decrypted)")
        #endif

        return decrypted.isEmpty ? body : decrypted
    }

    private func handleNotificationAction(type: String, data: [AnyHashable: Any]) {
        #if DEBUG
        print("🎯 Notification action: \(type)")
        #endif

        NotificationCenter.default.post(
            name: NSNotification.Name("NotificationActionReceived"),
            object: nil,
            userInfo: data as? [String: Any]
        )

        #if DEBUG
        switch type {
        case "message": print("📨 Opening messages")
        case "wallet":  print("💰 Opening wallet")
        case "task":    print("✅ Opening task")
        default:        print("🤷‍♂️ Unknown type: \(type)")
        }
        #endif
    }
}
