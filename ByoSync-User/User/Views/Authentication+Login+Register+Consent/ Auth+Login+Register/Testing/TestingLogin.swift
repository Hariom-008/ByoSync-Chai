//
//  TestingLoginView.swift
//  ByoSync
//
//  Testing view for login with face verification
//  Matches FaceDetectionView structure exactly
//

import SwiftUI
internal import AVFoundation
import MediaPipeTasksVision
import Combine
import UIKit
import CoreImage

struct TestingLoginView: View {
    
    // MARK: - Core Managers
    @StateObject private var faceManager: FaceManager
    @StateObject private var cameraSpecManager: CameraSpecManager
    
    // MARK: - NCNN Liveness
    @StateObject private var ncnnViewModel = NcnnLivenessViewModel()
    
    // MARK: - Testing ViewModel
    @StateObject private var viewModel: TestingLoginViewModel
    @StateObject private var faceIdFetchViewModel = FaceIdFetchViewModel()
    
    // MARK: - Hardcoded Testing Credentials
    private let deviceKey = "1234abcde"
    
    // MARK: - EAR Series
    @State private var earSeries: [CGFloat] = []
    private let earMaxSamples = 180
    private let blinkThreshold: CGFloat = 0.21
    
    // MARK: - Pose Buffers
    @State private var pitchSeries: [CGFloat] = []
    @State private var yawSeries: [CGFloat] = []
    @State private var rollSeries: [CGFloat] = []
    private let poseMaxSamples = 180
    
    // MARK: - UI State
    @State private var showRecordingFlash: Bool = false
    @State private var hideOverlays: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""
    @State private var isProcessing: Bool = false
    
    // MARK: - Init
    init() {
        let camSpecManager = CameraSpecManager()
        _cameraSpecManager = StateObject(wrappedValue: camSpecManager)
        _faceManager = StateObject(wrappedValue: FaceManager(cameraSpecManager: camSpecManager))
        _viewModel = StateObject(wrappedValue: TestingLoginViewModel())
    }
    
    // MARK: - Derived UI State
    
    private var isBusy: Bool {
        isProcessing || faceIdFetchViewModel.isLoading || viewModel.isLoading
    }
    
    private var backendEnrollmentValid: Bool {
        guard faceIdFetchViewModel.hasLoadedOnce else { return false }
        guard let data = faceIdFetchViewModel.faceIdData else { return false }
        return !data.salt.isEmpty && !data.faceData.isEmpty
    }
    
    private var enrollmentStatusText: String {
        if !faceIdFetchViewModel.hasLoadedOnce { return "Checking…" }
        return backendEnrollmentValid ? "Enrolled" : "Not Enrolled"
    }
    
    private var enrollmentStatusIcon: String {
        if !faceIdFetchViewModel.hasLoadedOnce { return "hourglass.circle.fill" }
        return backendEnrollmentValid ? "checkmark.circle.fill" : "xmark.circle.fill"
    }
    
    private var enrollmentStatusColor: Color {
        if !faceIdFetchViewModel.hasLoadedOnce { return .yellow }
        return backendEnrollmentValid ? .green : .red
    }
    
    // MARK: - Body
    var body: some View {
        GeometryReader { geometry in
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
                
                // Busy overlay
                if isBusy {
                    ZStack {
                        Color.black.opacity(0.5)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            
                            Text(statusText)
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
                        // Testing indicator
                        HStack(spacing: 8) {
                            Image(systemName: "testtube.2")
                                .foregroundColor(.cyan)
                            Text("Testing Mode")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(0.7))
                        )
                        .foregroundColor(.white)
                        
                        // Enrollment status
                        HStack(spacing: 8) {
                            Image(systemName: enrollmentStatusIcon)
                                .foregroundColor(enrollmentStatusColor)
                            Text(enrollmentStatusText)
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
                                .fill(faceManager.totalFramesCollected >= 10 ? Color.green.opacity(0.8) : Color.black.opacity(0.7))
                        )
                        .foregroundColor(.white)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 60)
                    
                    Spacer()
                    
                    // Bottom button
                    VStack(spacing: 12) {
                        // Login button
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
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
            // EAR series update
            .onChange(of: faceManager.EAR) { newEAR in
                var s = earSeries
                s.append(CGFloat(newEAR))
                if s.count > earMaxSamples { s.removeFirst(s.count - earMaxSamples) }
                earSeries = s
            }
            // Nose center status update
            .onReceive(faceManager.$NormalizedPoints) { _ in
                faceManager.updateNoseTipCenterStatusFromCalcCoords()
            }
            // Pose buffers update
            .onReceive(
                faceManager.$NormalizedPoints
                    .throttle(for: .milliseconds(100), scheduler: RunLoop.main, latest: true)
            ) { pts in
                if let (pitch, yaw, roll) = faceManager.computeAngles(from: pts) {
                    var p = pitchSeries; p.append(CGFloat(pitch))
                    var y = yawSeries; y.append(CGFloat(yaw))
                    var r = rollSeries; r.append(CGFloat(roll))
                    
                    let cap = poseMaxSamples
                    if p.count > cap { p.removeFirst(p.count - cap) }
                    if y.count > cap { y.removeFirst(y.count - cap) }
                    if r.count > cap { r.removeFirst(r.count - cap) }
                    
                    pitchSeries = p
                    yawSeries = y
                    rollSeries = r
                }
            }
            // Frame recorded indicator
            .onChange(of: faceManager.frameRecordedTrigger) { _ in
                showRecordingFlash = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    showRecordingFlash = false
                }
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK") {
                    showAlert = false
                    // If success, maybe dismiss or navigate
                    if alertTitle.contains("Success") {
                        // Handle success
                    }
                }
            } message: {
                Text(alertMessage)
            }
        }
        .onAppear {
            // Load NCNN models
            ncnnViewModel.loadModels()
            
            // Callback for liveness
            ncnnViewModel.onLivenessUpdated = { [weak faceManager] score in
                faceManager?.updateFaceLivenessScore(score)
            }
            
            // Fetch enrollment status
            print("🌐 [TestingLoginView] Fetching FaceIds on appear for deviceKey=\(deviceKey)")
            faceIdFetchViewModel.fetchFaceIds(for: deviceKey)
        }
        // NCNN frames
        .onReceive(
            faceManager.$latestPixelBuffer
                .compactMap { $0 }
                .throttle(for: .milliseconds(150), scheduler: RunLoop.main, latest: true)
        ) { buffer in
            ncnnViewModel.processFrame(buffer)
        }
    }
    
    // MARK: - Helper Functions
    
    private var statusText: String {
        if viewModel.isLoading {
            switch viewModel.currentStep {
            case .loggingIn:
                return "Logging in..."
            case .fetchingFaceIds:
                return "Loading verification data..."
            case .verifying:
                return "Verifying face..."
            default:
                return "Processing..."
            }
        }
        if faceIdFetchViewModel.isLoading {
            return "Fetching enrollment..."
        }
        return "Processing..."
    }
    
    private func canLogin() -> Bool {
        faceManager.totalFramesCollected >= 10 &&
        backendEnrollmentValid &&
        !isBusy
    }
    
    private func loginButtonColor() -> Color {
        if isBusy { return .gray }
        return (faceManager.totalFramesCollected >= 10 && backendEnrollmentValid) ? .blue : .gray
    }
    
    // MARK: - Login Handler
    
    private func handleLogin() {
        print("\n" + String(repeating: "=", count: 50))
        print("🧪 TESTING LOGIN BUTTON PRESSED")
        print("Total frames collected: \(faceManager.totalFramesCollected)")
        print("Backend FaceId count: \(faceIdFetchViewModel.faceIds.count)")
        print("backendEnrollmentValid: \(backendEnrollmentValid)")
        print(String(repeating: "=", count: 50))
        
        isProcessing = true
        
        guard backendEnrollmentValid else {
            print("❌ NO BACKEND ENROLLMENT DATA AVAILABLE")
            isProcessing = false
            
            alertTitle = "❌ No Enrollment Found"
            alertMessage = "No face data found for this device. Please register first using the main app."
            showAlert = true
            return
        }
        
        // Validate frames
        let allFrames = faceManager.VerifyFrameDistanceArray()
        let validFrames = allFrames.filter { $0.count == 316 }
        let invalidCount = allFrames.count - validFrames.count
        
        print("📊 Frame Analysis (TESTING LOGIN):")
        print("   Total frames: \(allFrames.count)")
        print("   Valid frames (316 distances): \(validFrames.count)")
        print("   Invalid frames: \(invalidCount)")
        
        guard validFrames.count >= 10 else {
            print("❌ INSUFFICIENT VALID FRAMES FOR LOGIN")
            isProcessing = false
            
            alertTitle = "❌ Login Failed"
            alertMessage = "Need at least 10 valid frames.\n\nFound: \(validFrames.count) valid\nInvalid: \(invalidCount)"
            showAlert = true
            return
        }
        
        print("🚀 Starting testing login flow...")
        
        // Use the testing ViewModel to perform complete flow
        viewModel.performTestingLogin(
            faceManager: faceManager,
            validFrames: validFrames
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
                        print("✅ TESTING LOGIN SUCCESSFUL! 🎉")
                        print("✅ Match: \(String(format: "%.1f", matchPercent))%")
                        print("✅ ========================================")
                        
                        self.alertTitle = "✅ Testing Login Successful!"
                        self.alertMessage = """
                        Welcome back, Hariom!
                        
                        Match: \(String(format: "%.1f", matchPercent))%
                        Device: 1234abcde
                        
                        Token saved to UserDefaults.
                        """
                        self.showAlert = true
                        
                    } else {
                        print("❌ ========================================")
                        print("❌ TESTING LOGIN FAILED ⛔")
                        print("❌ Match: \(String(format: "%.1f", matchPercent))%")
                        print("❌ Notes: \(verification.notes)")
                        print("❌ ========================================")
                        
                        self.alertTitle = "❌ Login Failed"
                        self.alertMessage = """
                        Face verification failed.
                        
                        Match: \(String(format: "%.1f", matchPercent))%
                        
                        \(verification.notes)
                        """
                        self.showAlert = true
                    }
                    
                case .failure(let error):
                    print("❌ ========================================")
                    print("❌ TESTING LOGIN ERROR")
                    print("❌ Error: \(error.localizedDescription)")
                    print("❌ ========================================")
                    
                    self.alertTitle = "❌ Login Error"
                    self.alertMessage = "Error: \(error.localizedDescription)"
                    self.showAlert = true
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    TestingLoginView()
}
