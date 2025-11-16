import AVFoundation
import UIKit
import MediaPipeTasksVision
import Combine
import simd
import Foundation

final class CameraManager: NSObject, ObservableObject {
    // MARK: - Published data (UI-relevant)
    @Published var FaceOwnerPhoneNumber: String = "+91"
    @Published var imageSize: CGSize = .zero
    
    @Published var NormalizedPoints : [(x:Float,y:Float)] = []
    
    @Published var EAR: Float = 0
    @Published var Pitch: Float = 0
    @Published var Yaw: Float = 0
    @Published var Roll: Float = 0
    
    @Published var FaceScale: Float = 0
    
    @Published var isCentreTracking: Bool = false
    @Published var isMovementTracking: Bool = false
    
    @Published var GazeVector: (x:Float,y:Float) = (0,0)
    
    @Published var actualLeftMean:(x:Float,y:Float) = (0,0)
    @Published var actualRightMean:(x:Float,y:Float) = (0,0)
    
    // Liveness gating
    @Published var isFaceReal: Bool = false
    @Published var rejectedFrames: Int = 0
    
    // Frame collection status
    @Published var frameRecordedTrigger: Bool = false
    @Published var totalFramesCollected: Int = 0
    
    // Uploading
    @Published var isUploadingPattern: Bool = false
    @Published var uploadSuccess: Bool = false
    @Published var uploadError: String?
    @Published var hasEnteredPhoneNumber: Bool = false
    
    @Published var latestPixelBuffer: CVPixelBuffer?
    
    // MARK: - Internal-only math buffers (NO @Published)
    var CameraFeedCoordinates: [(x: Float, y: Float)] = []
    var CalculationCoordinates: [(x: Float, y: Float)] = []
    var centroid : (x:Float,y:Float)?
    
    var Translated:[(x:Float,y:Float)] = []
    var TranslatedSquareDistance: [Float] = []
    var scale: Float = 0
    
    var actualLeftList:[(x:Float,y:Float)] = []
    var actualRightList:[(x:Float,y:Float)] = []
    
    var landmarkDistanceLists: [[Float]] = []
    
    var previewLayer: AVCaptureVideoPreviewLayer?
    var cameraDevice: AVCaptureDevice?

    
    private let faceOvalIndices: [Int] = [
        10, 338, 297, 332, 284, 251, 389, 356, 454, 323,
        361, 288, 397, 365, 379, 378, 400, 377, 152, 148,
        176, 149, 150, 136, 172, 58, 132, 93, 234, 127,
        162, 21, 54, 103, 67, 109
    ]

    private let mandatory_landmark_pairs: [(Int, Int)] = [
        (46,55), (70,46), (107,55), (70,107), // Right eyebrow
        (336,285), (285,276), (276,300), (300,336), // Left eyebrow
        (33,133), (133,9), (9,362), (362,263), // Eyes
        (33,98), (133,98), (9,98), // Nose edge
        (9,327), (362,327), (263,327), // Nose edge
        (9,4), // Nose major midline
        (98,327), (4,2) // Nose edge
    ]

 
    // MARK: - Camera + MediaPipe
    let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let processingQueue = DispatchQueue(label: "camera.processing.queue")
    
    #if canImport(MediaPipeTasksVision)
    private var faceLandmarker: FaceLandmarker?
    #endif

    override init() {
        super.init()
        #if canImport(MediaPipeTasksVision)
        setupMediaPipe()
        #endif
        sessionQueue.async { [weak self] in
            self?.setupCamera()
        }
    }

    private func setupCamera() {
        captureSession.beginConfiguration()
        
        // ↓↓↓ reduce resolution for performance
        captureSession.sessionPreset = .medium   // or .vga640x480
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                   for: .video,
                                                   position: .front) else {
            debugLog("❌ No front camera available")
            captureSession.commitConfiguration()
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if captureSession.canAddInput(input) { captureSession.addInput(input) }

            videoOutput.setSampleBufferDelegate(self, queue: processingQueue)
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            if captureSession.canAddOutput(videoOutput) { captureSession.addOutput(videoOutput) }

            if let conn = videoOutput.connection(with: .video) {
                conn.videoOrientation = .portrait
            }

            captureSession.commitConfiguration()
            captureSession.startRunning()
            debugLog("📸 Camera session started")
        } catch {
            debugLog("❌ Camera setup failed: \(error.localizedDescription)")
        }
    }


    // MARK: - Setup MediaPipe
    private func setupMediaPipe() {
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

            faceLandmarker = try FaceLandmarker(options: options)
            print("✅ MediaPipe Face Landmarker initialized")
        } catch {
            print("❌ Error initializing Face Landmarker: \(error.localizedDescription)")
        }
    }
    
    
    func calculateCentroidUsingFaceOval() {
        guard !CalculationCoordinates.isEmpty else {
            centroid = nil
            return
        }

        var sumX: Float = 0
        var sumY: Float = 0
        var count: Int = 0

        for idx in faceOvalIndices {
            if idx >= 0 && idx < CalculationCoordinates.count {
                let p = CalculationCoordinates[idx]
                sumX += p.x
                sumY += p.y
                count += 1
            }
        }

        guard count > 0 else {
            centroid = nil
            return
        }
        centroid = (x: sumX / Float(count), y: sumY / Float(count))
    }

    
    func calculateTranslated() {
        guard let c = centroid else {
            Translated = []
            return
        }

        // Build a new array from CalculationCoordinates by subtracting the centroid
        Translated = CalculationCoordinates.map { p in
            (x: p.x - c.x, y: p.y - c.y)
        }
    }
    func calculateTranslatedSquareDistance() {
        guard !Translated.isEmpty else {
            TranslatedSquareDistance = []
            return
        }

        // (x^2 + y^2) for each translated point
        TranslatedSquareDistance = Translated.map { p in
            p.x * p.x + p.y * p.y
        }
    }
    func calculateRMSOfTransalted() {
        let n = TranslatedSquareDistance.count
        guard n > 0 else {
            scale = 0
            return
        }

        // Sum, mean, then RMS
        let sum = TranslatedSquareDistance.reduce(0 as Float, +)
        let mean = sum / Float(n)
        scale = sqrt(max(0, mean)) // max guards tiny negative from FP error
    }
    
    func calculateNormalizedPoints() {
        // Need points and a non-zero scale
        let eps: Float = 1e-6
        guard !Translated.isEmpty, scale > eps else {
            NormalizedPoints = []
            return
        }

        NormalizedPoints = Translated.map { p in
            (x: p.x / scale, y: p.y / scale)
        }
    }
    
    
    /// Computes average Eye Aspect Ratio (EAR) from full 468-point mesh.
    /// Expects landmarks array indexed like MediaPipe FaceMesh (>= 388 elements).
    @inline(__always)
    private func dist(_ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Float { length(a - b) }

    func earCalc(from landmarks: [SIMD2<Float>]) -> Float {
        // We need up to index 387/385/380 etc., so ensure we have enough points.
        guard landmarks.count > 387 else { return 0 }

        // LEFT eye: (160,144), (158,153) / (33,133)
        let A_left = dist(landmarks[160], landmarks[144])
        let B_left = dist(landmarks[158], landmarks[153])
        let C_left = dist(landmarks[33],  landmarks[133])
        guard C_left > 0 else { return 0 }
        let ear_left = (A_left + B_left) / (2.0 * C_left)

        // RIGHT eye: (385,380), (387,373) / (362,263)
        let A_right = dist(landmarks[385], landmarks[380])
        let B_right = dist(landmarks[387], landmarks[373])
        let C_right = dist(landmarks[362], landmarks[263])
        guard C_right > 0 else { return 0 }
        let ear_right = (A_right + B_right) / (2.0 * C_right)

        return (ear_left + ear_right) / 2.0
    }
    // MARK: - Direct port of the Python function
    // Inputs should already be normalized so that x^2 + y^2 <= 1 (unit circle or inside).
    @inline(__always)
    func angleCalc(noseTip: (x: Float, y: Float),
                   verticalLine: (x: Float, y: Float)) -> (pitch: Float, yaw: Float, roll: Float) {

        let x = noseTip.x
        let y = noseTip.y

        // den = sqrt(max(0, 1 - x^2 - y^2))
        let oneMinusR2 = max(0 as Float, 1 - (x * x + y * y))
        let den = sqrtf(oneMinusR2)

        // Use atan2 for stability (same as numpy's arctan2)
        // pitch = atan2(y, den)
        // yaw   = atan2(x, den)
        // roll  = atan2(verticalLine.y, verticalLine.x)
        let pitch = atan2f(y, den)
        let yaw   = atan2f(x, den)
        let roll  = atan2f(verticalLine.y, verticalLine.x)

        return (pitch, yaw, roll)
    }

    // MARK: - Convenience: compute from landmarks (indices 4, 33, 263)
    func computeAngles(from landmarks: [(x: Float, y: Float)]) -> (pitch: Float, yaw: Float, roll: Float)? {
        // Need indices 4, 33, 263
        let needed = [4, 33, 263]
        guard needed.allSatisfy({ $0 < landmarks.count }) else { return nil }

        let nose = landmarks[4]
        let p33 = landmarks[33]
        let p263 = landmarks[263]

        // Vector from 263 -> 33 (as specified: 33 - 263)
        let verticalLine = (x: p33.x - p263.x, y: p33.y - p263.y)

        return angleCalc(noseTip: nose, verticalLine: verticalLine)
    }

    
    // Gaze Vector Functions

    /// Mean of a SUBSET (by landmark indices) of CalculationCoordinates.
    /// Skips any out-of-bounds indices safely.
    func meanOfCalculationCoordinates(_ coords: [(x: Float, y: Float)],
                                      indices: [Int]) -> (x: Float, y: Float)? {
        guard !coords.isEmpty, !indices.isEmpty else { return nil }

        var sx: Float = 0
        var sy: Float = 0
        var cnt: Int = 0

        for i in indices {
            if i >= 0, i < coords.count {
                sx += coords[i].x
                sy += coords[i].y
                cnt += 1
            }
        }
        guard cnt > 0 else { return nil }
        let n = Float(cnt)
        return (x: sx / n, y: sy / n)
    }

    // MARK: - Gaze pieces (iris means, eye means, optional gaze vectors)
    func calculateActualLeftRight(
        from coords: [(x: Float, y: Float)]
    ) -> (left: (x: Float, y: Float)?, right: (x: Float, y: Float)?) {

        // Indices
        let leftIrisIdx  = [468, 469, 470, 471, 472]
        let rightIrisIdx = [473, 474, 475, 476, 477]
        let leftEyeIdx   = [33, 7, 163, 144, 145, 153, 154, 155, 133, 173, 157, 158, 159, 160, 161, 246]
        let rightEyeIdx  = [362, 382, 381, 380, 374, 373, 390, 249, 263, 466, 388, 387, 386, 385, 384, 398]

        // Means (optionals)
        let leftIrisCentre  = meanOfCalculationCoordinates(coords, indices: leftIrisIdx)
        let rightIrisCentre = meanOfCalculationCoordinates(coords, indices: rightIrisIdx)
        let leftEyeCentre   = meanOfCalculationCoordinates(coords, indices: leftEyeIdx)
        let rightEyeCentre  = meanOfCalculationCoordinates(coords, indices: rightEyeIdx)

        // Need both eye centers to compute scale
        guard let le = leftEyeCentre, let re = rightEyeCentre else {
            self.FaceScale = 0
            return (nil, nil)
        }

        // Face scale
        let dx = re.x - le.x
        let dy = re.y - le.y
        var faceScale = sqrtf(dx*dx + dy*dy)
        if faceScale < 1e-6 { faceScale = 1e-6 }   // avoid Inf/NaN
        self.FaceScale = faceScale

        // Actual values = (iris - eye)/FaceScale (each side optional if iris missing)
        let actualLeft: (x: Float, y: Float)?
        if let li = leftIrisCentre {
            let dL = Helper.shared.sub(li, le)
           // actualLeft = Helper.shared.div(dL, faceScale)
            actualLeft = dL
        } else {
            actualLeft = nil
        }

        let actualRight: (x: Float, y: Float)?
        if let ri = rightIrisCentre {
            let dR = Helper.shared.sub(ri, re)
            //actualRight = Helper.shared.div(dR, faceScale)
            actualRight = dR
        } else {
            actualRight = nil
        }

        return (actualLeft, actualRight)
    }

    // 🔥 MODIFIED: Appending the value in list of actual left and actual right with liveness gating
    func AppendActualLeftRight(){
        // 🔥 Gate: Only collect during calibration if face is real
        guard isFaceReal || !isCentreTracking else {
            if isCentreTracking {
                print("⚠️ Skipping calibration data - Spoof detected")
            }
            return
        }
        
        let (actualLeft,actualRight) = calculateActualLeftRight(from: CalculationCoordinates)
        guard let actualLeft = actualLeft,let actualRight = actualRight else{
            return
        }
        self.actualLeftList.append(actualLeft)
        self.actualRightList.append(actualRight)
        print("""
              🧮 Length of actualLeftList = \(actualLeftList.count)  && 
              Last Value : X = \(actualLeftList[actualLeftList.count-1].x) , Y = \(actualLeftList[actualLeftList.count-1].y)
        """)
        print("""
            🧮 Length of actualRightList = \(actualRightList.count) &&
            Last Value : X = \(actualRightList[actualRightList.count-1].x) , Y = \(actualRightList[actualRightList.count-1].y)
        """)
        print("✅ Actual Left and Right Are Appended in the List")
    }
    
    func calculateCenterMeans() {
        guard !actualLeftList.isEmpty, !actualRightList.isEmpty else {
            print("⚠️ No values to calculate means for calibration")
            return
        }

        guard let meanLeft = Helper.shared.calculateMean(actualLeftList),
              let meanRight = Helper.shared.calculateMean(actualRightList) else {
            print("⚠️ Mean calculation failed")
            return
        }

        // Save the baseline
        actualLeftMean = meanLeft
        actualRightMean = meanRight

        print("✅ Calibration complete:")
        print("Left Mean: \(actualLeftMean)")
        print("Right Mean: \(actualRightMean)")
    }
    
    func calculateGazeVector() {
        guard isMovementTracking else { return }

        // Get current actual left/right from the frame
        let (maybeActualLeft, maybeActualRight) = calculateActualLeftRight(from: CalculationCoordinates)
        
        print("📏 Final Length of actualLeftList : \(actualLeftList.count)")
        print("📏 Final Length of actualRightList : \(actualRightList.count)")
        guard let actualLeft = maybeActualLeft,
              let actualRight = maybeActualRight else {
            print("⚠️ Could not unwrap actualLeft or actualRight")
            return
        }

        // Compute differences from the baseline means
        let diffLeft = Helper.shared.sub(actualLeft, actualLeftMean)
        let diffRight = Helper.shared.sub(actualRight, actualRightMean)
        
        // Average the deltas → gaze vector
        let sumDiff = Helper.shared.add(diffLeft, diffRight)
        GazeVector = Helper.shared.div(sumDiff, 2)
        
        print("🎯 GazeVector: \(GazeVector)")
    }
    
    
    /// Check if head pose is stable (within ±0.1 for pitch, yaw, roll)
    func isHeadPoseStable() -> Bool {
        let threshold: Float = 0.1
        return abs(Pitch) <= threshold &&
               abs(Yaw) <= threshold &&
               abs(Roll) <= threshold
    }

    /// 🔥 MODIFIED: Calculate distances between landmark pairs with liveness gating
    func calculateLandmarkDistances() {
        guard !NormalizedPoints.isEmpty else {
            print("⚠️ NormalizedPoints is empty")
            return
        }
        
        // 🔥 CRITICAL: Only collect frames when face is REAL
        guard isFaceReal else {
            rejectedFrames += 1
            print("❌ Frame rejected (\(rejectedFrames) total) - Spoof detected")
            return
        }
        
        var distances: [Float] = []
        
        for pair in mandatory_landmark_pairs {
            let idx1 = pair.0
            let idx2 = pair.1
            
            // Validate indices
            guard idx1 >= 0 && idx1 < NormalizedPoints.count,
                  idx2 >= 0 && idx2 < NormalizedPoints.count else {
                print("⚠️ Invalid landmark indices: (\(idx1), \(idx2))")
                return  // Skip this frame if any index is invalid
            }
            
            let p1 = NormalizedPoints[idx1]
            let p2 = NormalizedPoints[idx2]
            
            // Euclidean distance
            let dx = p2.x - p1.x
            let dy = p2.y - p1.y
            let distance = sqrtf(dx * dx + dy * dy)
            
            distances.append(distance)
        }
        
        // Append only if we have all distances
        if distances.count == mandatory_landmark_pairs.count {
            landmarkDistanceLists.append(distances)
            totalFramesCollected = landmarkDistanceLists.count
            
            // Trigger UI flash animation
            frameRecordedTrigger.toggle()
            
            print("✅ Frame \(landmarkDistanceLists.count): Collected \(distances.count) landmark distances [REAL FACE]")
            print("   Distances: \(distances.map { String(format: "%.4f", $0) }.joined(separator: ", "))")
        }
    }
    
    // 🔥 MODIFIED: Add reset function with rejectedFrames
    func resetForNewUser() {
        // Reset all data
        landmarkDistanceLists.removeAll()
        totalFramesCollected = 0
        actualLeftList.removeAll()
        actualRightList.removeAll()
        rejectedFrames = 0
        
        // Reset states
        isCentreTracking = false
        isMovementTracking = false
        uploadSuccess = false
        uploadError = nil
        isUploadingPattern = false
        isFaceReal = false
        
        // Reset phone number
        FaceOwnerPhoneNumber = "+91"
        hasEnteredPhoneNumber = false
        
        print("🔄 Reset complete - ready for new user")
    }
}





// MARK: - Capture frames
extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {

        if let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            DispatchQueue.main.async {
                self.latestPixelBuffer = buffer
            }
        }
        
        guard let faceLandmarker = faceLandmarker else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let image = try? MPImage(pixelBuffer: pixelBuffer) else { return }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        DispatchQueue.main.async { [weak self] in
            self?.imageSize = CGSize(width: width, height: height)
        }

        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let timestampMs = Int(CMTimeGetSeconds(timestamp) * 1000)

        do {
            try faceLandmarker.detectAsync(image: image, timestampInMilliseconds: timestampMs)
        } catch {
            debugLog("❌ detectAsync failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - MediaPipe Callback
extension CameraManager: FaceLandmarkerLiveStreamDelegate {
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
          //  print("⚠️ No face detected")
            return
        }

        // ✅ Step 1: Safely get the current frame size
        guard imageSize.width > 0, imageSize.height > 0 else {
            print("⚠️ Image size not yet set")
            return
        }

        let frameWidth = Float(imageSize.width)
        let frameHeight = Float(imageSize.height)

        // ✅ Step 2: Flip Y (1 - lm.y) and multiply by camera feed width/height
        let coords: [(x: Float, y: Float)] = firstFace.map { lm in
            (x: lm.x * frameWidth, y: lm.y * frameHeight)
        }

        let calcCoords: [(x: Float, y: Float)] = firstFace.map { lm in
            let flippedY = 1 - lm.y
            let flippedX = 1 - lm.x
            return (x: flippedX * frameWidth, y: flippedY * frameHeight)
        }


        // ✅ Step 3: Store results
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.CameraFeedCoordinates = coords
            self.CalculationCoordinates = calcCoords

            self.calculateCentroidUsingFaceOval()
            self.calculateTranslated()
            self.calculateTranslatedSquareDistance()
            self.calculateRMSOfTransalted()
            self.calculateNormalizedPoints()

            // Convert tuples -> SIMD2<Float> for EAR
            let simdPoints = self.CalculationCoordinates.asSIMD2
            self.EAR = self.earCalc(from: simdPoints)

            // ✅ 1️⃣ Collect data or calculate gaze vector depending on state
            if self.isCentreTracking && !self.isMovementTracking {
                // While calibrating: append samples for mean calculation
                self.AppendActualLeftRight()
            }
            else if !self.isCentreTracking && self.isMovementTracking {
                // While movement tracking: compute live gaze
                self.calculateGazeVector()
            }

            // ✅ 2️⃣ Compute face orientation (Pitch/Yaw/Roll)
            if let (pitch, yaw, roll) = self.computeAngles(from: self.NormalizedPoints) {
                self.Pitch = pitch
                self.Yaw = yaw
                self.Roll = roll
                
                // ✅ 3️⃣ Check if head pose is stable and collect landmark distances
                // 🔥 Frame collection now gated by isFaceReal inside calculateLandmarkDistances()
                if self.isHeadPoseStable() {
                    self.calculateLandmarkDistances()
                }
            } else {
                self.Pitch = 0
                self.Yaw = 0
                self.Roll = 0
            }
        }
    }
}


// Convert array of (x,y) tuples -> [SIMD2<Float>]
extension Array where Element == (x: Float, y: Float) {
    var asSIMD2: [SIMD2<Float>] { map { SIMD2<Float>($0.x, $0.y) } }
}
