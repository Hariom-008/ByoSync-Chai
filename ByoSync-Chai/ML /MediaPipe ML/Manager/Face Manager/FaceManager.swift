internal import AVFoundation
import UIKit
import MediaPipeTasksVision
import Combine
import simd
import Foundation
import SwiftUI

/// Main FaceManager class - Coordinates all face detection and tracking functionality
final class FaceManager: NSObject, ObservableObject {
    
    // MARK: - Dependencies
    let cameraSpecManager: CameraSpecManager
    
    @Published var isBusy: Bool = false
    
    private let bchQueue = DispatchQueue(label: "FaceManager.BCH", qos: .userInitiated)
    
    var rollPrintTick: Int = 0
    
    // MARK: - Published UI Properties
    @Published var imageSize: CGSize = .zero
    @Published var NormalizedPoints: [(x: Float, y: Float)] = []
    
    @Published var EAR: Float = 0
    @Published var Pitch: Float = 0
    @Published var Yaw: Float = 0
    @Published var Roll: Float = 0
    @Published var FaceScale: Float = 0
    
    @Published var isCentreTracking: Bool = false
    @Published var isMovementTracking: Bool = false
    @Published var GazeVector: (x: Float, y: Float) = (0, 0)
    @Published var actualLeftMean: (x: Float, y: Float) = (0, 0)
    @Published var actualRightMean: (x: Float, y: Float) = (0, 0)
    
    // Liveness
    @Published var isFaceReal: Bool = false
    @Published var rejectedFrames: Int = 0
    
    // Frame collection
    @Published var frameRecordedTrigger: Bool = false
    @Published var totalFramesCollected: Int = 0
    
    // Upload status
    @Published var isUploadingPattern: Bool = false
    @Published var uploadSuccess: Bool = false
    @Published var uploadError: String?
    @Published var hasEnteredPhoneNumber: Bool = false
    
    @Published var latestPixelBuffer: CVPixelBuffer?
    @Published var irisDistanceRatio: Float? = nil
    @Published var faceBoundingBox: CGRect? = nil
    
    // ✅ NEW: Iris target and ratio check
    @Published var irisTargetPx: Float = 0
    @Published var dMeanPx : Float = 0
    @Published var ratioIsInRange: Bool = false
    @Published var faceLivenessScore:Float = 0
    
    
    @Published var TargetFaceOvalCoordinates:[(x: CGFloat, y: CGFloat)] = []
    @Published var TransalatedScaledFaceOvalCoordinates :[(x:CGFloat,y:CGFloat)] = []
    @Published var FaceOvalIsInTarget:Bool = false
    
    @Published var currentDistanceRatio: CGFloat = 0.0
    
    // FaceManager.swift
    @Published var iodNormalized: Float = 0
    @Published var iodPixels: Float = 0
    @Published var iodIsValid: Bool = false
    
    let errorWindowPx: CGFloat = 55.0
    // Updated by IODGate.swift
    @Published var iodGuidance: DistanceGuidance = .noFace
    
    @Published var acceptedFrameUploads: [AcceptedFrameUpload] = []
    
    @Published var iodMin : Float = 0.28
    @Published var iodMax:Float = 0.29

    // Limit concurrent uploads (avoid 80 parallel uploads)
     let frameUploadSemaphore = DispatchSemaphore(value: 2)

    // Store last MediaPipe callback timestamp so the acceptor can tag uploads
    var lastDetectionTimestampMs: Int = 0

    struct AcceptedFrameUpload: Identifiable {
        let id = UUID()
        let frameIndex: Int
        let timestampMs: Int
        var url: String? = nil
        var error: String? = nil
    }

    
    // MARK: - Internal Calculation Buffers
    var rawMediaPipePoints: [(x: Float, y: Float)] = []
    var CameraFeedCoordinates: [(x: Float, y: Float)] = []
    var CalculationCoordinates: [(x: Float, y: Float)] = []
   // var ScreenCoordinates:[(x: CGFloat, y: CGFloat)] = []
    
    var centroid: (x: Float, y: Float)?
    
    var Translated: [(x: Float, y: Float)] = []
    var TranslatedSquareDistance: [Float] = []
    var scale: Float = 0
    
    var actualLeftList: [(x: Float, y: Float)] = []
    var actualRightList: [(x: Float, y: Float)] = []
    
    var landmarkDistanceLists: [[Float]] = []
   // @Published var AllFramesOptionalAndMandatoryDistance: [[Float]] = []
    
    // Array used to store the frame details when all Gates Cleared
    @Published var capturedFrames: [FrameDistance] = []
    
    @Published var registrationPhase: RegistrationPhase = .centerCollecting
    @Published var registrationComplete: Bool = false

    // optional: for UI guidance + balanced sampling
    @Published var currentTarget: HeadDirection = .left

    var centerFrames: [FrameDistance] = []
    var movementFrames: [FrameDistance] = []
    var capturedPerDir: [HeadDirection:Int] = [.left:0,.right:0,.up:0,.down:0,.center:0]
    var movementTimer: DispatchSourceTimer?
    
    
    let faceAuthManager: FaceAuthManager

    // UI-friendly counters (because centerFrames/movementFrames are not @Published)
    @Published var centerFramesCount: Int = 0
    @Published var movementFramesCount: Int = 0
    @Published var movementSecondsRemaining: Int = 0

    var totalRegistrationFrames: Int { centerFramesCount + movementFramesCount }
    @Published var verificationFrameCollectedDistances:[FrameDistance] = []
    
    // MARK: - Camera Components
    var previewLayer: AVCaptureVideoPreviewLayer?
    var cameraDevice: AVCaptureDevice?
    let captureSession = AVCaptureSession()
    let videoOutput = AVCaptureVideoDataOutput()
    let sessionQueue = DispatchQueue(label: "camera.session.queue")
    let processingQueue = DispatchQueue(label: "camera.processing.queue")
    
    // MARK: - MediaPipe
    var faceLandmarker: FaceLandmarker?
    
    // MARK: - Landmark Indices (Constants)
    let faceOvalIndices: [Int] = [
        10, 338, 297, 332, 284, 251, 389, 356, 454, 323,
        361, 288, 397, 365, 379, 378, 400, 377, 152, 148,
        176, 149, 150, 136, 172, 58, 132, 93, 234, 127,
        162, 21, 54, 103, 67, 109
    ]
    let facePoints = [
        104, 69, 108, 151, 337, 299, 333, 301, 71, 345,
        376, 367, 394, 369, 175, 140, 169, 138, 215, 116, 139
    ]
    
    @Published var faceisInsideFaceOval:Bool = false
    // Add these new properties to FaceManager class
    @Published var staticTargetOvalCoordinates: [(x: CGFloat, y: CGFloat)] = []
    @Published var isTargetOvalLocked: Bool = false
    @Published var targetOvalScale: CGFloat = 0
    @Published var targetOvalCenter: (x: CGFloat, y: CGFloat) = (0, 0)

    
    let midLineMandatoryLandmarks = [2, 4, 9]
    let leftMandatoryLandmarks = [70, 107, 46, 55, 33, 133, 98]
    let rightMandatoryLandmarks = [300, 336, 276, 285, 263, 362, 327]
    
    let mandatoryLandmarkPoints = [2, 4, 9, 70, 107, 46, 55, 33, 133, 98, 300, 336, 276, 285, 263, 362, 327]
    let selectedOptionalLandmarks = [423, 357, 349, 347, 340, 266, 330, 427, 280, 203]
    
    let optionalLandmarks = [423, 357, 349, 347, 340, 266, 330, 427, 280, 203, 128, 120, 118, 111, 36, 101, 207, 50, 187, 147, 411, 376, 336, 107, 351, 399, 429, 363, 134, 209, 174, 122, 151, 69, 299, 63, 156, 293, 383]
    
    // MARK: - Initialization
    init(cameraSpecManager: CameraSpecManager,
            faceAuthManager: FaceAuthManager = .shared) {
           self.cameraSpecManager = cameraSpecManager
           self.faceAuthManager = faceAuthManager
           super.init()
           setupMediaPipe()
           sessionQueue.async { [weak self] in self?.setupCamera() }
       }
    
    // MARK: - Liveness Update Method
    func updateFaceLivenessScore(_ score: Float) {
        // Update the score based on the liveness score
        self.faceLivenessScore = score
        
        // Check if the liveness score is above the threshold (0.9)
        if score > 0.9 {
            self.isFaceReal = true
        } else {
            self.isFaceReal = false
        }
    }
    /// Thread-safe setter (optional but recommended)
    func setBusy(_ busy: Bool) {
        if Thread.isMainThread {
            self.isBusy = busy
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.isBusy = busy
            }
        }
    }
    
    // Add method to lock the target oval
    func lockTargetOval(screenWidth: CGFloat, screenHeight: CGFloat) {
        guard !TransalatedScaledFaceOvalCoordinates.isEmpty else {
            print("⚠️ Cannot lock target - no face oval coordinates")
            return
        }
        
        // Store the current oval as the static target
        staticTargetOvalCoordinates = TransalatedScaledFaceOvalCoordinates
        isTargetOvalLocked = true
        targetOvalCenter = (x: screenWidth / 2.0, y: screenHeight / 2.0)
        
        // Calculate and store the scale used
        if !NormalizedPoints.isEmpty {
            let normIOD = calculateNormalizedIOD()
            let camW = max(imageSize.width, 1e-6)
            let camH = max(imageSize.height, 1e-6)
            let scaleToPreview = max(screenWidth / camW, screenHeight / camH)
            let iodPxOnScreen = CGFloat(iodPixels) * scaleToPreview
            
            if normIOD > 1e-6, iodPxOnScreen > 0 {
                targetOvalScale = iodPxOnScreen / CGFloat(normIOD)
            }
        }
        
        print("✅ Target oval locked with \(staticTargetOvalCoordinates.count) points")
    }

    // Helper to calculate normalized IOD
    private func calculateNormalizedIOD(leftEyeIdx: Int = 33, rightEyeIdx: Int = 263) -> Float {
        guard NormalizedPoints.count > max(leftEyeIdx, rightEyeIdx) else { return 0 }
        let l = NormalizedPoints[leftEyeIdx]
        let r = NormalizedPoints[rightEyeIdx]
        let dx = r.x - l.x
        let dy = r.y - l.y
        return sqrt(dx * dx + dy * dy)
    }

    // Add method to reset/unlock target
    func resetTargetOval() {
        staticTargetOvalCoordinates.removeAll()
        isTargetOvalLocked = false
        targetOvalScale = 0
        print("🔓 Target oval reset")
    }
}

// MARK: - Array Extension
extension Array where Element == (x: Float, y: Float) {
    var asSIMD2: [SIMD2<Float>] { map { SIMD2<Float>($0.x, $0.y) } }
}
