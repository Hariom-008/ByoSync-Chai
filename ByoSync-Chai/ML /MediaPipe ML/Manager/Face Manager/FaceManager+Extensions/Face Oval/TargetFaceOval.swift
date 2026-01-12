import Foundation
import CoreGraphics

extension FaceManager {
    // MARK: - Point in Polygon (Ray Casting)
    private func pointInPolygon(_ p: CGPoint, polygon: [CGPoint]) -> Bool {
        guard polygon.count >= 3 else { return false }

        var inside = false
        var j = polygon.count - 1

        for i in 0..<polygon.count {
            let pi = polygon[i]
            let pj = polygon[j]

            // Check if edge crosses the horizontal ray to the right of point p
            let intersect = ((pi.y > p.y) != (pj.y > p.y)) &&
                (p.x < (pj.x - pi.x) * (p.y - pi.y) / (pj.y - pi.y + 1e-12) + pi.x)

            if intersect { inside.toggle() }
            j = i
        }
        return inside
    }

    private func normalizedToScreen(_ p: (x: Float, y: Float),
                                    cx: CGFloat,
                                    cy: CGFloat,
                                    scale: CGFloat) -> CGPoint {
        // Must match your oval mapping exactly (including Y inversion and the "-" sign)
        CGPoint(
            x: cx - CGFloat(p.x) * scale,
            y: cy - CGFloat(p.y) * scale
        )
    }

    /// Call this right after you compute TransalatedScaledFaceOvalCoordinates
    /// - Parameters:
    ///   - requiredInsideFraction: 1.0 = all points inside, 0.9 = 90% inside, etc.
    private func updateFaceInsideOvalFlag(cx: CGFloat,
                                         cy: CGFloat,
                                         scale: CGFloat,
                                         requiredInsideFraction: CGFloat = 1.0) {
        let poly = TransalatedScaledFaceOvalCoordinates.map { CGPoint(x: $0.x, y: $0.y) }
        guard poly.count >= 3, !NormalizedPoints.isEmpty else {
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

            if pointInPolygon(sp, polygon: poly) {
                insideCount += 1
            }
        }

        guard total > 0 else {
            faceisInsideFaceOval = false
            return
        }

        let frac = CGFloat(insideCount) / CGFloat(total)
        faceisInsideFaceOval = (frac >= requiredInsideFraction)
    }

    /// Builds the on-screen oval from NormalizedPoints and updates `faceisInsideFaceOval`.
    func updateTargetFaceOvalCoordinates(
        screenWidth: CGFloat,
        screenHeight: CGFloat,
        leftEyeOuterIdx: Int = 33,
        rightEyeOuterIdx: Int = 263,
        fallbackScale: CGFloat = 235.0
    ) {
        TargetFaceOvalCoordinates.removeAll(keepingCapacity: true)
        TransalatedScaledFaceOvalCoordinates.removeAll(keepingCapacity: true)

        guard !NormalizedPoints.isEmpty else {
            faceisInsideFaceOval = false
            return
        }

        // 1) Grab face-oval points in normalized space
        let normOval: [(x: Float, y: Float)] = faceOvalIndices.compactMap { idx in
            guard idx >= 0, idx < NormalizedPoints.count else { return nil }
            return NormalizedPoints[idx]
        }
        guard !normOval.isEmpty else {
            faceisInsideFaceOval = false
            return
        }

        // 2) Compute IOD in normalized space
        var normIOD: Float = 0
        if NormalizedPoints.count > max(leftEyeOuterIdx, rightEyeOuterIdx) {
            let l = NormalizedPoints[leftEyeOuterIdx]
            let r = NormalizedPoints[rightEyeOuterIdx]
            let dx = r.x - l.x
            let dy = r.y - l.y
            normIOD = sqrt(dx * dx + dy * dy)
        }

        // 3) Convert iodPixels -> iodPx on preview using aspect-fill scale
        let camW = max(imageSize.width, 1e-6)
        let camH = max(imageSize.height, 1e-6)
        let scaleToPreview = max(screenWidth / camW, screenHeight / camH)
        let iodPxOnScreen = CGFloat(iodPixels) * scaleToPreview

        // 4) Final mapping scale
        let scale: CGFloat
        if normIOD > 1e-6, iodPxOnScreen > 0 {
            scale = iodPxOnScreen / CGFloat(normIOD)
        } else {
            scale = fallbackScale
        }

        let cx = screenWidth / 2.0
        let cy = screenHeight / 2.0

        // 5) Build oval polygon in screen space
        TransalatedScaledFaceOvalCoordinates.reserveCapacity(normOval.count)
        for p in normOval {
            TransalatedScaledFaceOvalCoordinates.append(
                (x: cx - CGFloat(p.x) * scale,
                 y: cy - CGFloat(p.y) * scale)
            )
        }
        TargetFaceOvalCoordinates = TransalatedScaledFaceOvalCoordinates

        // 6) ✅ Set boolean if facePoints are inside oval
        // Use 1.0 for strict; use 0.9 if you want jitter-tolerance.
        updateFaceInsideOvalFlag(cx: cx, cy: cy, scale: scale, requiredInsideFraction: 1.0)
        // updateFaceInsideOvalFlag(cx: cx, cy: cy, scale: scale, requiredInsideFraction: 0.9)
    }
}
