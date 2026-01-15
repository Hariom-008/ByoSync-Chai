import SwiftUI
internal import AVFoundation
import MediaPipeTasksVision
import Combine
import UIKit
import CoreImage

@MainActor
struct FaceDetectionView: View {

    // For saving frames of count 30 (for JPEG debug / liveness etc.)
    @State private var isSavingFrames: Bool = false
    @State private var savedFrameCount: Int = 0
    private let maxSavedFrames = 30

    // Core managers
    @StateObject private var faceManager: FaceManager
    @StateObject private var cameraSpecManager: CameraSpecManager

    // NCNN liveness model
    @StateObject private var ncnnViewModel = NcnnLivenessViewModel()

    // Backend FaceId VMs
    @StateObject private var faceIdUploadViewModel = FaceIdViewModel()
    @StateObject private var fetchUserByTokenViewModel = FetchUserByTokenViewModel()
    @StateObject private var registerFromChaiViewModel = RegisterFromChaiAppViewModel()

    // Auth / device identity (passed from parent)
    let authToken: String
    let onComplete: () -> Void

    // EAR series
    @State private var earSeries: [CGFloat] = []
    private let earMaxSamples = 180
    private let blinkThreshold: CGFloat = 0.21

    // Pose buffers
    @State private var pitchSeries: [CGFloat] = []
    @State private var yawSeries:   [CGFloat] = []
    @State private var rollSeries:  [CGFloat] = []
    private let poseMaxSamples = 180

    // Animation state for frame recording indicator
    @State private var hideOverlays: Bool = false

    // UI State for enrollment/verification
    @State private var isEnrolled: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""
    @State private var isProcessing: Bool = false

    // ✅ NEW: Show/hide normalized points overlay
    @State private var showNormalizedPoints: Bool = true

    // ✅ Face auth mode manager
    @EnvironmentObject var faceAuthManager: FaceAuthManager

    // ✅ NEW: enrollment persistence gate
    @EnvironmentObject var enrollmentGate: EnrollmentGate

    // ✅ Auto-trigger tracking (prevent multiple triggers)
    @State private var hasAutoTriggered: Bool = false

    // CHAI
    let userId: String
    let deviceKeyHash: String
    let token: Int

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

    private var busyLocal: Bool {
        isProcessing || fetchUserByTokenViewModel.isLoading || faceIdUploadViewModel.isUploading
    }

    private func syncBusy() {
        faceManager.setBusy(busyLocal)
    }

    /// Whether token-based fetch has produced a result (success or failure) at least once.
    private var tokenFetchLoaded: Bool {
        fetchUserByTokenViewModel.message != nil ||
        fetchUserByTokenViewModel.errorText != nil ||
        fetchUserByTokenViewModel.salt != nil
    }

    /// Enrollment is "usable" only if token fetch returned BOTH salt + non-empty faceData.
    private var backendEnrollmentValid: Bool {
        guard let salt = fetchUserByTokenViewModel.salt, !salt.isEmpty else { return false }
        return !fetchUserByTokenViewModel.faceIds.isEmpty
    }

    private var enrollmentStatusText: String {
        if !tokenFetchLoaded { return "Checking…" }
        return backendEnrollmentValid ? "Enrolled" : "Not Enrolled"
    }

    private var enrollmentStatusIcon: String {
        if !tokenFetchLoaded { return "hourglass.circle.fill" }
        return backendEnrollmentValid ? "checkmark.circle.fill" : "xmark.circle.fill"
    }

    private var enrollmentStatusColor: Color {
        if !tokenFetchLoaded { return .yellow }
        return backendEnrollmentValid ? .green : .red
    }

    // ✅ Current mode display
    private var currentModeText: String {
        switch faceAuthManager.currentMode {
        case .registration: return "Registration Mode"
        case .verification: return "Verification Mode"
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
                if !faceManager.isBusy {
                    MediapipeCameraPreviewView(faceManager: faceManager)
                        .ignoresSafeArea()

                    TargetFaceOvalOverlay(faceManager: faceManager)
                    DirectionalGuidanceOverlay(faceManager: faceManager)
                }

                if faceManager.isBusy {
                    Color.black.ignoresSafeArea()
                }

                if faceManager.isBusy {
                    ZStack {
                        Color.black.opacity(0.5).ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))

                            Text(faceIdUploadViewModel.isUploading ? "Uploading enrollment..."
                                 : (fetchUserByTokenViewModel.isLoading ? "Fetching user data..." : "Processing..."))
                            .font(.headline)
                            .foregroundColor(.white)
                        }
                        .padding(32)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.8)))
                    }
                }

                VStack {
                    HStack(spacing: 16) {
                        HStack(spacing: 8) {
                            Image(systemName: currentModeIcon).foregroundColor(currentModeColor)
                                .font(.system(size: 10, weight: .thin))
                            Text(currentModeText)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.7)))
                        .foregroundColor(.white)

                        HStack {
                            Text("Token: \(token)")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(.green)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.7)))
                        .foregroundColor(.white)

                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 60)

                    if faceManager.totalFramesCollected >= targetFrameCount && !hasAutoTriggered {
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
            }
            .onReceive(
                faceManager.$NormalizedPoints
                    .throttle(for: .milliseconds(100), scheduler: RunLoop.main, latest: true)
            ) { pts in
                if let (pitch, yaw, roll) = faceManager.computeAngles(from: pts) {
                    var p = pitchSeries; p.append(CGFloat(pitch))
                    var y = yawSeries;   y.append(CGFloat(yaw))
                    var r = rollSeries;  r.append(CGFloat(roll))

                    let cap = poseMaxSamples
                    if p.count > cap { p.removeFirst(p.count - cap) }
                    if y.count > cap { y.removeFirst(y.count - cap) }
                    if r.count > cap { r.removeFirst(r.count - cap) }

                    pitchSeries = p
                    yawSeries = y
                    rollSeries = r
                }
            }
            .onAppear {
                syncBusy()
                #if DEBUG
                print("🎬 [FaceDetectionView] View appeared")
                #endif
            }
            .onChange(of: isProcessing) { _, _ in syncBusy() }
            .onChange(of: fetchUserByTokenViewModel.isLoading) { _, _ in syncBusy() }
            .onChange(of: faceIdUploadViewModel.isUploading) { _, _ in syncBusy() }

            // Only auto-trigger verification when token face data is ready
            .onChange(of: faceManager.totalFramesCollected) { _, newValue in
                guard !hasAutoTriggered && !faceManager.isBusy else { return }

                if faceAuthManager.currentMode == .verification, newValue >= 10, backendEnrollmentValid {
                    hasAutoTriggered = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { handleLogin() }
                }
            }

            .onChange(of: faceManager.uploadSuccess) { success in
                if success {
                    #if DEBUG
                    print("🎉 [Upload] Success! Completing flow...")
                    #endif
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        faceManager.resetForNewUser()
                        onComplete()
                    }
                }
            }

            .onChange(of: fetchUserByTokenViewModel.salt) { _, _ in
                checkEnrollmentStatus()
            }
            .onChange(of: fetchUserByTokenViewModel.faceIds) { _, _ in
                checkEnrollmentStatus()
            }

            .onChange(of: faceIdUploadViewModel.uploadSuccess) { ok in
                guard ok else { return }

                #if DEBUG
                print("✅ [Upload] Registration successful!")
                #endif
                enrollmentGate.markEnrolled()

                faceManager.capturedFrames = []
                faceManager.totalFramesCollected = 0
                hasAutoTriggered = false

                alertTitle = "✅ Registration Successful"
                alertMessage = "Your face has been enrolled successfully!"
                showAlert = true

                faceIdUploadViewModel.resetState()
            }
            
            .onChange(of: faceManager.registrationComplete) { _, done in
                guard done, !hasAutoTriggered, !faceManager.isBusy else { return }
                hasAutoTriggered = true
                handleRegister()
            }

            .onChange(of: fetchUserByTokenViewModel.errorText) { _, err in
                guard let err else { return }
                #if DEBUG
                print("❌ [TokenFetch] Error: \(err)")
                #endif
                alertTitle = "❌ Fetch Failed"
                alertMessage = err
                showAlert = true
                hasAutoTriggered = false
            }

            .onChange(of: faceIdUploadViewModel.showError) { show in
                guard show else { return }
                #if DEBUG
                print("❌ [Upload] Error: \(faceIdUploadViewModel.errorMessage ?? "Unknown")")
                #endif
                alertTitle = "❌ Upload Failed"
                alertMessage = faceIdUploadViewModel.errorMessage ?? "Unknown upload error"
                showAlert = true
                hasAutoTriggered = false
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
                    }
                }
            } message: {
                Text(alertMessage)
            }
        }
        .onAppear {
            faceManager.startSessionIfNeeded()
            hasAutoTriggered = false
            syncBusy()

            #if DEBUG
            print("🎯 [FaceDetectionView] Current mode: \(faceAuthManager.currentMode)")
            #endif

            if faceAuthManager.currentMode == .registration {
                enrollmentGate.markNotEnrolled()
            } else {
                // ✅ NEW: token-based face data fetch
                Task { await fetchUserByTokenViewModel.fetch(token: token) }
            }
        }
        .onDisappear {
            faceManager.stopSessionIfNeeded()
        }
        .onReceive(
            faceManager.$latestPixelBuffer
                .compactMap { $0 }
                .throttle(for: .milliseconds(150), scheduler: RunLoop.main, latest: true)
        ) { buffer in
            ncnnViewModel.processFrame(buffer)
        }
    }

    // MARK: - Helper Functions

    private func checkEnrollmentStatus() {
        isEnrolled = backendEnrollmentValid

        if tokenFetchLoaded {
            if backendEnrollmentValid {
                enrollmentGate.markEnrolled()
            } else {
                enrollmentGate.markNotEnrolled()
            }
        }

        let count = fetchUserByTokenViewModel.faceIds.count
        let saltLen = fetchUserByTokenViewModel.salt?.count ?? 0

        #if DEBUG
        print("📊 Enrollment status (token backend): \(isEnrolled ? "✅ Enrolled" : "❌ Not Enrolled")")
        print("   Remote FaceId count: \(count)")
        print("   Remote salt len: \(saltLen)")
        #endif
    }

    // MARK: - Register Handler (unchanged)

    private func handleRegister() {
        isProcessing = true

        let frames = faceManager.registrationFramesForUpload()
        let valid = frames.filter { $0.distances.count == 316 }

        guard valid.count >= 60 else {
            isProcessing = false
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
                self.isProcessing = false
                switch result {
                case .success:
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.onComplete()
                    }
                case .failure(let error):
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

    // MARK: - Login Handler (NEW: uses FetchUserByTokenViewModel)

    private func handleLogin() {
        isProcessing = true

        guard backendEnrollmentValid else {
            enrollmentGate.markNotEnrolled()
            isProcessing = false
            alertTitle = "No usable face data"
            alertMessage = "No usable face data for this token. Please register first."
            showAlert = true
            return
        }

        let allFrames = faceManager.verificationFrames10()
        let validFrames = allFrames.filter { $0.distances.count == 316 }

        guard validFrames.count >= 10 else {
            isProcessing = false
            alertTitle = "Failed to Login"
            alertMessage = "Need at least 10 valid frames.\n\nFound: \(validFrames.count) valid"
            showAlert = true
            return
        }

        guard let saltHex = fetchUserByTokenViewModel.salt, !saltHex.isEmpty else {
            isProcessing = false
            alertTitle = "Failed to Login"
            alertMessage = "Missing salt from token fetch."
            showAlert = true
            return
        }

        let faceIds = fetchUserByTokenViewModel.faceIds
        guard !faceIds.isEmpty else {
            isProcessing = false
            alertTitle = "Failed to Login"
            alertMessage = "No face data found for this token. Please register first."
            showAlert = true
            return
        }

        faceManager.loadRemoteFaceIdsForVerification(
            salt: saltHex,
            faceIds: faceIds
        ) { cacheResult in
            switch cacheResult {
            case .failure(let error):
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.alertTitle = "⚠️Verification Error"
                    self.alertMessage = "Cache error: \(error.localizedDescription)"
                    self.showAlert = true
                }
            case .success:
                faceManager.verifyFaceIDAgainstBackend(
                    framesToUse: allFrames,
                    requiredMatches: 4
                ) { result in
                    DispatchQueue.main.async {
                        self.isProcessing = false

                        self.faceManager.capturedFrames = []
                        self.faceManager.totalFramesCollected = 0
                        self.hasAutoTriggered = false

                        switch result {
                        case .success(let verification):
                            let matchPercent = verification.matchPercentage
                            #if DEBUG
                            print("📊 [Login] Verification result - Success: \(verification.success) | Match: \(String(format: "%.1f", matchPercent))% | notes=\(verification.notes ?? "")")
                            #endif

                            if verification.success {
                                DispatchQueue.main.async { onComplete() }
                            } else {
                                self.alertTitle = "Failed to Login"
                                self.alertMessage = "Face verification failed. Try again"
                                self.showAlert = true

                                faceManager.capturedFrames = []
                                faceManager.totalFramesCollected = 0
                                hasAutoTriggered = false
                            }

                        case .failure(let error):
                            self.alertTitle = "⚠️Verification Error"
                            self.alertMessage = "Error: \(error.localizedDescription)"
                            self.showAlert = true
                        }
                    }
                }
            }
        }
    }
}
