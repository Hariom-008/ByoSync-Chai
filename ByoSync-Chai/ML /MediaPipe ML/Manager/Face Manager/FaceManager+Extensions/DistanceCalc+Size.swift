import SwiftUI

// MARK: - Mode of Collection
enum FrameCollectionMode: String, Codable {
    case registration
    case verification
}

// MARK: - Struct for distance + IOD
struct FrameDistance {
    let distances: [Float]
    let iod: Float
}

// MARK: - Calculating Distances for each frame
extension FaceManager {

    private var IOD_NORM_MAX: Float { 0.22 }

    // Function to remove extra digits after 4 digits after decimal
    @inline(__always)
    private func trunc4(_ x: Float) -> Float {
        let factor: Float = 10_000
        return Float(Int(x * factor)) / factor   // truncate toward 0
    }

    // 1) Registration Mode: should we accept this frame?
    //    ✅ NO direction concept anymore
    private func shouldAcceptRegistrationFrame() -> Bool {
        switch registrationPhase {
        case .centerCollecting:
            // Phase 1 (centre tracking):
            // iodIsValid && iodNormalized<=0.31 && isHeadPoseStable && faceInsideOval
            return iodIsValid
            && iodNormalized <= IOD_NORM_MAX
            && isHeadPoseStable()
            && faceisInsideFaceOval

        case .movementCollecting:
            // Phase 2 (movement tracking):
            // isHeadPoseStable && faceInsideOval
            return isHeadPoseStable()
            && faceisInsideFaceOval

        case .done:
            return false
        }
    }

    // 2) Registration storage (no direction, just store by phase)
    private func storeRegistrationFrame(_ fd: FrameDistance) {
        switch registrationPhase {
        case .centerCollecting:
            centerFrames.append(fd)
            centerFramesCount = centerFrames.count
            totalFramesCollected = centerFrames.count + movementFrames.count

            // transition when 60 collected
            if centerFramesCount >= 60 {
                startMovementPhase(durationSec: 15)
            }

        case .movementCollecting:
            movementFrames.append(fd)
            movementFramesCount = movementFrames.count
            totalFramesCollected = centerFrames.count + movementFrames.count

        case .done:
            break
        }
    }

    // MARK: - Main distance compute + accept + store
    func calculateOptionalAndMandatoryDistances() {

        @inline(__always)
        func d(_ i: Int, _ j: Int, _ pts: [(x: Float, y: Float)]) -> Float {
            Helper.shared.calculateDistance(pts[i], pts[j])
        }

        guard !isBusy else { return }

        // Decide acceptance based on mode + registration phase
        let accept: Bool
        switch faceAuthManager.currentMode {
        case .registration:
            accept = shouldAcceptRegistrationFrame()

        case .verification:
            // Verification:
            // iodIsValid && iodNormalized<=0.31 && isHeadPoseStable && faceInsideOval
            accept = iodIsValid
            && iodNormalized <= IOD_NORM_MAX
            && isHeadPoseStable()
            && faceisInsideFaceOval
        }

        guard accept else {
            DispatchQueue.main.async { [weak self] in self?.rejectedFrames += 1 }
            return
        }

        // Snapshot IOD for this accepted frame
        let iodAtCapture = iodNormalized

        let points = NormalizedPoints
        guard !points.isEmpty else { return }

        let mand = mandatoryLandmarkPoints.sorted()
        let opt  = selectedOptionalLandmarks

        var allDistances: [Float] = []
        allDistances.reserveCapacity(316)

        // mand-mand pairs
        for i in 0..<mand.count {
            let a = mand[i]
            for j in (i + 1)..<mand.count {
                allDistances.append(trunc4(d(a, mand[j], points)))
            }
        }

        // opt ring
        for i in 0..<opt.count {
            allDistances.append(trunc4(d(opt[i], opt[(i + 1) % opt.count], points)))
        }

        // mand-opt
        for a in mand {
            for b in opt {
                allDistances.append(trunc4(d(a, b, points)))
            }
        }

        guard allDistances.count == 316 else {
            DispatchQueue.main.async { [weak self] in self?.rejectedFrames += 1 }
            return
        }

        let fd = FrameDistance(distances: allDistances, iod: iodAtCapture)
        let pb = latestPixelBuffer

        DispatchQueue.main.async { [weak self] in
            guard let self, !self.isBusy else { return }

            switch self.faceAuthManager.currentMode {
            case .registration:
                self.storeRegistrationFrame(fd)

            case .verification:
                self.verificationFrameCollectedDistances.append(fd)
                #if DEBUG
                print("Verification Mode Frame Collection : \(self.verificationFrameCollectedDistances.count)")
                #endif
                self.totalFramesCollected = self.verificationFrameCollectedDistances.count
            }

            self.frameRecordedTrigger.toggle()

            if let pb {
                self.enqueueAcceptedFrameUpload(frameIndex: self.totalFramesCollected, pixelBuffer: pb)
            }
        }
    }
}

// MARK: - Registration phase timers/state
extension FaceManager {

    func startMovementPhase(durationSec: Int) {
        let end = Date().addingTimeInterval(TimeInterval(durationSec))
        registrationPhase = .movementCollecting(endAt: end)
        movementSecondsRemaining = durationSec

        movementTimer?.cancel()
        movementTimer = nil

        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now(), repeating: 0.2)
        t.setEventHandler { [weak self] in
            guard let self else { return }
            guard case let .movementCollecting(endAt) = self.registrationPhase else { return }

            let rem = max(0, Int(ceil(endAt.timeIntervalSinceNow)))
            self.movementSecondsRemaining = rem

            if rem <= 0 {
                self.registrationPhase = .done
                self.registrationComplete = true
                self.movementTimer?.cancel()
                self.movementTimer = nil
            }
        }

        movementTimer = t
        t.resume()
    }

//    func resetRegistrationState() {
//        movementTimer?.cancel()
//        movementTimer = nil
//
//        registrationPhase = .centerCollecting
//        registrationComplete = false
//
//        centerFrames.removeAll()
//        movementFrames.removeAll()
//
//        centerFramesCount = 0
//        movementFramesCount = 0
//        movementSecondsRemaining = 0
//        totalFramesCollected = 0
//    }
}

// MARK: - Upload helpers
extension FaceManager {

    func registrationFramesForUpload() -> [FrameDistance] {
        (centerFrames + movementFrames).filter { $0.distances.count == 316 }
    }

    func verificationFrames10() -> [FrameDistance] {
        let frames = verificationFrameCollectedDistances

        guard frames.count >= 10 else {
            #if DEBUG
            print("⚠️ Not enough valid frames. Have \(frames.count), need 10.")
            #endif
            return []
        }

        let selectedFrames = frames.suffix(10)

        let iodScaledFrames: [FrameDistance] = selectedFrames.map { frame in
            let scaledDistances = frame.distances.map { $0 / frame.iod }

            return FrameDistance(
                distances: scaledDistances,
                iod: frame.iod
            )
        }

        #if DEBUG
        print("✅ Verification frames prepared: \(iodScaledFrames.count) frames, IOD-scaled")
        #endif

        return iodScaledFrames
    }

}
