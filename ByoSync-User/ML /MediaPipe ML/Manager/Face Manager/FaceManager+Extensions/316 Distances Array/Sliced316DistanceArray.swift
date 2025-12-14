//
//  SliceDistanceArray.swift
//  ML-Testing
//

import Foundation

extension FaceManager {
    
    /// Returns up to 80 frames, each with 316 NORMALIZED distances
    /// Skips element 0 (raw reference) and takes elements 1-316
    func save316LengthDistanceArray() -> [[Float]] {
        guard AllFramesOptionalAndMandatoryDistance.count >= 80 else {
            print("⚠️ Not enough frames. Have \(AllFramesOptionalAndMandatoryDistance.count), need at least 80.")
            return []
        }
        
        let first80Frames = Array(AllFramesOptionalAndMandatoryDistance.prefix(80))
        
        // ✅ FIX: Skip element 0 (raw ref), take next 316 normalized elements
        let trimmed = first80Frames.compactMap { frame -> [Float]? in
            guard frame.count >= 317 else {
                print("⚠️ Frame too short: \(frame.count), need at least 317")
                return nil
            }
            // Elements 1-316 (all normalized by reference distance)
            return Array(frame[1...316])
        }
        
        print("📊 [ENROLLMENT] Extracted \(trimmed.count) valid frames (316 normalized distances each)")
        return trimmed
    }
    
    /// Returns up to 10 frames for verification, each with 316 NORMALIZED distances
    /// Skips element 0 (raw reference) and takes elements 1-316
    func VerifyFrameDistanceArray() -> [[Float]] {
        guard AllFramesOptionalAndMandatoryDistance.count >= 10 else {
            print("⚠️ Not enough frames. Have \(AllFramesOptionalAndMandatoryDistance.count), need at least 10.")
            return []
        }
        
        let first10Frames = Array(AllFramesOptionalAndMandatoryDistance.prefix(10))
        
        // ✅ FIX: Skip element 0 (raw ref), take next 316 normalized elements
        let trimmed = first10Frames.compactMap { frame -> [Float]? in
            guard frame.count >= 317 else {
                print("⚠️ Frame too short: \(frame.count), need at least 317")
                return nil
            }
            // Elements 1-316 (all normalized by reference distance)
            return Array(frame[1...316])
        }
        
        print("📊 [VERIFICATION] Extracted \(trimmed.count) valid frames (316 normalized distances each)")
        return trimmed
    }
}
