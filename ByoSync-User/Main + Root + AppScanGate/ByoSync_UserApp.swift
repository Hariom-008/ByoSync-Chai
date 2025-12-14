// ByoSync_UserApp.swift
import SwiftUI
import Firebase
import UIKit
import FirebaseAuth
import FirebaseMessaging
import Combine

@main
struct ByoSync_UserApp: App {
    @StateObject private var cryptoManager = CryptoManager()
    
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject var userSession = UserSession.shared
    @StateObject private var socketManager = SocketIOManager.shared
    @StateObject private var scanGate = AppScanGate.shared
    @StateObject private var faceAuthManager = FaceAuthManager.shared
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ZStack {
                RouterView {
                    RootView()
                }
                .environmentObject(userSession)
                .environmentObject(languageManager)
                .environmentObject(faceAuthManager)
                .environment(\.locale, .init(identifier: languageManager.currentLanguageCode))
                .preferredColorScheme(.light)
                .environmentObject(cryptoManager)
                .environmentObject(scanGate)
                
                GlobalPaymentOverlayView()
            }
            .onAppear {
                print("🚀 [APP] App appeared, connecting socket")
                socketManager.connect()
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                print("🔄 [APP] Scene phase changed: \(oldPhase) -> \(newPhase)")
                switch newPhase {
                case .active:
                    print("✅ [APP] App active - connecting socket")
                    socketManager.connectIfNeeded()
                    
                case .inactive:
                    print("⏸️ [APP] App inactive - requiring scan and disconnecting socket")
                    // 🔒 Rule: if app becomes INACTIVE we require scan next time
                    scanGate.markRequiredDueToInactive()
                    socketManager.disconnect()
                    
                case .background:
                    print("📱 [APP] App background - disconnecting socket (no scan flag change)")
                    // Do NOT change scan flag here (per your rule)
                    socketManager.disconnect()
                    
                @unknown default:
                    print("⚠️ [APP] Unknown scene phase: \(newPhase)")
                    break
                }
            }
        }
    }
}
