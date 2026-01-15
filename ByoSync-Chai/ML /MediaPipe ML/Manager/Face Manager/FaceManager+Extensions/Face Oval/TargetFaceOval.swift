import Foundation
import CoreGraphics

extension FaceManager {
    // MARK: - Point in Ellipse Check
    private func pointInEllipse(_ p: CGPoint, center: CGPoint, width: CGFloat, height: CGFloat) -> Bool {
        let dx = p.x - center.x
        let dy = p.y - center.y
        let a = width / 2.0  // semi-major axis
        let b = height / 2.0  // semi-minor axis
        
        // Ellipse equation: (x-cx)²/a² + (y-cy)²/b² <= 1
        let result = (dx * dx) / (a * a) + (dy * dy) / (b * b)
        return result <= 1.0
    }

    private func normalizedToScreen(_ p: (x: Float, y: Float),
                                    cx: CGFloat,
                                    cy: CGFloat,
                                    scale: CGFloat) -> CGPoint {
        CGPoint(
            x: cx - CGFloat(p.x) * scale,
            y: cy - CGFloat(p.y) * scale
        )
    }

    /// Check if face points are inside the STATIC geometric oval
    /// - Parameters:
    ///   - requiredInsideFraction: 1.0 = all points inside, 0.9 = 90% inside, etc.
    private func updateFaceInsideOvalFlag(cx: CGFloat,
                                         cy: CGFloat,
                                         scale: CGFloat,
                                         ovalCenter: CGPoint,
                                         ovalWidth: CGFloat,
                                         ovalHeight: CGFloat,
                                         requiredInsideFraction: CGFloat = 1.0) {
        guard !NormalizedPoints.isEmpty else {
            faceisInsideFaceOval = false
            return
        }

        // Use your chosen landmark set (facePoints indices)
        let indices = self.facePoints

        var total = 0
        var insideCount = 0

        for idx in indices {
            guard idx >= 0, idx < NormalizedPoints.count else { continue }
            total += 1

            let np = NormalizedPoints[idx]
            let sp = normalizedToScreen(np, cx: cx, cy: cy, scale: scale)

            if pointInEllipse(sp, center: ovalCenter, width: ovalWidth, height: ovalHeight) {
                insideCount += 1
            }
        }

        guard total > 0 else {
            faceisInsideFaceOval = false
            return
        }

        let frac = CGFloat(insideCount) / CGFloat(total)
        faceisInsideFaceOval = (frac >= requiredInsideFraction)
        
        print("🎯 Face inside static oval: \(faceisInsideFaceOval) (\(insideCount)/\(total) points, \(Int(frac*100))%)")
    }

    /// Builds static geometric oval and checks if face is inside
    func updateTargetFaceOvalCoordinates(
        screenWidth: CGFloat,
        screenHeight: CGFloat,
        leftEyeOuterIdx: Int = 33,
        rightEyeOuterIdx: Int = 263,
        fallbackScale: CGFloat = 235.0
    ) {
        // Clear old coordinates (not used anymore with geometric oval)
        TargetFaceOvalCoordinates.removeAll(keepingCapacity: true)
        TransalatedScaledFaceOvalCoordinates.removeAll(keepingCapacity: true)

        guard !NormalizedPoints.isEmpty else {
            faceisInsideFaceOval = false
            return
        }

        // ✅ STATIC GEOMETRIC OVAL (matches Android)
        let cx = screenWidth / 2.0
        let cy = screenHeight * 0.45  // 45% from top
        
        let ovalWidth = screenWidth * 0.75   // 75% of screen width
        let ovalHeight = screenHeight * 0.40  // 40% of screen height
        
        let ovalCenter = CGPoint(x: cx, y: cy)
        
        // Calculate scale for face point mapping (same as before)
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
        let scaleToPreview = max(screenWidth / camW, screenHeight / camH)
        let iodPxOnScreen = CGFloat(iodPixels) * scaleToPreview

        let scale: CGFloat
        if normIOD > 1e-6, iodPxOnScreen > 0 {
            scale = iodPxOnScreen / CGFloat(normIOD)
        } else {
            scale = fallbackScale
        }

        // ✅ Check if face landmarks are inside the static geometric oval
        updateFaceInsideOvalFlag(
            cx: cx,
            cy: cy,
            scale: scale,
            ovalCenter: ovalCenter,
            ovalWidth: ovalWidth,
            ovalHeight: ovalHeight,
            requiredInsideFraction: 1.0  // Use 0.9 for more tolerance
        )
        
        print("📐 Static oval: center(\(ovalCenter.x), \(ovalCenter.y)), size(\(ovalWidth) x \(ovalHeight))")
    }
}
