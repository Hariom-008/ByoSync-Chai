import SwiftUI
internal import AVFoundation
import MediaPipeTasksVision
import Combine
import UIKit
import CoreImage

@MainActor
struct FaceDetectionView: View {

    // Core managers
    @StateObject private var faceManager: FaceManager
    @StateObject private var cameraSpecManager: CameraSpecManager

    // NCNN liveness model
    @StateObject private var ncnnViewModel = NcnnLivenessViewModel()

    // Backend FaceId VMs
    @StateObject private var faceIdUploadViewModel = FaceIdViewModel()
    @StateObject private var fetchUserByTokenViewModel = FetchUserByTokenViewModel()

    // Auth / device identity
    let authToken: String
    let onComplete: () -> Void

    // UI State
    @State private var showAlert: Bool = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""
    
    // ✅ FIXED: Separate processing states to avoid blocking camera
    @State private var isUploadingFrames: Bool = false
    @State private var isVerifying: Bool = false

    // ✅ Face auth mode manager
    @EnvironmentObject var faceAuthManager: FaceAuthManager
    @EnvironmentObject var enrollmentGate: EnrollmentGate

    // ✅ Auto-trigger tracking
    @State private var hasAutoTriggered: Bool = false

    // ✅ Token copy toast
    @State private var showCopyToast: Bool = false

    // CHAI credentials
    let userId: String
    let deviceKeyHash: String
    let token: Int

    // ✅ FIXED: Track if initial fetch is done (don't block camera for this)
    @State private var initialFetchComplete: Bool = false

    // MARK: - Init
    init(
        authToken: String,
        onComplete: @escaping () -> Void,
        userId: String,
        deviceKeyHash: String,
        token: Int
    ) {
        self.authToken = authToken

        let camSpecManager = CameraSpecManager()
        _cameraSpecManager = StateObject(wrappedValue: camSpecManager)
        _faceManager = StateObject(wrappedValue: FaceManager(cameraSpecManager: camSpecManager))
        self.onComplete = onComplete
        self.userId = userId
        self.deviceKeyHash = deviceKeyHash
        self.token = token
    }

    // MARK: - Derived UI state

    // ✅ FIXED: Only block UI when actually processing frames, not during initial fetch
    private var shouldShowProcessingOverlay: Bool {
        isUploadingFrames || isVerifying
    }

    // ✅ FIXED: Sync busy state only for frame processing
    private func updateBusyState() {
        faceManager.setBusy(shouldShowProcessingOverlay)
    }

    private var tokenFetchLoaded: Bool {
        initialFetchComplete
    }

    private var backendEnrollmentValid: Bool {
        guard let salt = fetchUserByTokenViewModel.salt, !salt.isEmpty else { return false }
        return !fetchUserByTokenViewModel.faceIds.isEmpty
    }

    private var currentModeText: String {
        switch faceAuthManager.currentMode {
        case .registration: return "Registration"
        case .verification: return "Verification"
        }
    }

    private var currentModeIcon: String {
        switch faceAuthManager.currentMode {
        case .registration: return "person.badge.plus.fill"
        case .verification: return "lock.shield.fill"
        }
    }

    private var currentModeColor: Color {
        switch faceAuthManager.currentMode {
        case .registration: return .green
        case .verification: return .blue
        }
    }

    private var targetFrameCount: Int {
        switch faceAuthManager.currentMode {
        case .registration: return 60
        case .verification: return 10
        }
    }

    private var verificationTarget: Int { 10 }

    private var topCounterText: String {
        switch faceAuthManager.currentMode {
        case .registration:
            switch faceManager.registrationPhase {
            case .centerCollecting:
                return "Center \(faceManager.centerFramesCount)/60"
            case .movementCollecting:
                return "Move \(faceManager.movementFramesCount) • \(faceManager.movementSecondsRemaining)s"
            case .done:
                return "Processing…"
            }
        case .verification:
            return "\(faceManager.totalFramesCollected)/\(verificationTarget)"
        }
    }

    private var frameProgress: Double {
        switch faceAuthManager.currentMode {
        case .registration:
            switch faceManager.registrationPhase {
            case .centerCollecting:
                return Double(faceManager.centerFramesCount) / 60.0
            case .movementCollecting:
                let done = max(0, 15 - faceManager.movementSecondsRemaining)
                return Double(done) / 15.0
            case .done:
                return 1.0
            }
        case .verification:
            return Double(faceManager.totalFramesCollected) / Double(verificationTarget)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // ✅ FIXED: Always show camera preview (don't hide it)
                MediapipeCameraPreviewView(faceManager: faceManager)
                    .ignoresSafeArea()

                // ✅ Overlays only when camera is visible
                if !shouldShowProcessingOverlay {
                    TargetFaceOvalOverlay(faceManager: faceManager)
                    DirectionalGuidanceOverlay(faceManager: faceManager)
                }

                // ✅ FIXED: Show processing overlay on top of camera (not black screen)
                if shouldShowProcessingOverlay {
                    ZStack {
                        Color.black.opacity(0.7).ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))

                            Text(isUploadingFrames ? "Uploading enrollment..." : "Processing verification...")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .padding(32)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.8)))
                    }
                }

                VStack {
                    // Top bar with mode and token
                    HStack(spacing: 12) {
                        // Mode indicator
                        HStack(spacing: 6) {
                            Image(systemName: currentModeIcon)
                                .font(.system(size: 12, weight: .semibold))
                            Text(currentModeText)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(currentModeColor.opacity(0.2))
                                .overlay(
                                    Capsule()
                                        .strokeBorder(currentModeColor.opacity(0.5), lineWidth: 1)
                                )
                        )

                        Spacer()

                        // Token display
                        tokenDisplayView
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 60)

                    // ✅ Show processing indicator when auto-trigger happens
                    if faceManager.totalFramesCollected >= targetFrameCount && !hasAutoTriggered && !shouldShowProcessingOverlay {
                        HStack(spacing: 8) {
                            ProgressView().scaleEffect(0.8)
                            Text(faceAuthManager.currentMode == .registration ? "Processing registration..." : "Processing verification...")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.7)))
                        .foregroundColor(.white)
                        .padding(.top, 8)
                    }

                    Spacer()
                }

                // Copy toast notification
                if showCopyToast {
                    VStack {
                        Spacer()
                        copyToastView
                            .padding(.bottom, 100)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .onAppear {
                print("🎬 [FaceDetectionView] View appeared - Mode: \(faceAuthManager.currentMode)")
                
                // ✅ Start camera immediately
                faceManager.startSessionIfNeeded()
                hasAutoTriggered = false
                updateBusyState()

                // ✅ Handle mode-specific setup
                if faceAuthManager.currentMode == .registration {
                    enrollmentGate.markNotEnrolled()
                    initialFetchComplete = true
                } else {
                    // ✅ FIXED: Fetch in background without blocking camera
                    print("📥 [FaceDetectionView] Fetching face data for token: \(token)")
                    Task {
                        await fetchUserByTokenViewModel.fetch(token: token)
                        await MainActor.run {
                            initialFetchComplete = true
                            checkEnrollmentStatus()
                            print("✅ [FaceDetectionView] Initial fetch complete")
                        }
                    }
                }
            }
            .onDisappear {
                print("👋 [FaceDetectionView] View disappearing")
                faceManager.stopSessionIfNeeded()
            }
            
            // ✅ FIXED: Update busy state when processing states change
            .onChange(of: isUploadingFrames) { _, _ in updateBusyState() }
            .onChange(of: isVerifying) { _, _ in updateBusyState() }

            // Auto-trigger verification when frames ready
            .onChange(of: faceManager.totalFramesCollected) { _, newValue in
                guard !hasAutoTriggered && !shouldShowProcessingOverlay else { return }

                if faceAuthManager.currentMode == .verification, newValue >= 10, backendEnrollmentValid {
                    hasAutoTriggered = true
                    print("🚀 [FaceDetectionView] Auto-triggering verification with \(newValue) frames")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { handleLogin() }
                }
            }

            .onChange(of: faceManager.uploadSuccess) { success in
                if success {
                    print("🎉 [Upload] Success! Completing flow...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        faceManager.resetForNewUser()
                        onComplete()
                    }
                }
            }

            .onChange(of: faceIdUploadViewModel.uploadSuccess) { ok in
                guard ok else { return }

                print("✅ [Upload] Registration successful!")
                enrollmentGate.markEnrolled()

                faceManager.capturedFrames = []
                faceManager.totalFramesCollected = 0
                hasAutoTriggered = false
                isUploadingFrames = false

                alertTitle = "✅ Registration Successful"
                alertMessage = "Your face has been enrolled successfully!"
                showAlert = true

                faceIdUploadViewModel.resetState()
            }
            
            .onChange(of: faceManager.registrationComplete) { _, done in
                guard done, !hasAutoTriggered, !shouldShowProcessingOverlay else { return }
                print("✅ [FaceDetectionView] Registration complete, triggering upload")
                hasAutoTriggered = true
                handleRegister()
            }

            .onChange(of: fetchUserByTokenViewModel.errorText) { _, err in
                guard let err else { return }
                print("❌ [TokenFetch] Error: \(err)")
                alertTitle = "❌ Fetch Failed"
                alertMessage = err
                showAlert = true
                hasAutoTriggered = false
            }

            .onChange(of: faceIdUploadViewModel.showError) { show in
                guard show else { return }
                print("❌ [Upload] Error: \(faceIdUploadViewModel.errorMessage ?? "Unknown")")
                alertTitle = "❌ Upload Failed"
                alertMessage = faceIdUploadViewModel.errorMessage ?? "Unknown upload error"
                showAlert = true
                hasAutoTriggered = false
                isUploadingFrames = false
                isVerifying = false
            }

            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK") {
                    showAlert = false

                    if alertTitle.contains("Successful") {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            self.onComplete()
                        }
                    }

                    if alertTitle.contains("Failed") || alertTitle.contains("Error") {
                        faceManager.capturedFrames = []
                        faceManager.totalFramesCollected = 0
                        hasAutoTriggered = false
                        isUploadingFrames = false
                        isVerifying = false
                    }
                }
            } message: {
                Text(alertMessage)
            }
            
            // Process liveness frames
            .onReceive(
                faceManager.$latestPixelBuffer
                    .compactMap { $0 }
                    .throttle(for: .milliseconds(150), scheduler: RunLoop.main, latest: true)
            ) { buffer in
                ncnnViewModel.processFrame(buffer)
            }
        }
    }

    // MARK: - Token Display View

    private var tokenDisplayView: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "number.circle.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.orange)
                
                Text("Token")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Text("\(token)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .yellow],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .monospacedDigit()
            
            if faceAuthManager.currentMode == .registration {
                Button(action: copyToken) {
                    Image(systemName: "doc.on.doc.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.15))
                        )
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.orange.opacity(0.5), .yellow.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .shadow(color: .orange.opacity(0.3), radius: 8, x: 0, y: 4)
    }

    // MARK: - Copy Toast View

    private var copyToastView: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.green)
            
            Text("Token Copied!")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.85))
                .overlay(
                    Capsule()
                        .strokeBorder(Color.green.opacity(0.4), lineWidth: 1.5)
                )
        )
        .shadow(color: .green.opacity(0.3), radius: 12, x: 0, y: 6)
    }

    // MARK: - Helper Functions

    private func copyToken() {
        print("📋 [FaceDetectionView] Copying token: \(token)")
        
        UIPasteboard.general.string = String(token)
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
            showCopyToast = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                showCopyToast = false
            }
        }
    }

    private func checkEnrollmentStatus() {
        let isEnrolled = backendEnrollmentValid

        if tokenFetchLoaded {
            if backendEnrollmentValid {
                enrollmentGate.markEnrolled()
            } else {
                enrollmentGate.markNotEnrolled()
            }
        }

        let count = fetchUserByTokenViewModel.faceIds.count
        let saltLen = fetchUserByTokenViewModel.salt?.count ?? 0

        print("📊 [FaceDetectionView] Enrollment status: \(isEnrolled ? "✅ Enrolled" : "❌ Not Enrolled")")
        print("   • Remote FaceId count: \(count)")
        print("   • Remote salt length: \(saltLen)")
    }

    // MARK: - Register Handler

    private func handleRegister() {
        print("📝 [FaceDetectionView] Starting registration upload")
        isUploadingFrames = true

        let frames = faceManager.registrationFramesForUpload()
        let valid = frames.filter { $0.distances.count == 316 }

        print("   • Total frames: \(frames.count)")
        print("   • Valid frames: \(valid.count)")

        guard valid.count >= 60 else {
            isUploadingFrames = false
            alertTitle = "❌ Registration Failed"
            alertMessage = "Need at least 60 valid frames.\n\nFound: \(valid.count) valid"
            showAlert = true
            return
        }

        faceManager.generateAndUploadFaceID(
            userId: userId,
            authToken: authToken,
            viewModel: faceIdUploadViewModel,
            frames: valid,
            minRequired: 60
        ) { result in
            DispatchQueue.main.async {
                self.isUploadingFrames = false
                switch result {
                case .success:
                    print("✅ [FaceDetectionView] Registration upload complete")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.onComplete()
                    }
                case .failure(let error):
                    print("❌ [FaceDetectionView] Registration failed: \(error)")
                    self.alertTitle = "❌ Registration Failed"
                    self.alertMessage = "Error: \(error.localizedDescription)"
                    self.showAlert = true
                    
                    faceManager.capturedFrames = []
                    faceManager.totalFramesCollected = 0
                    hasAutoTriggered = false
                }
            }
        }
    }

    // MARK: - Login Handler

    private func handleLogin() {
        print("🔐 [FaceDetectionView] Starting verification")
        isVerifying = true

        guard backendEnrollmentValid else {
            enrollmentGate.markNotEnrolled()
            isVerifying = false
            alertTitle = "❌ No Face Data"
            alertMessage = "No usable face data for this token. Please register first."
            showAlert = true
            return
        }

        let allFrames = faceManager.verificationFrames10()
        let validFrames = allFrames.filter { $0.distances.count == 316 }

        print("   • Total frames: \(allFrames.count)")
        print("   • Valid frames: \(validFrames.count)")

        guard validFrames.count >= 10 else {
            isVerifying = false
            alertTitle = "❌ Failed to Login"
            alertMessage = "Need at least 10 valid frames.\n\nFound: \(validFrames.count) valid"
            showAlert = true
            return
        }

        guard let saltHex = fetchUserByTokenViewModel.salt, !saltHex.isEmpty else {
            isVerifying = false
            alertTitle = "❌ Failed to Login"
            alertMessage = "Missing salt from token fetch."
            showAlert = true
            return
        }

        let faceIds = fetchUserByTokenViewModel.faceIds
        guard !faceIds.isEmpty else {
            isVerifying = false
            alertTitle = "❌ Failed to Login"
            alertMessage = "No face data found for this token. Please register first."
            showAlert = true
            return
        }

        print("🔑 [FaceDetectionView] Loading face cache with \(faceIds.count) records")
        
        faceManager.loadRemoteFaceIdsForVerification(
            salt: saltHex,
            faceIds: faceIds
        ) { cacheResult in
            switch cacheResult {
            case .failure(let error):
                print("❌ [FaceDetectionView] Cache load failed: \(error)")
                DispatchQueue.main.async {
                    self.isVerifying = false
                    self.alertTitle = "⚠️ Verification Error"
                    self.alertMessage = "Cache error: \(error.localizedDescription)"
                    self.showAlert = true
                }
            case .success:
                print("✅ [FaceDetectionView] Cache loaded, starting BCH verification")
                
                faceManager.verifyFaceIDAgainstBackend(
                    framesToUse: allFrames
                ) { result in
                    DispatchQueue.main.async {
                        self.isVerifying = false

                        self.faceManager.capturedFrames = []
                        self.faceManager.totalFramesCollected = 0
                        self.hasAutoTriggered = false

                        switch result {
                        case .success(let verification):
                            let matchPercent = verification.matchPercentage
                            print("📊 [FaceDetectionView] Verification result - Success: \(verification.success) | Match: \(String(format: "%.1f", matchPercent))%")
                            print("   • Notes: \(verification.notes ?? "none")")

                            if verification.success {
                                print("✅ [FaceDetectionView] Verification passed, completing login")
                                DispatchQueue.main.async { onComplete() }
                            } else {
                                print("❌ [FaceDetectionView] Verification failed")
                                self.alertTitle = "❌ Failed to Login"
                                self.alertMessage = "Face verification failed. Try again"
                                self.showAlert = true

                                faceManager.capturedFrames = []
                                faceManager.totalFramesCollected = 0
                                hasAutoTriggered = false
                            }

                        case .failure(let error):
                            print("❌ [FaceDetectionView] Verification error: \(error)")
                            self.alertTitle = "⚠️ Verification Error"
                            self.alertMessage = "Error: \(error.localizedDescription)"
                            self.showAlert = true
                        }
                    }
                }
            }
        }
    }
}
