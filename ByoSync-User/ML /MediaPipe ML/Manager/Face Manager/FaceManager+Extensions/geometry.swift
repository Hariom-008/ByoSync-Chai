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

        // 1) Normalize (centroid already moved to origin in calculateTranslated)
        var normalized = Translated.map { p in (x: p.x / scale, y: p.y / scale) }

        guard normalized.count > 263 else {
            NormalizedPoints = normalized
            return
        }

        let p33  = normalized[33]
        let p263 = normalized[263]

        // Match Android direction: v = p33 - p263
        let vx = p33.x - p263.x
        let vy = p33.y - p263.y
        let v2 = vx * vx + vy * vy
        guard v2 > eps * eps else {
            NormalizedPoints = normalized
            return
        }

        let roll = atan2f(vy, vx) // [-pi, pi]
        let c = cosf(roll)
        let s = sinf(roll)

        @inline(__always)
        func rotateMinusRoll(_ pts: inout [(x: Float, y: Float)]) {
            // Android matrix: rotate by -roll around origin
            for i in pts.indices {
                let x = pts[i].x
                let y = pts[i].y
                pts[i] = (x: x * c + y * s,
                          y: -x * s + y * c)
            }
        }

        @inline(__always)
        func rotatePlusRoll(_ pts: inout [(x: Float, y: Float)]) {
            // rotate by +roll around origin
            for i in pts.indices {
                let x = pts[i].x
                let y = pts[i].y
                pts[i] = (x: x * c - y * s,
                          y: x * s + y * c)
            }
        }

        // If your coordinate conventions are consistent, this is enough:
        // rotateMinusRoll(&normalized)

        // If you want robustness across flips/mirroring, choose the one that makes the eye-line most horizontal (mod pi)
        var candA = normalized
        var candB = normalized
        rotateMinusRoll(&candA)
        rotatePlusRoll(&candB)

        func horizResidual(_ pts: [(x: Float, y: Float)]) -> Float {
            let a = pts[33], b = pts[263]
            let ang = atan2f(b.y - a.y, b.x - a.x)
            return abs(sinf(ang)) // 0 when angle is 0 or pi
        }

        normalized = (horizResidual(candA) <= horizResidual(candB)) ? candA : candB
        NormalizedPoints = normalized
    }
}
