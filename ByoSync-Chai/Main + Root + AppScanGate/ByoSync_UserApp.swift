// ByoSync_UserApp.swift

import SwiftUI
import FirebaseAuth
import UIKit

@main
struct ByoSync_UserApp: App {
    @StateObject private var cryptoManager = CryptoManager()
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject var userSession = UserSession.shared
    @StateObject private var socketManager = SocketIOManager.shared
    @StateObject private var scanGate = AppScanGate.shared
    @StateObject private var faceAuthManager = FaceAuthManager.shared
    @StateObject private var enrollmentGate = EnrollmentGate.shared
    


    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @Environment(\.scenePhase) private var scenePhase
    
    // ✅ guarantees we don't accidentally log twice
        private static var didLogAppStart = false
    
    
    
    // CHAI App
    
    var isDeviceAdded: Bool{
       // UserDefaults.standard.string(forKey: "chaiDeviceId") != nil
        KeychainHelper.shared.read(forKey: "chaiDeviceId") != nil
    }

    init() {
         if !Self.didLogAppStart {
             Self.didLogAppStart = true
           // Logger.shared.info("APP_STARTED bundle=\(Bundle.main.bundleIdentifier ?? "unknown")", type: .success)
         }
     }
    
    var body: some Scene {
        WindowGroup {
            NavigationStack{
            ZStack {
                    if isDeviceAdded {
                        EnterNumberToSearchUserView()
                    }else{
                        AddDeviceView()
                    }
                }
            }
            .environmentObject(faceAuthManager)
            .environmentObject(enrollmentGate)
            .environmentObject(scanGate)
            .preferredColorScheme(.light)
            .onOpenURL { url in
                Auth.auth().canHandle(url)
            }
            .onAppear {
                socketManager.connect()
                print("DeviceKeyHash:\(DeviceIdentity.resolve())")
                
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                print("🔄 [APP] Scene phase changed: \(oldPhase) -> \(newPhase)")

                // Only enforce re-scan if user is already logged in
                let isLoggedIn = (userSession.currentUser != nil)
                let isUserAccount = (UserDefaults.standard.string(forKey: "accountType") == "user")

                // Mark required only when leaving foreground
                if oldPhase == .active,
                   (newPhase == .inactive || newPhase == .background),
                   isLoggedIn,
                   isUserAccount,
                   enrollmentGate.isEnrolled
                {
                    print("🔐 [APP] Leaving foreground -> require verification scan on return")
                    scanGate.markRequiredDueToInactive()
                }

                switch newPhase {
                case .active:
                    socketManager.connectIfNeeded()
                case .inactive, .background:
                    socketManager.disconnect()
                @unknown default:
                    break
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                // Optional: extra safety if app is killed
                if userSession.currentUser != nil,
                   UserDefaults.standard.string(forKey: "accountType") == "user" {
                    print("🧨 [APP] willTerminate -> require scan on next launch")
                    scanGate.markRequiredOnTerminate()
                }
            }
        }
    }
}
