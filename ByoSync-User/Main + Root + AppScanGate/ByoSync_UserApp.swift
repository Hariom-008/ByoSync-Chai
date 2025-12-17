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

    @StateObject private var router = Router()   // ✅ NEW

    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $router.path) {
                FetchUserByPhoneView()
                    .navigationDestination(for: Route.self) { route in
                        RouteDestinationView.routeView(for: route)
                            .environmentObject(router)
                            .environmentObject(userSession)
                            .environmentObject(faceAuthManager)
                            .environment(\.locale, .init(identifier: languageManager.currentLanguageCode))
                            .environmentObject(cryptoManager)
                    }
                    .sheet(item: $router.presentedSheet) { route in
                        RouteDestinationView.routeView(for: route)
                            .environmentObject(router)
                            .environmentObject(userSession)
                            .environmentObject(faceAuthManager)
                            .environment(\.locale, .init(identifier: languageManager.currentLanguageCode))
                            .environmentObject(cryptoManager)
                    }
                    .fullScreenCover(item: $router.presentedFullScreen) { route in
                        RouteDestinationView.routeView(for: route)
                            .environmentObject(router)
                            .environmentObject(userSession)
                            .environmentObject(faceAuthManager)
                            .environment(\.locale, .init(identifier: languageManager.currentLanguageCode))
                            .environmentObject(cryptoManager)
                    }
                    .environmentObject(router)
                    .environmentObject(userSession)
                    .environmentObject(faceAuthManager)
                    .environment(\.locale, .init(identifier: languageManager.currentLanguageCode))
                    .preferredColorScheme(.light)
                    .environmentObject(cryptoManager)
            }
            .onAppear {
                socketManager.connect()
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .active:
                    socketManager.connectIfNeeded()
                case .inactive:
                    scanGate.markRequiredDueToInactive()
                    socketManager.disconnect()
                case .background:
                    socketManager.disconnect()
                @unknown default:
                    break
                }
            }
        }
    }
}
