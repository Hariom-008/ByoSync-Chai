import Foundation
import CoreGraphics

extension FaceManager {
    
    /// Builds the on-screen oval from **NormalizedPoints** (Android-style).
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
                (x: cx + CGFloat(p.x) * scale,
                 y: cy - CGFloat(p.y) * scale)   // ✅ invert Y for screen space
            )
        }

        // Keeping this for compatibility/debugging (same points, same meaning now)
        TargetFaceOvalCoordinates = TransalatedScaledFaceOvalCoordinates
    }
}
