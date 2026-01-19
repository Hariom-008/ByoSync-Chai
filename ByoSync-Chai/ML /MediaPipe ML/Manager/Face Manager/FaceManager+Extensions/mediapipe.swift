import Foundation
import MediaPipeTasksVision
internal import AVFoundation
import Foundation
import CoreGraphics

// MARK: - FaceLandmarkerLiveStreamDelegate + Mediapipe
extension FaceManager: FaceLandmarkerLiveStreamDelegate {
    /// Sets up MediaPipe Face Landmarker with live stream mode
    func setupMediaPipe() {
        do {
            guard let modelPath = Bundle.main.path(forResource: "face_landmarker", ofType: "task") else {
                print("❌ face_landmarker.task file not found")
                return
            }
            
            let options = FaceLandmarkerOptions()
            options.baseOptions.modelAssetPath = modelPath
            options.runningMode = .liveStream
            options.numFaces = 1
            options.faceLandmarkerLiveStreamDelegate = self
            
            // 🔒 Increase thresholds to be stricter about “face detected”
            options.minFaceDetectionConfidence = 0.80
            options.minFacePresenceConfidence = 0.80
            options.minTrackingConfidence = 0.80
            
            faceLandmarker = try FaceLandmarker(options: options)
            print("✅ MediaPipe Face Landmarker initialized")
        } catch {
            print("❌ Error initializing Face Landmarker: \(error.localizedDescription)")
        }
    }
    
    func faceLandmarker(_ faceLandmarker: FaceLandmarker,
                        didFinishDetection result: FaceLandmarkerResult?,
                        timestampInMilliseconds: Int,
                        error: Error?) {
        
        if let error = error {
            print("❌ Face detection error: \(error.localizedDescription)")
            return
        }
        
        guard let result = result,
              let firstFace = result.faceLandmarks.first else {
            // No face detected → clear data
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.CameraFeedCoordinates = []
                self.CalculationCoordinates = []
                
               // self.ScreenCoordinates = []
                self.rawMediaPipePoints = []
                self.irisDistanceRatio = nil
                self.ratioIsInRange = false
                self.verificationFrameCollectedDistances = []
                
//                self.TargetFaceOvalCoordinates.removeAll()
//                self.TransalatedScaledFaceOvalCoordinates.removeAll()
                self.FaceOvalIsInTarget = false
                
               // self.resetIODGate()
               // self.resetRegistrationState()
                
            }
            return
        }
        
        // Validate frame size
        guard imageSize.width > 0, imageSize.height > 0 else {
            print("⚠️ Image size not yet set")
            return
        }
        
        let imageWidth = Float(imageSize.width)
        let imageHeight = Float(imageSize.height)
        
        // RAW MediaPipe normalized points (0–1)
        let rawPoints: [(x: Float, y: Float)] = firstFace.map { lm in
            (x: lm.x, y: lm.y)
        }
        
        // Transform landmarks to camera feed coordinates
        let coords: [(x: Float, y: Float)] = firstFace.map { lm in
            (x: lm.x * imageWidth, y: lm.y * imageHeight)
        }
        
        //        // Transform landmarks for calculations (flipped)
        //        let calcCoords: [(x: Float, y: Float)] = firstFace.map { lm in
        //            let flippedY = 1 - lm.y
        //            let flippedX = 1 - lm.x
        //            return (x: flippedX * frameWidth, y: flippedY * frameHeight)
        //        }
        
        // Process on main queue
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.lastDetectionTimestampMs = timestampInMilliseconds
            
            
            // Store coordinates
            self.CameraFeedCoordinates = coords
            //            self.CalculationCoordinates = calcCoords
            self.rawMediaPipePoints = rawPoints
            
            // IOD gate (per-frame)
            if faceAuthManager.currentMode == .verification{
                self.iodMin = 0.28
                self.iodMax = 0.29
            }else{
                if registrationPhase == .centerCollecting{
                    self.iodMin = 0.28
                    self.iodMax = 0.29
                }else{
                    self.iodMin = 0.26
                    self.iodMax = 0.30
                }
            }
            self.updateIODGate(imageWidth: imageWidth, imageHeight: imageHeight,iodMin: iodMin,iodMax: iodMax)
            
            // Convert to screen coordinates (kept; other UI may still use this)
            if let previewLayer = self.previewLayer {
                let cameraResolution = CGSize(width: CGFloat(imageWidth), height: CGFloat(imageHeight))
                
                let screenCoords: [(x: Float, y: Float)] = firstFace.map { lm in
                    let screenPoint = self.convertToScreenCoordinates(
                        normalizedX: CGFloat(lm.x),
                        normalizedY: CGFloat(lm.y),
                        previewLayer: previewLayer,
                        cameraResolution: cameraResolution
                    )
                    return (x: screenPoint.x, y: screenPoint.y)
                }
                
                self.CalculationCoordinates = screenCoords
            } else {
                //self.ScreenCoordinates = []
                self.TransalatedScaledFaceOvalCoordinates.removeAll()
            }
            
            // Geometric calculations
            self.calculateCentroidUsingFaceOval()
            self.calculateTranslated()
            self.calculateTranslatedSquareDistance()
            self.calculateRMSOfTransalted()
            self.calculateNormalizedPoints()
            
//            if let previewLayer = self.previewLayer {
//                let b = previewLayer.bounds
//
//                // CalculationCoordinates are already in previewLayer.bounds space
//                let ptsCG: [CGPoint] = self.CalculationCoordinates.map {
//                    CGPoint(x: CGFloat($0.x), y: CGFloat($0.y))
//                }
//
//                self.updateNoseTipCenterStatusFromCalcCoords(
//                    pixelPoints: ptsCG,
//                    screenCenterX: b.midX,
//                    screenCenterY: b.midY,
//                    tolerancePx: 10.0
//                )
//            } else {
//                self.isNoseTipCentered = false
//            }
            
            
            // Build face-oval overlay from NormalizedPoints
            // Build face-oval overlay from NormalizedPoints
            if let previewLayer = self.previewLayer {
                let bounds = previewLayer.bounds
                self.updateTargetFaceOvalCoordinates(
                    screenWidth: bounds.width,
                    screenHeight: bounds.height
                )
                
                // ✅ Check if key face landmarks are inside the oval
                self.updateFaceOvalAlignment()
            }
            
            // Eye Aspect Ratio -- NOT IN USE
            let simdPoints = self.CalculationCoordinates.asSIMD2
            self.EAR = self.earCalc(from: simdPoints)
            
            // Gaze tracking logic -- NOT IN USE
            //            if self.isCentreTracking && !self.isMovementTracking {
            //                self.AppendActualLeftRight()
            //            } else if !self.isCentreTracking && self.isMovementTracking {
            //                self.calculateGazeVector()
            //            }
            
            // Head pose estimation
            if let (pitch, yaw, roll) = self.computeAngles(from: self.NormalizedPoints) {
                self.Pitch = pitch
                self.Yaw = yaw
                self.Roll = roll
            } else {
                self.Pitch = -1000
                self.Yaw = -1000
                self.Roll = -1000
            }
            
            // Always calculate pattern (conditions checked inside function)
            self.calculateOptionalAndMandatoryDistances()
        }
    }
}
// MARK: - Coordinate to Pixel Value of type:FLOAT
extension FaceManager {
    struct Pixel{
        let x: Float
        let y: Float
    }
    /// Converts MediaPipe normalized coordinates to screen coordinates
    /// Accounts for: portrait orientation, mirroring, and aspect fill scaling
    func convertToScreenCoordinates(
        normalizedX: CGFloat,
        normalizedY: CGFloat,
        previewLayer: AVCaptureVideoPreviewLayer,
        cameraResolution: CGSize
    ) -> Pixel {
        
        let previewBounds = previewLayer.bounds
        let previewWidth = previewBounds.width
        let previewHeight = previewBounds.height
        
        // Calculate the actual visible area considering aspect fill
        let cameraAspectRatio = cameraResolution.width / cameraResolution.height
        let previewAspectRatio = previewWidth / previewHeight
        
        var scaleX: CGFloat = 1.0
        var scaleY: CGFloat = 1.0
        var offsetX: CGFloat = 0.0
        var offsetY: CGFloat = 0.0
        
        if cameraAspectRatio > previewAspectRatio {
            // Camera is wider - fills height, crops width
            scaleY = previewHeight / cameraResolution.height
            scaleX = scaleY
            
            let scaledCameraWidth = cameraResolution.width * scaleX
            offsetX = (previewWidth - scaledCameraWidth) / 2.0
        } else {
            // Camera is taller - fills width, crops height
            scaleX = previewWidth / cameraResolution.width
            scaleY = scaleX
            
            let scaledCameraHeight = cameraResolution.height * scaleY
            offsetY = (previewHeight - scaledCameraHeight) / 2.0
        }
        
        // Convert normalized [0,1] to camera pixel coordinates
        let cameraX = (1-normalizedX) * cameraResolution.width
        let cameraY = (1-normalizedY) * cameraResolution.height
        
        // Scale to screen and add offset
        let screenX = cameraX * scaleX + offsetX
        let screenY = cameraY * scaleY + offsetY
        
        return Pixel(x: Float(screenX), y: Float(screenY))
    }
}



