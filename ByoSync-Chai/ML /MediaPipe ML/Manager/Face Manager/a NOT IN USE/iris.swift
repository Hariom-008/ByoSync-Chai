//
//  iris.swift
//  ByoSync-User
//
//  Created by Hari's Mac on 31.12.2025.
//

//import Foundation

// MARK: - Face Bounding Box & Iris Distance

/// Calculates face bounding box and iris distance ratio for liveness detection
/// Also calculates and publishes the target iris size for UI overlay
//    func calculateFaceBoundingBox() {
//        // Need intrinsics and enough landmarks
//        guard let fx = cameraSpecManager.currentSpecs?.intrinsicMatrix?.columns.0.x,
//              CalculationCoordinates.count > 477,
//              !CameraFeedCoordinates.isEmpty else {
//            irisDistanceRatio = nil
//            faceBoundingBox = nil
//            return
//        }
//
//        // Constants for iris distance calculation
//        let dIrisMm: Float = 11.5      // Average iris diameter in mm
//        let LTargetMm: Float = 305.0   // Target distance in mm
//
//        // ✅ Calculate and store iris_target_px for UI overlay
//        let irisTarget_px = fx * (dIrisMm / LTargetMm)
//        self.irisTargetPx = irisTarget_px
//
//        // Iris landmark indices
//        let leftIdxA = 476
//        let leftIdxB = 474
//        let rightIdxA = 471
//        let rightIdxB = 469
//
//        // Validate indices
//        guard leftIdxA < CalculationCoordinates.count,
//              leftIdxB < CalculationCoordinates.count,
//              rightIdxA < CalculationCoordinates.count,
//              rightIdxB < CalculationCoordinates.count else {
//            irisDistanceRatio = nil
//            faceBoundingBox = nil
//            return
//        }
//
//        // Calculate iris diameters
//        let diameterLeft_px  = Helper.shared.calculateDistance(
//            CalculationCoordinates[leftIdxA],
//            CalculationCoordinates[leftIdxB]
//        )
//        let diameterRight_px = Helper.shared.calculateDistance(
//            CalculationCoordinates[rightIdxA],
//            CalculationCoordinates[rightIdxB]
//        )
//
//        let d_mean_px: Float = (diameterLeft_px + diameterRight_px) / 2.0
//        self.dMeanPx = d_mean_px
//        guard irisTargetPx > 0 else {
//            irisDistanceRatio = nil
//            faceBoundingBox = nil
//            return
//        }
//
//        // Calculate and publish ratio
//        let ratio = d_mean_px / irisTargetPx
//        irisDistanceRatio = ratio
//
//        // ✅ Updated acceptance range to 0.95 - 1.05
//        if ratio >= 0.95 && ratio <= 1.05 {
//            self.ratioIsInRange = true
//            print("✅ ACCEPT (ratio = \(ratio))")
//        } else {
//            self.ratioIsInRange = false
//            //  print("❌ REJECT (ratio = \(ratio))")
//        }
//
//        // Calculate face bounding box using face oval landmarks
//        var minX = Float.greatestFiniteMagnitude
//        var minY = Float.greatestFiniteMagnitude
//        var maxX = -Float.greatestFiniteMagnitude
//        var maxY = -Float.greatestFiniteMagnitude
//
//        for idx in faceOvalIndices {
//            guard idx >= 0, idx < CameraFeedCoordinates.count else { continue }
//            let p = CameraFeedCoordinates[idx]
//            minX = min(minX, p.x)
//            minY = min(minY, p.y)
//            maxX = max(maxX, p.x)
//            maxY = max(maxY, p.y)
//        }
//
//        if minX < maxX, minY < maxY {
//            faceBoundingBox = CGRect(
//                x: CGFloat(minX),
//                y: CGFloat(minY),
//                width: CGFloat(maxX - minX),
//                height: CGFloat(maxY - minY)
//            )
//        } else {
//            faceBoundingBox = nil
//        }
//    }
//
//    func calculateTargetOvalDimensions() -> (width: Float, height: Float)? {
//        guard let fx = cameraSpecManager.currentSpecs?.intrinsicMatrix?.columns.0.x else {
//            return nil
//        }
//
//        let dIrisMm: Float = 11.5
//        let LTargetMm: Float = 305.0
//        // Iris_Weight_Px = irisTarget_px && currentiris_width = d_mean_px
//        let irisTarget_px = fx * (dIrisMm / LTargetMm)
//
//        // ML team's formula
//        let ovalWidth_px  = 9.0 * irisTarget_px
//        let ovalHeight_px = 11.0 * irisTarget_px
//
//        return (width: ovalWidth_px, height: ovalHeight_px)
//    }
