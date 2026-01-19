import Foundation
import CoreGraphics

extension FaceManager {
    /// Builds the on-screen oval from **NormalizedPoints.
    ///
    /// Mapping:
    ///   screen = center + normalized * scale
    ///   where scale = iodPx_on_screen / normIOD
    func updateTargetFaceOvalCoordinates(
        screenWidth: CGFloat,
        screenHeight: CGFloat,
        leftEyeOuterIdx: Int = 33,
        rightEyeOuterIdx: Int = 263,
        fallbackScale: CGFloat = 235.0
    ) {
        // Reset for this frame
        TargetFaceOvalCoordinates.removeAll(keepingCapacity: true)
        TransalatedScaledFaceOvalCoordinates.removeAll(keepingCapacity: true)

        guard !NormalizedPoints.isEmpty else { return }

        // 1) Grab face-oval points in normalized space
        let normOval: [(x: Float, y: Float)] = faceOvalIndices.compactMap { idx in
            guard idx >= 0, idx < NormalizedPoints.count else { return nil }
            return NormalizedPoints[idx]
        }
        
        guard !normOval.isEmpty else { return }

        // 2) Compute IOD in normalized space
        var normIOD: Float = 0
        if NormalizedPoints.count > max(leftEyeOuterIdx, rightEyeOuterIdx) {
            let l = NormalizedPoints[leftEyeOuterIdx]
            let r = NormalizedPoints[rightEyeOuterIdx]
            let dx = r.x - l.x
            let dy = r.y - l.y
            normIOD = sqrt(dx * dx + dy * dy)
        }

        // 3) Convert iodPixels (camera px) -> iodPx on preview (points) using aspect-fill scale
        let camW = max(imageSize.width, 1e-6)
        let camH = max(imageSize.height, 1e-6)
        let scaleToPreview = max(screenWidth / camW, screenHeight / camH)
        let iodPxOnScreen = CGFloat(iodPixels) * scaleToPreview

        // 4) Final mapping scale: normalized units -> screen points
        let scale: CGFloat
        if normIOD > 1e-6, iodPxOnScreen > 0 {
            scale = iodPxOnScreen / CGFloat(normIOD)
        } else {
            scale = fallbackScale
        }

        let cx = screenWidth / 2.0
        let cy = screenHeight / 2.0

        // 5) Build the oval points in screen space (centered)
        TransalatedScaledFaceOvalCoordinates.reserveCapacity(normOval.count)
        for p in normOval {
            TransalatedScaledFaceOvalCoordinates.append(
                (x: cx - CGFloat(p.x) * scale,
                 y: cy - CGFloat(p.y) * scale)   // ✅ invert Y for screen space
            )
        }

        // Keeping this for compatibility/debugging (same points, same meaning now)
        TargetFaceOvalCoordinates = TransalatedScaledFaceOvalCoordinates
    }

}
// MARK: - Face Oval Alignment Check
extension FaceManager {
    
    /// Checks if key face landmarks (151, 345, 175, 116) are inside the target oval
    /// These points represent: nose tip, left cheek, right cheek, and chin area
    func updateFaceOvalAlignment() {
        // Key landmark indices to check
        let checkIndices = [151, 345, 175, 116]
        
        // Reset if prerequisites not met
        guard !NormalizedPoints.isEmpty,
              !TransalatedScaledFaceOvalCoordinates.isEmpty,
              TransalatedScaledFaceOvalCoordinates.count > 2 else {
            faceisInsideFaceOval = false
            #if DEBUG
            print("❌ [Oval Alignment] Missing normalized points or oval coordinates")
            #endif
            return
        }
        
        // Verify all check indices are valid
        guard checkIndices.allSatisfy({ $0 < NormalizedPoints.count }) else {
            faceisInsideFaceOval = false
            #if DEBUG
            print("❌ [Oval Alignment] Check indices out of range")
            #endif
            return
        }
        
        // Calculate the scale and center (same as updateTargetFaceOvalCoordinates)
        let screenWidth = TransalatedScaledFaceOvalCoordinates.map { $0.x }.max()! -
                          TransalatedScaledFaceOvalCoordinates.map { $0.x }.min()!
        let screenHeight = TransalatedScaledFaceOvalCoordinates.map { $0.y }.max()! -
                           TransalatedScaledFaceOvalCoordinates.map { $0.y }.min()!
        
        // Get center from existing oval (approximate)
        let cx = TransalatedScaledFaceOvalCoordinates.map { $0.x }.reduce(0, +) / CGFloat(TransalatedScaledFaceOvalCoordinates.count)
        let cy = TransalatedScaledFaceOvalCoordinates.map { $0.y }.reduce(0, +) / CGFloat(TransalatedScaledFaceOvalCoordinates.count)
        
        // Calculate scale from IOD
        let leftEyeOuterIdx = 33
        let rightEyeOuterIdx = 263
        var normIOD: Float = 0
        if NormalizedPoints.count > max(leftEyeOuterIdx, rightEyeOuterIdx) {
            let l = NormalizedPoints[leftEyeOuterIdx]
            let r = NormalizedPoints[rightEyeOuterIdx]
            let dx = r.x - l.x
            let dy = r.y - l.y
            normIOD = sqrt(dx * dx + dy * dy)
        }
        
        let camW = max(imageSize.width, 1e-6)
        let camH = max(imageSize.height, 1e-6)
        
        // Using approximate screen dimensions from oval
        let maxDim = max(screenWidth, screenHeight) * 1.5 // rough estimate
        let scaleToPreview = maxDim / max(camW, camH)
        let iodPxOnScreen = CGFloat(iodPixels) * scaleToPreview
        
        let scale: CGFloat
        if normIOD > 1e-6, iodPxOnScreen > 0 {
            scale = iodPxOnScreen / CGFloat(normIOD)
        } else {
            faceisInsideFaceOval = false
            #if DEBUG
            print("❌ [Oval Alignment] Invalid scale calculation")
            #endif
            return
        }
        
        // Transform check points to screen space (same formula as oval points)
        let checkPointsScreen: [(x: CGFloat, y: CGFloat)] = checkIndices.map { idx in
            let p = NormalizedPoints[idx]
            return (
                x: cx - CGFloat(p.x) * scale,
                y: cy - CGFloat(p.y) * scale
            )
        }
        
        // Create path from oval coordinates
        var ovalPath = CGPath(
            rect: .zero,
            transform: nil
        )
        
        let mutablePath = CGMutablePath()
        if let firstPoint = TransalatedScaledFaceOvalCoordinates.first {
            mutablePath.move(to: CGPoint(x: firstPoint.x, y: firstPoint.y))
            for i in 1..<TransalatedScaledFaceOvalCoordinates.count {
                let point = TransalatedScaledFaceOvalCoordinates[i]
                mutablePath.addLine(to: CGPoint(x: point.x, y: point.y))
            }
            mutablePath.closeSubpath()
        }
        ovalPath = mutablePath
        
        // Check if ALL check points are inside the oval path
        let allPointsInside = checkPointsScreen.allSatisfy { point in
            ovalPath.contains(CGPoint(x: point.x, y: point.y))
        }
        
        faceisInsideFaceOval = allPointsInside
        
//        #if DEBUG
//        if allPointsInside {
//            print("✅ [Oval Alignment] All key landmarks inside target oval")
//        } else {
//            print("❌ [Oval Alignment] Some key landmarks outside target oval")
//            for (idx, point) in zip(checkIndices, checkPointsScreen) {
//                let isInside = ovalPath.contains(CGPoint(x: point.x, y: point.y))
//                print("   • Landmark \(idx): \(isInside ? "✅ inside" : "❌ outside")")
//            }
//        }
       // #endif
    }
}
