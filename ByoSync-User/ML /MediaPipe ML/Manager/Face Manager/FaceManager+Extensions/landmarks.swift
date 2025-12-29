import Foundation
import simd

extension FaceManager {

    @inline(__always)
    private func trunc4(_ x: Float) -> Float {
        let factor: Float = 10_000
        return Float(Int(x * factor)) / factor   // truncate toward 0
    }

    func calculateOptionalAndMandatoryDistances() {
        // ✅ 1) Hard stop: don't even compute while busy
        guard !isBusy else { return }

        // ✅ 2) Snapshot points (avoid races)
        let points = NormalizedPoints
        guard !points.isEmpty else {
            #if DEBUG
            print("⚠️ NormalizedPoints is empty, cannot compute pattern vector")
            #endif
            return
        }

        let mand = mandatoryLandmarkPoints.sorted()
        let opt  = selectedOptionalLandmarks

        let maxIdx = max(mand.max() ?? 0, opt.max() ?? 0)
        guard maxIdx < points.count else {
            print("⚠️ Invalid landmark index \(maxIdx) for NormalizedPoints.count = \(points.count)")
            return
        }

        @inline(__always)
        func d(_ i: Int, _ j: Int) -> Float {
            let p1 = points[i]
            let p2 = points[j]
            return Helper.shared.calculateDistance(p1, p2)
        }

        var allDistances: [Float] = []
        allDistances.reserveCapacity(316)

        // 1). mandatory×mandatory
        for i in 0..<mand.count {
            let idxA = mand[i]
            for j in (i + 1)..<mand.count {
                let idxB = mand[j]
                allDistances.append(trunc4(d(idxA, idxB)))
            }
        }

        // 2). optional chain
        for i in 0..<opt.count {
            let idxA = opt[i]
            let idxB = opt[(i + 1) % opt.count]
            allDistances.append(trunc4(d(idxA, idxB)))
        }

        // 3). mandatory×optional
        for a in mand {
            for b in opt {
                allDistances.append(trunc4(d(a, b)))
            }
        }

        //Gate right before storing
        guard iodIsValid,
              isNoseTipCentered,
              isHeadPoseStable(),
              !allDistances.isEmpty,
              !isBusy
        else {
            DispatchQueue.main.async { [weak self] in
                self?.rejectedFrames += 1
            }
            return
        }

        // Publish state on main
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard !self.isBusy else { return }

            self.AllFramesOptionalAndMandatoryDistance.append(allDistances)
            self.totalFramesCollected = self.AllFramesOptionalAndMandatoryDistance.count
            self.frameRecordedTrigger.toggle()
            
            self.enqueueAcceptedFrameUpload(frameIndex: self.totalFramesCollected)
            #if DEBUG
            print("""
            ✅ FRAME ACCEPTED & STORED:
               frameIndex (1-based) = \(totalFramesCollected)
               vector length        = \(allDistances.count)
               total stored frames  = \(AllFramesOptionalAndMandatoryDistance.count)
            """)
            #endif
        }
    }
}
