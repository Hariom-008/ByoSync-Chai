//
//  geometry.swift
//  ML-Testing
//
//  Created by Hari's Mac on 19.11.2025.
//

import Foundation
import Foundation

// MARK: - Geometric Calculations
extension FaceManager {
    
    /// Calculates the centroid (center point) of the face using face oval landmarks
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
    
    /// Translates all landmarks to be centered around the centroid
    func calculateTranslated() {
        guard let c = centroid else {
            Translated = []
            return
        }
        
        // Subtract centroid from each point
        Translated = CalculationCoordinates.map { p in
            (x: p.x - c.x, y: p.y - c.y)
        }
    }
    
    /// Calculates squared distances for each translated point (for RMS calculation)
    func calculateTranslatedSquareDistance() {
        guard !Translated.isEmpty else {
            TranslatedSquareDistance = []
            return
        }
        
        // Calculate x² + y² for each translated point
        TranslatedSquareDistance = Translated.map { p in
            p.x * p.x + p.y * p.y
        }
    }
    
    /// Calculates Root Mean Square (RMS) of translated points to determine scale
    func calculateRMSOfTransalted() {
        let n = TranslatedSquareDistance.count
        guard n > 0 else {
            scale = 0
            return
        }
        
        // Calculate mean and then RMS
        let sum = TranslatedSquareDistance.reduce(0 as Float, +)
        let mean = sum / Float(n)
        scale = sqrt(max(0, mean))  // max guards against tiny negative from FP error
    }
    
    /// Normalizes all points by dividing by the scale factor
//    func calculateNormalizedPoints() {
//        let eps: Float = 1e-6
//        guard !Translated.isEmpty, scale > eps else {
//            NormalizedPoints = []
//            return
//        }
//        
//        // Divide each translated point by scale
//        NormalizedPoints = Translated.map { p in
//            (x: p.x / scale, y: p.y / scale)
//        }
//    }
}

extension FaceManager {

    func calculateNormalizedPoints() {
        let eps: Float = 1e-6
        guard !Translated.isEmpty, scale > eps else {
            NormalizedPoints = []
            return
        }

        // 1) Normalize
        var normalized = Array(repeating: (x: Float(0), y: Float(0)), count: Translated.count)
        for i in 0..<Translated.count {
            let p = Translated[i]
            normalized[i] = (x: p.x / scale, y: p.y / scale)
        }

        // If we don't have enough landmarks for 33 and 263, stop here
        guard normalized.count > 263 else {
            NormalizedPoints = normalized
            return
        }

        let p33 = normalized[33]
        let p263 = normalized[263]
        let vx = p263.x - p33.x
        let vy = p263.y - p33.y

        // Degenerate case: eye line too small (bad frame / face tiny)
        let v2 = vx * vx + vy * vy
        guard v2 > (eps * eps) else {
            NormalizedPoints = normalized
            return
        }

        // Roll of the eye-line
        let rollRaw = atan2f(vy, vx) // [-pi, pi]

        // Treat the eye-line as an *undirected* line => period is pi, not 2pi.
        // Map to [-pi/2, +pi/2] so we never do a near-180° flip.
        let halfPi: Float = .pi / 2
        var rollLine = rollRaw
        if rollLine > halfPi { rollLine -= .pi }
        if rollLine < -halfPi { rollLine += .pi }

        // Rotate around pivot = midpoint between eyes (recommended)
        let pivot = (x: (p33.x + p263.x) * 0.5, y: (p33.y + p263.y) * 0.5)

        @inline(__always)
        func rotate(points: inout [(x: Float, y: Float)], angle: Float) {
            let c = cosf(angle)
            let s = sinf(angle)
            for i in 0..<points.count {
                let px = points[i].x - pivot.x
                let py = points[i].y - pivot.y
                points[i] = (
                    x: px * c - py * s + pivot.x,
                    y: px * s + py * c + pivot.y
                )
            }
        }

        @inline(__always)
        func rollAfter(_ pts: [(x: Float, y: Float)]) -> Float {
            let a = pts[33], b = pts[263]
            return atan2f(b.y - a.y, b.x - a.x)
        }

        // 2) Robustly pick sign: try both and choose the one that levels best.
        // This handles y-down vs y-up and mirrored pipelines.
        var candA = normalized
        var candB = normalized

        rotate(points: &candA, angle: -rollLine)
        rotate(points: &candB, angle: +rollLine)

        let afterA = rollAfter(candA)
        let afterB = rollAfter(candB)

        let useA = abs(afterA) <= abs(afterB)
        normalized = useA ? candA : candB

        NormalizedPoints = normalized

        // 3) Debug (throttled)
        rollPrintTick &+= 1
        if (rollPrintTick % 15) == 0 {
            let toDeg: Float = 57.2957795
            let usedAngle = useA ? (-rollLine) : (+rollLine)
            let after = useA ? afterA : afterB
            print(String(format: "rollRaw=%.4f (%.1f°), rollLine=%.4f (%.1f°), angleUsed=%.4f (%.1f°), rollAfter=%.4f (%.1f°)",
                         rollRaw, rollRaw * toDeg,
                         rollLine, rollLine * toDeg,
                         usedAngle, usedAngle * toDeg,
                         after, after * toDeg))
        }
    }
}
