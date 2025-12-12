import SwiftUI
internal import AVFoundation
import MediaPipeTasksVision
import Combine
import UIKit
import CoreImage

struct FaceDetectionView: View {
    
    // For saving frames of count 30 (for JPEG debug / liveness etc.)
    @State private var isSavingFrames: Bool = false
    @State private var savedFrameCount: Int = 0
    private let maxSavedFrames = 30
    
    // ✅ CORRECT: Both created as StateObjects
    @StateObject private var faceManager: FaceManager
    @StateObject private var cameraSpecManager: CameraSpecManager
    
    // ✅ NCNN liveness model
    @StateObject private var ncnnViewModel = NcnnLivenessViewModel()
    
    // ✅ New ViewModels for backend FaceId
    @StateObject private var faceIdUploadViewModel = FaceIdViewModel()
    @StateObject private var faceIdFetchViewModel = FaceIdFetchViewModel()
    
    // Auth / device identity (passed from parent)
    let authToken: String
    let deviceKey: String
    
    let onComplete: () -> Void
    
    // EAR series
    @State private var earSeries: [CGFloat] = []
    private let earMaxSamples = 180
    private let earRange: ClosedRange<CGFloat> = 0.0...0.5
    private let blinkThreshold: CGFloat = 0.21
    
    // Pose buffers
    @State private var pitchSeries: [CGFloat] = []
    @State private var yawSeries:   [CGFloat] = []
    @State private var rollSeries:  [CGFloat] = []
    private let poseMaxSamples = 180
    private let poseRange: ClosedRange<CGFloat> = (-.pi)...(.pi)
    
    // Animation state for frame recording indicator
    @State private var showRecordingFlash: Bool = false
    @State private var hideOverlays: Bool = false
    
    // UI State for enrollment/verification
    @State private var isEnrolled: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""
    @State private var isProcessing: Bool = false
    
    // MARK: - Init
    
    init(
        authToken: String,
        deviceKey: String,
        onComplete: @escaping () -> Void
    ) {
        self.authToken = authToken
        self.deviceKey = deviceKey
        
        let camSpecManager = CameraSpecManager()
        _cameraSpecManager = StateObject(wrappedValue: camSpecManager)
        _faceManager = StateObject(wrappedValue: FaceManager(cameraSpecManager: camSpecManager))
        self.onComplete = onComplete
    }
    
    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let screenHeight = geometry.size.height
            let isCompact = screenWidth < 1024 || screenHeight < 768
            
            ZStack {
                // Camera preview
                MediapipeCameraPreviewView(faceManager: faceManager)
                    .ignoresSafeArea()
                
                // Face detection overlays
                FacePointsOverlay(faceManager: faceManager)
                TargetFaceOvalOverlay(faceManager: faceManager)
                FaceOvalOverlay(faceManager: faceManager)
                
                DirectionalGuidanceOverlay(faceManager: faceManager)
                
                // Nose center overlay
                NoseCenterCircleOverlay(isCentered: faceManager.isNoseTipCentered)
                
                // Gaze vector (shown after calibration)
                if faceManager.isMovementTracking {
                    GazeVectorCard(
                        gazeVector: faceManager.GazeVector,
                        screenSize: geometry.size
                    )
                    .transition(.opacity.combined(with: .scale))
                    .animation(.easeInOut(duration: 0.3), value: faceManager.isMovementTracking)
                }
                
                // Processing overlay
                if isProcessing {
                    ZStack {
                        Color.black.opacity(0.5)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            
                            Text("Processing...")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .padding(32)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.black.opacity(0.8))
                        )
                    }
                }
                
                VStack {
                    // Top status bar
                    HStack(spacing: 16) {
                        // Enrollment status
                        HStack(spacing: 8) {
                            Image(systemName: isEnrolled ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(isEnrolled ? .green : .red)
                            Text(isEnrolled ? "Enrolled" : "Not Enrolled")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(0.7))
                        )
                        .foregroundColor(.white)
                        
                        Spacer()
                        
                        // Frame counter
                        HStack(spacing: 8) {
                            Image(systemName: "camera.fill")
                            Text("\(faceManager.totalFramesCollected)")
                                .font(.system(size: 14, weight: .bold))
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(faceManager.totalFramesCollected >= 80 ? Color.green.opacity(0.8) : Color.black.opacity(0.7))
                        )
                        .foregroundColor(.white)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 60)
                    
                    Spacer()
                    
                    // Bottom buttons
                    VStack(spacing: 12) {
                        // MARK: - Register button
                        Button {
                            handleRegister()
                        } label: {
                            HStack {
                                Image(systemName: "person.badge.plus.fill")
                                Text("Register")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(registerButtonColor())
                            )
                            .foregroundColor(.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .disabled(!canRegister())
                        .opacity(canRegister() ? 1.0 : 0.5)
                        
                        // MARK: - Login button
                        Button {
                            handleLogin()
                        } label: {
                            HStack {
                                Image(systemName: "lock.shield.fill")
                                Text("Login")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(loginButtonColor())
                            )
                            .foregroundColor(.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .disabled(!canLogin())
                        .opacity(canLogin() ? 1.0 : 0.5)
                        
                        // MARK: - Clear enrollment button (for testing)
                        Button {
                            handleClearEnrollment()
                        } label: {
                            HStack {
                                Image(systemName: "trash.fill")
                                Text("Clear Enrollment")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.red.opacity(0.7))
                            )
                            .foregroundColor(.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .disabled(!isEnrolled)
                        .opacity(isEnrolled ? 1.0 : 0.5)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
            .onChange(of: faceManager.EAR) { newEAR in
                var s = earSeries
                s.append(CGFloat(newEAR))
                if s.count > earMaxSamples {
                    s.removeFirst(s.count - earMaxSamples)
                }
                earSeries = s
            }
            .onReceive(faceManager.$NormalizedPoints) { _ in
                faceManager.updateNoseTipCenterStatusFromCalcCoords()
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
            // Trigger flash animation when new frame is recorded
            .onChange(of: faceManager.frameRecordedTrigger) { _ in
                showRecordingFlash = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    showRecordingFlash = false
                }
            }
            // When backend upload flow inside FaceManager marks success
            .onChange(of: faceManager.uploadSuccess) { success in
                if success {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        faceManager.resetForNewUser()
                        onComplete()
                    }
                }
            }
            // Keep isEnrolled in sync with remote faceIds
            .onChange(of: faceIdFetchViewModel.faceIds) { _ in
                checkEnrollmentStatus()
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK") {
                    showAlert = false
                }
            } message: {
                Text(alertMessage)
            }
        }
        .onAppear {
            // ✅ Load models
            ncnnViewModel.loadModels()
            
            // ✅ Set up the callback to update FaceManager
            ncnnViewModel.onLivenessUpdated = { [weak faceManager] score in
                faceManager?.updateFaceLivenessScore(score)
            }
            
            // Fetch enrollment status from backend for this device
            print("🌐 [FaceDetectionView] Fetching FaceIds on appear for deviceKey=\(deviceKey)")
            faceIdFetchViewModel.fetchFaceIds(for: deviceKey)
            
            debugLog("✅ FaceDetectionView appeared, callback connected")
        }
        // NCNN frames – throttled to avoid overloading CPU/GPU & starts saving frames in device
        .onReceive(
            faceManager.$latestPixelBuffer
                .compactMap { $0 }
                .throttle(for: .milliseconds(150), scheduler: RunLoop.main, latest: true)
        ) { buffer in
            // NCNN processing
            ncnnViewModel.processFrame(buffer)
            
            // Optional: save JPEG frames while collecting
            if isSavingFrames && savedFrameCount < maxSavedFrames &&
                faceManager.isHeadPoseStable() &&
                faceManager.isFaceReal &&
                faceManager.FaceOvalIsInTarget &&
                faceManager.ratioIsInRange
            {
                let currentIndex = savedFrameCount
                savedFrameCount += 1
                
                DispatchQueue.global(qos: .userInitiated).async {
                    saveFrame(buffer, index: currentIndex)
                }
                
                if savedFrameCount == maxSavedFrames {
                    isSavingFrames = false
                    print("✅ Finished saving \(maxSavedFrames) frames.")
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func checkEnrollmentStatus() {
        isEnrolled = !faceIdFetchViewModel.faceIds.isEmpty
        print("📊 Enrollment status (backend): \(isEnrolled ? "✅ Enrolled" : "❌ Not Enrolled")")
        print("   Remote FaceId count from VM: \(faceIdFetchViewModel.faceIds.count)")
    }
    
    private func canRegister() -> Bool {
        return faceManager.totalFramesCollected >= 80 && !isProcessing
    }
    
    private func canLogin() -> Bool {
        // For login we only need 10 frames + at least one backend FaceId
        return faceManager.totalFramesCollected >= 10 &&
               isEnrolled &&
               !faceIdFetchViewModel.faceIds.isEmpty &&
               !isProcessing
    }
    
    private func registerButtonColor() -> Color {
        if isProcessing { return .gray }
        if isEnrolled { return .orange }  // Already enrolled, can re-register
        return faceManager.totalFramesCollected >= 80 ? .green : .gray
    }
    
    private func loginButtonColor() -> Color {
        if isProcessing { return .gray }
        // Consistent with canLogin(): 10 frames + enrolled + backend data present
        return (faceManager.totalFramesCollected >= 10 &&
                isEnrolled &&
                !faceIdFetchViewModel.faceIds.isEmpty)
        ? .blue : .gray
    }
    
    // MARK: - Register Handler
    private func handleRegister() {
        print("\n" + String(repeating: "=", count: 50))
        print("📸 REGISTER BUTTON PRESSED")
        print("Total frames collected: \(faceManager.totalFramesCollected)")
        print(String(repeating: "=", count: 50))
        
        isProcessing = true
        
        // Validate frames
        let allFrames = faceManager.save316LengthDistanceArray()
        let validFrames = allFrames.filter { $0.count == 316 }
        let invalidCount = allFrames.count - validFrames.count
        
        print("📊 Frame Analysis (REGISTER):")
        print("   Total frames: \(allFrames.count)")
        print("   Valid frames (316 distances): \(validFrames.count)")
        print("   Invalid frames: \(invalidCount)")
        
        // Check if we have enough valid frames
        guard validFrames.count >= 80 else {
            print("❌ INSUFFICIENT VALID FRAMES FOR REGISTRATION")
            isProcessing = false
            
            alertTitle = "❌ Registration Failed"
            alertMessage = "Need at least 80 valid frames.\n\nFound: \(validFrames.count) valid\nInvalid: \(invalidCount)"
            showAlert = true
            return
        }
        
        // Proceed with enrollment → generate + upload to backend
        faceManager.generateAndUploadFaceID(
            authToken: authToken,
            viewModel: faceIdUploadViewModel
        ) { result in
            DispatchQueue.main.async {
                isProcessing = false
                
                switch result {
                case .success:
                    print("✅ ========================================")
                    print("✅ REGISTRATION GENERATION COMPLETED!")
                    print("✅ 80 enrollment records generated & upload triggered")
                    print("✅ ========================================")
                    
                    // Refresh remote enrollment state
                    faceIdFetchViewModel.fetchFaceIds(for: deviceKey)
                    isEnrolled = true
                    
                    // Clear frames
                    faceManager.AllFramesOptionalAndMandatoryDistance = []
                    faceManager.totalFramesCollected = 0
                    
                    // Show success alert
                    alertTitle = "✅ Registration Successful"
                    alertMessage = "Your face has been enrolled!\n\nYou can now use Login to verify your identity."
                    showAlert = true
                    
                case .failure(let error):
                    print("❌ ========================================")
                    print("❌ REGISTRATION FAILED")
                    print("❌ Error: \(error.localizedDescription)")
                    print("❌ ========================================")
                    
                    // Show error alert
                    alertTitle = "❌ Registration Failed"
                    alertMessage = "Error: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
    
    // MARK: - Login Handler
    private func handleLogin() {
        print("\n" + String(repeating: "=", count: 50))
        print("🔐 LOGIN BUTTON PRESSED")
        print("Total frames collected: \(faceManager.totalFramesCollected)")
        print("Backend FaceId count in VM: \(faceIdFetchViewModel.faceIds.count)")
        print("isEnrolled flag: \(isEnrolled)")
        print(String(repeating: "=", count: 50))
        
        isProcessing = true
        
        // Ensure we think the device is enrolled (backend) AND we actually have remote records
        guard isEnrolled, !faceIdFetchViewModel.faceIds.isEmpty else {
            print("❌ NO BACKEND ENROLLMENT DATA AVAILABLE FOR LOGIN")
            isProcessing = false
            
            alertTitle = "❌ No Enrollment Found"
            alertMessage = "No face data found for this device on backend. Please press REGISTER first."
            showAlert = true
            return
        }
        
        // Validate frames
        let allFrames = faceManager.save316LengthDistanceArray()
        let validFrames = allFrames.filter { $0.count == 316 }
        let invalidCount = allFrames.count - validFrames.count
        
        print("📊 Frame Analysis (LOGIN):")
        print("   Total frames: \(allFrames.count)")
        print("   Valid frames (316 distances): \(validFrames.count)")
        print("   Invalid frames: \(invalidCount)")
        
        // Check if we have enough valid frames (10)
        guard validFrames.count >= 10 else {
            print("❌ INSUFFICIENT VALID FRAMES FOR LOGIN")
            isProcessing = false
            
            alertTitle = "❌ Login Failed"
            alertMessage = "Need at least 10 valid frames.\n\nFound: \(validFrames.count) valid\nInvalid: \(invalidCount)"
            showAlert = true
            return
        }
        
        print("🚀 Starting backend token-only verification (FaceManager.verifyFaceIDAgainstBackend)...")
        
        // Proceed with verification against BACKEND (FaceManager will handle caching + API if needed)
        faceManager.verifyFaceIDAgainstBackend(
            deviceKey: deviceKey,
            fetchViewModel: faceIdFetchViewModel
        ) { result in
            DispatchQueue.main.async {
                self.isProcessing = false
                
                // Clear frames after verification
                self.faceManager.AllFramesOptionalAndMandatoryDistance = []
                self.faceManager.totalFramesCollected = 0
                
                switch result {
                case .success(let verification):
                    let matchPercent = verification.matchPercentage
                    
                    if verification.success {
                        print("✅ ========================================")
                        print("✅ LOGIN SUCCESSFUL! 🎉")
                        print("✅ Match: \(String(format: "%.1f", matchPercent))%")
                        print("✅ ========================================")
                        
                        self.alertTitle = "✅ Login Successful!"
                        self.alertMessage = "Welcome back!\n\nMatch: \(String(format: "%.1f", matchPercent))%"
                        self.showAlert = true
                        
                        // 🔑 Trigger completion after a short delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            print("🎯 [FaceDetectionView] Login success → calling onComplete()")
                            self.onComplete()
                        }
                        
                    } else {
                        print("❌ ========================================")
                        print("❌ LOGIN FAILED ⛔")
                        print("❌ Match: \(String(format: "%.1f", matchPercent))%")
                        print("❌ ========================================")
                        
                        self.alertTitle = "❌ Login Failed"
                        self.alertMessage = "Face verification failed.\n\nMatch: \(String(format: "%.1f", matchPercent))%"
                        self.showAlert = true
                    }
                    
                case .failure(let error):
                    print("❌ ========================================")
                    print("❌ VERIFICATION ERROR")
                    print("❌ Error: \(error.localizedDescription)")
                    print("❌ ========================================")
                    
                    self.alertTitle = "❌ Verification Error"
                    self.alertMessage = "Error: \(error.localizedDescription)"
                    self.showAlert = true
                }
            }
        }
    }
    
    // MARK: - Clear Enrollment Handler
    private func handleClearEnrollment() {
        print("\n🧹 CLEARING ENROLLMENT DATA (LOCAL FLAGS)")
        
        // Old local cache clear (harmless even if not used anymore)
        LocalEnrollmentCache.shared.clear()
        
        faceManager.AllFramesOptionalAndMandatoryDistance = []
        faceManager.totalFramesCollected = 0
        
        // Reset remote state flags (does NOT delete from backend)
        faceIdFetchViewModel.resetState()
        isEnrolled = false
        
        print("✅ Local enrollment state cleared (remote backend data not deleted)")
        
        alertTitle = "🧹 Data Cleared"
        alertMessage = "Local enrollment state has been cleared.\n\nYou can now register again."
        showAlert = true
    }
    
    // MARK: - Misc UI helpers
    
    private func instructionRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.cyan)
                .frame(width: 24)
            
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
        }
    }
    
    // MARK: - Save camera frame to Documents as JPEG
    private func saveFrame(_ pixelBuffer: CVPixelBuffer, index: Int) {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            print("❌ Failed to create CGImage for frame \(index)")
            return
        }
        
        let uiImage = UIImage(cgImage: cgImage)
        guard let jpegData = uiImage.jpegData(compressionQuality: 0.9) else {
            print("❌ Failed to get JPEG data for frame \(index)")
            return
        }
        
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = docs.appendingPathComponent("frame_\(index).jpg")
        
        do {
            try jpegData.write(to: fileURL, options: .atomic)
            print("✅ Saved frame \(index) at: \(fileURL.path)")
        } catch {
            print("❌ Error saving frame \(index): \(error)")
        }
    }
}

//// MARK: - Verification Extension (BACKEND with cache)
//extension FaceManager {
//    
//    /// Token-only verification using records fetched from BACKEND:
//    /// - Capture ~10 frames
//    /// - Ensure remote cache is filled (salt + [FaceId]) via API if needed
//    /// - Use current secretHash (R') of each captured frame with SALT + K2/token from backend
//    ///   to try to match tokens.
//    ///
//    /// NOTE: With the current crypto design (no secretHash returned for stored frames),
//    ///       this scheme only matches when secretHash for a login frame equals the
//    ///       secretHash used for an enrollment frame.
//    func verifyFaceIDAgainstBackend(
//        deviceKey: String,
//        fetchViewModel: FaceIdFetchViewModel,
//        completion: @escaping (Result<BCHBiometric.VerificationResult, Error>) -> Void
//    ) {
//        print("\n🔍 ========== VERIFICATION (TOKEN-ONLY, BACKEND+CACHE) STARTED ==========")
//        
//        // 1️⃣ Capture frames
//        let trimmedFrames = VerifyFrameDistanceArray()
//        print("📊 Captured \(trimmedFrames.count) frames total (raw)")
//        
//        // 2️⃣ Filter valid frames by distance count
//        var validFrames: [[Float]] = []
//        var invalidFrameIndices: [Int] = []
//        
//        for (index, frame) in trimmedFrames.enumerated() {
//            if frame.count == BCHBiometric.NUM_DISTANCES {
//                validFrames.append(frame)
//            } else {
//                invalidFrameIndices.append(index)
//                print("⚠️ Frame #\(index + 1) has \(frame.count) distances (expected \(BCHBiometric.NUM_DISTANCES)) - SKIPPED")
//            }
//        }
//        
//        print("✅ Valid frames (distance count OK): \(validFrames.count)")
//        print("❌ Invalid frames (distance count mismatch): \(invalidFrameIndices.count)")
//        
//        let requiredCollectedFrames = 10
//        
//        guard validFrames.count >= requiredCollectedFrames else {
//            print("❌ Insufficient valid frames for token-only verification.")
//            print("   Got \(validFrames.count), but need at least \(requiredCollectedFrames) valid frames.")
//            
//            DispatchQueue.main.async {
//                completion(.failure(
//                    BCHBiometricError.invalidDistancesCount(
//                        expected: requiredCollectedFrames,
//                        actual: validFrames.count
//                    )
//                ))
//            }
//            print("🔚 ========== VERIFICATION ABORTED (NOT ENOUGH VALID FRAMES) ==========\n")
//            return
//        }
//        
//        // We'll only use first 10 valid frames for verification
//        let framesToUse = Array(validFrames.prefix(requiredCollectedFrames))
//        print("🎯 Using first \(framesToUse.count) valid frames for TOKEN comparison.\n")
//        
//        let totalRawFrames = trimmedFrames.count
//        let totalValidFrames = validFrames.count
//        let invalidIndicesCopy = invalidFrameIndices
//        
//        // 3️⃣ Ensure remote cache is filled (salt + [FaceId])
//        loadRemoteFaceIdsIfNeeded(deviceKey: deviceKey, fetchViewModel: fetchViewModel) { [weak self] result in
//            guard let self = self else { return }
//            
//            switch result {
//            case .failure(let error):
//                DispatchQueue.main.async {
//                    completion(.failure(error))
//                }
//                
//            case .success:
//                // 4️⃣ Run the heavy verification loop using cached remote data
//                self.performBackendTokenVerificationTokenOnly(
//                    framesToUse: framesToUse,
//                    totalRawFrames: totalRawFrames,
//                    totalValidFrames: totalValidFrames,
//                    invalidIndices: invalidIndicesCopy,
//                    completion: completion
//                )
//            }
//        }
//    }
//}
