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

    /// 1) Normalize by RMS scale (divide by `scale`)
    /// 2) Fix roll using eye line (33 -> 263) by rotating all normalized points by -roll
    /// 3) Print rollRaw / rollUsed / rollAfter (throttled)
    func calculateNormalizedPoints() {
        let eps: Float = 1e-6
        guard !Translated.isEmpty, scale > eps else {
            NormalizedPoints = []
            return
        }

        // If we don't have enough landmarks for 33 and 263, just normalize
        guard Translated.count > 263 else {
            var normalized = Array(repeating: (x: Float(0), y: Float(0)), count: Translated.count)
            for i in 0..<Translated.count {
                let p = Translated[i]
                normalized[i] = (x: p.x / scale, y: p.y / scale)
            }
            NormalizedPoints = normalized
            return
        }

        // 1) Normalize (single allocation + loop for perf)
        var normalized = Array(repeating: (x: Float(0), y: Float(0)), count: Translated.count)
        for i in 0..<Translated.count {
            let p = Translated[i]
            normalized[i] = (x: p.x / scale, y: p.y / scale)
        }

        // 2) Compute roll from eye-line vector in normalized space
        let p33 = normalized[33]
        let p263 = normalized[263]
        let vx = p263.x - p33.x
        let vy = p263.y - p33.y

        let rollRaw = atan2f(vy, vx) // [-pi, pi]

        // Wrap roll so we pick the *smallest* rotation that levels the eye line.
        // This avoids the ~pi case when the eye vector points left (vx < 0).
        var roll = rollRaw
        let halfPi: Float = .pi / 2
        if roll > halfPi { roll -= .pi }
        if roll < -halfPi { roll += .pi }

        // Rotate by -roll to "unroll"
        let angle = -roll
        let c = cosf(angle)
        let s = sinf(angle)

        for i in 0..<normalized.count {
            let x = normalized[i].x
            let y = normalized[i].y
            normalized[i] = (x: x * c - y * s,
                             y: x * s + y * c)
        }

        NormalizedPoints = normalized

        // 3) Debug: recompute roll AFTER rotation (should be near 0)
        let p33r = normalized[33]
        let p263r = normalized[263]
        let vx2 = p263r.x - p33r.x
        let vy2 = p263r.y - p33r.y
        let rollAfter = atan2f(vy2, vx2)

        // Throttle prints to reduce frame drops (pipeline runs on main thread)
        rollPrintTick &+= 1
        if (rollPrintTick % 15) == 0 {
            let toDeg: Float = 57.2957795
            print(String(format: "rollRaw=%.4f rad (%.1f°), rollUsed=%.4f rad (%.1f°), rollAfter=%.4f rad (%.1f°)",
                         rollRaw, rollRaw * toDeg,
                         roll,    roll    * toDeg,
                         rollAfter, rollAfter * toDeg))
        }
    }
}
