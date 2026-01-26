//import SwiftUI
//internal import AVFoundation
//
//private enum AppStep {
//    case loading, auth, consent, cameraPrep, mlScan, mainTab
//}
//
//private enum LaunchDeviceState {
//    case unknown
//    case registered
//    case notRegistered
//}
//
//struct RootView: View {
//    @EnvironmentObject var userSession: UserSession
//    @EnvironmentObject var scanGate: AppScanGate
//    @EnvironmentObject var router: Router
//    @EnvironmentObject var faceAuthManager: FaceAuthManager
//    @EnvironmentObject var enrollmentGate: EnrollmentGate
//
//    @StateObject private var deviceRegistrationVM = DeviceRegistrationViewModel()
//    @StateObject private var fetchUserByIdVM = UserDataByIdViewModel()
//
//    @State private var step: AppStep = .loading
//    @State private var consentAccepted = false
//    private let consentKey = "consentAccepted"
//
//    @State private var didRunLaunchDeviceCheck = false
//    @State private var launchDeviceState: LaunchDeviceState = .unknown
//    @State private var launchHasFaceData: Bool? = nil
//
//    // ✅ Key: only use launch routing until user is logged in
//    @State private var launchRoutingActive = true
//
//    private var hasCameraPermission: Bool {
//        AVCaptureDevice.authorizationStatus(for: .video) == .authorized
//    }
//
//    var body: some View {
//        Group {
//            switch step {
//            case .loading:
//                SplashScreenView()
//
//            case .auth:
//                AuthenticationView()
//
//            case .consent:
//                UserConsentView(onComplete: {
//                    consentAccepted = true
//                    UserDefaults.standard.set(true, forKey: consentKey)
//                    withAnimation(.easeInOut) { step = .cameraPrep }
//                })
//
//            case .cameraPrep:
//                CameraPreparationView(onReady: {
//                    withAnimation(.easeInOut(duration: 0.3)) { step = .mlScan }
//                })
//
//            case .mlScan:
//                MLScanView(onDone: {
//                    scanGate.markScanCompleted()
//
//                    // OK: backend refresh, does NOT touch UserSession persistence
//                    fetchUserByIdVM.fetch(
//                        userId: userSession.currentUserID,
//                        deviceKeyHash: HMACGenerator.generateHMAC(jsonString: DeviceIdentity.resolve())
//                    )
//
//                    // ❌ REMOVE: userSession.loadUser()
//                    // This can cause re-evaluation / step flip during transitions.
//                    enrollmentGate.reload()
//
//                    // stop any launch gating once scan is done
//                    launchRoutingActive = false
//                    launchDeviceState = .unknown
//                    launchHasFaceData = nil
//
//                    withAnimation(.easeInOut) { step = nextStep() }
//                })
//
//            case .mainTab:
//                MainTabView()
//            }
//        }
//        .onAppear {
//            // ✅ Only load from disk if we don't already have a session in memory.
//            if userSession.currentUser == nil {
//                userSession.loadUser()
//            }
//
//            enrollmentGate.reload()
//            consentAccepted = UserDefaults.standard.bool(forKey: consentKey)
//            scanGate.reloadFromStorage()
//
//            // If already logged in, never run launch routing
//            if userSession.currentUser != nil {
//                launchRoutingActive = false
//                step = nextStep()
//                return
//            }
//
//            // run launch device check once
//            guard !didRunLaunchDeviceCheck else {
//                step = nextStep()
//                return
//            }
//            didRunLaunchDeviceCheck = true
//
//            let deviceKey = DeviceIdentity.resolve()
//            if deviceKey.isEmpty {
//                launchDeviceState = .notRegistered
//                launchHasFaceData = nil
//                step = nextStep()
//                return
//            }
//
//            launchDeviceState = .unknown
//            launchHasFaceData = nil
//            deviceRegistrationVM.checkDeviceRegistration()
//        }
//        .onChange(of: deviceRegistrationVM.isLoading) { _, isLoading in
//            guard didRunLaunchDeviceCheck else { return }
//            guard !isLoading else { return }
//            guard launchRoutingActive else { return } // ✅ ignore once logged in
//
//            if deviceRegistrationVM.isDeviceRegistered {
//                launchDeviceState = .registered
//                launchHasFaceData = deviceRegistrationVM.hasFaceData
//            } else {
//                launchDeviceState = .notRegistered
//                launchHasFaceData = nil
//            }
//
//            step = nextStep()
//        }
//        .onChange(of: userSession.currentUser) { _, newUser in
//            // ✅ the moment login sets currentUser, disable launch routing forever
//            if newUser != nil {
//                launchRoutingActive = false
//                launchDeviceState = .unknown
//                launchHasFaceData = nil
//                enrollmentGate.reload()
//            }
//            step = nextStep()
//        }
//        .onChange(of: scanGate.requireScan) { _, _ in
//            step = nextStep()
//        }
//    }
//
//    private func nextStep() -> AppStep {
//        // ✅ Launch routing only when NOT logged in
//        if launchRoutingActive {
//            switch launchDeviceState {
//            case .notRegistered:
//                return .auth
//
//            case .registered:
//                guard let hasFaceData = launchHasFaceData else { return .loading }
//
//                if hasFaceData {
//                    faceAuthManager.setVerificationMode()
//                } else {
//                    faceAuthManager.setRegistrationMode()
//                }
//                return hasCameraPermission ? .mlScan : .cameraPrep
//
//            case .unknown:
//                return .loading
//            }
//        }
//
//        // ---- Normal logic ----
//        guard userSession.currentUser != nil else { return .auth }
//
//        if enrollmentGate.needsEnrollment {
//            faceAuthManager.setRegistrationMode()
//            return hasCameraPermission ? .mlScan : .cameraPrep
//        }
//
//        if scanGate.requireScan {
//            faceAuthManager.setVerificationMode()
//            return hasCameraPermission ? .mlScan : .cameraPrep
//        }
//
//        return .mainTab
//    }
//}
//
//#Preview {
//    RootView()
//        .environmentObject(UserSession.shared)
//}
