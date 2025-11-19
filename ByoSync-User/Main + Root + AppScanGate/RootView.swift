// RootView.swift
import SwiftUI
import AVFoundation

private enum AppStep {
    case loading, auth, consent, cameraPrep, mlScan, mainTab
}

struct RootView: View {
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var scanGate: AppScanGate
    @EnvironmentObject var router: Router
    
    @State private var step: AppStep = .loading
    @State private var consentAccepted = false
    @State private var cameraPermissionGranted = false
    
    private let consentKey = "consentAccepted"
    
    var body: some View {
        Group {
            switch step {
            case .loading:
                SplashScreenView()
                
            case .auth:
                AuthenticationView()
                
            case .consent:
                UserConsentView(onComplete: {
                    consentAccepted = true
                    UserDefaults.standard.set(true, forKey: consentKey)
                    print("✅ Consent accepted, moving to camera prep")
                    withAnimation(.easeInOut) { step = .cameraPrep }
                })
                
            case .cameraPrep:
                CameraPreparationView(onReady: {
                    print("✅ Camera ready, moving to ML scan")
                    cameraPermissionGranted = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            step = .mlScan
                        }
                    }
                })
                
            case .mlScan:
                MLScanView(onDone: {
                    print("✅ ML scan completed")
                    scanGate.markScanCompleted()
                    withAnimation(.easeInOut) { step = .mainTab }
                })
                
            case .mainTab:
                MainTabView()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.98)),
                        removal: .opacity.combined(with: .move(edge: .trailing))
                    ))
            }
        }
        .onAppear {
            print("🚀 RootView appeared")
            userSession.loadUser()
            consentAccepted = UserDefaults.standard.bool(forKey: consentKey)
            scanGate.reloadFromStorage()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                step = nextStep()
                print("📍 Moving to step: \(step)")
            }
        }
        .onChange(of: userSession.currentUser) { _, _ in
            step = nextStep()
            print("👤 User changed, step: \(step)")
        }
        .onChange(of: scanGate.requireScan) { _, _ in
            step = nextStep()
            print("📸 Scan requirement changed, step: \(step)")
        }
    }
    
    private func nextStep() -> AppStep {
        guard let accountType = UserDefaults.standard.string(forKey: "accountType"),
              accountType == "user" else {
            print("⚠️ Not a user account")
            return .auth
        }
        
        guard userSession.currentUser != nil else {
            print("⚠️ No current user")
            return .auth
        }
        
        if !consentAccepted {
            print("📋 Consent not accepted")
            return .consent
        }
        if scanGate.requireScan {
            print("📸 Scan required, checking camera prep")
            return cameraPermissionGranted ? .mlScan : .cameraPrep
        }
        print("✅ All checks passed, going to main tab")
        return .mainTab
    }
}


// Camera preparation view - handles permissions and pre-initialization
struct CameraPreparationView: View {
    let onReady: () -> Void
    
    @State private var permissionStatus: PermissionStatus = .checking
    @State private var isPreparingCamera = false
    
    private enum PermissionStatus {
        case checking, granted, denied, restricted
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(UIColor.systemGroupedBackground),
                    Color(UIColor.secondarySystemGroupedBackground)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
              
                ProgressView()
                Text(statusMessage)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                if permissionStatus == .checking || isPreparingCamera {
                    ProgressView()
                        .scaleEffect(1.2)
                        .padding(.top, 8)
                }
                
                if permissionStatus == .denied || permissionStatus == .restricted {
                    Button("Open Settings") {
                        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(settingsUrl)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 16)
                }
            }
            .padding()
        }
        .onAppear {
            print("📸 Camera preparation view appeared")
            checkAndRequestCameraPermission()
        }
    }
    
    private var statusMessage: String {
        switch permissionStatus {
        case .checking:
            return "Checking permissions..."
        case .granted:
            return isPreparingCamera ? "Preparing model..." : "All Set!"
        case .denied:
            return "Camera access is required.\nPlease enable it in Settings."
        case .restricted:
            return "Camera access is restricted on this device."
        }
    }
    
    private func checkAndRequestCameraPermission() {
        print("📸 Checking camera permission status")
        
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            print("✅ Camera already authorized")
            permissionStatus = .granted
            prepareCamera()
            
        case .notDetermined:
            print("❓ Camera permission not determined, requesting...")
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        print("✅ Camera permission granted")
                        permissionStatus = .granted
                        prepareCamera()
                    } else {
                        print("❌ Camera permission denied")
                        permissionStatus = .denied
                    }
                }
            }
            
        case .denied:
            print("❌ Camera permission previously denied")
            permissionStatus = .denied
            
        case .restricted:
            print("⚠️ Camera access restricted")
            permissionStatus = .restricted
            
        @unknown default:
            print("⚠️ Unknown camera permission status")
            permissionStatus = .denied
        }
    }
    
    private func prepareCamera() {
        print("🎬 Starting camera preparation")
        isPreparingCamera = true
        
        // Prepare camera session on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            print("🔧 Initializing camera session...")
            
            // Simulate/perform camera initialization
            let captureSession = AVCaptureSession()
            captureSession.sessionPreset = .high
            
            // Check if camera is available
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                print("❌ No camera device found")
                DispatchQueue.main.async {
                    isPreparingCamera = false
                    permissionStatus = .denied
                }
                return
            }
            
            print("✅ Camera device found: \(videoDevice.localizedName)")
            
            // Small delay to ensure everything is ready
            Thread.sleep(forTimeInterval: 0.3)
            
            DispatchQueue.main.async {
                print("✅ Camera preparation complete")
                isPreparingCamera = false
                
                // Smooth transition to scan view
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onReady()
                }
            }
        }
    }
}


// Enhanced splash screen with smooth animations
struct SplashScreenView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Animated gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(UIColor.systemGroupedBackground),
                    Color(UIColor.secondarySystemGroupedBackground)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Animated circle in background
            Circle()
                .fill(Color(hex: "4B548D").opacity(0.08))
                .frame(width: 400, height: 400)
                .blur(radius: 60)
                .scaleEffect(isAnimating ? 1.1 : 1.0)
                .offset(y: isAnimating ? 20 : -20)
            
            VStack(spacing: 30) {
                // Animated progress indicator
                ProgressView()
                    .scaleEffect(isAnimating ? 1.0 : 0.8, anchor: .center)
                    .padding(.bottom, 40)
            }
            .padding()
        }
        .onAppear {
            print("🎨 Splash screen appeared")
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(UserSession.shared)
}
