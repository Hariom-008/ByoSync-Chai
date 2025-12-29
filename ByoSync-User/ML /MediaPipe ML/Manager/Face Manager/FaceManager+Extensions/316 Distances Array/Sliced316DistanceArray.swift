import Foundation

extension FaceManager {
    
    /// Returns last 80 frames, each with exactly 316 distances
    func save316LengthDistanceArray() -> [[Float]] {
        guard AllFramesOptionalAndMandatoryDistance.count >= 80 else {
            print("⚠️ Not enough frames. Have \(AllFramesOptionalAndMandatoryDistance.count), need at least 80.")
            return []
        }

        let last80Frames = AllFramesOptionalAndMandatoryDistance.suffix(80)

        let trimmed = last80Frames.compactMap { frame -> [Float]? in
            guard frame.count >= 316 else {
                print("⚠️ Frame too short: \(frame.count), need at least 316")
                return nil
            }
            return Array(frame[0..<316])
        }
        return trimmed
    }

    /// Returns last 10 frames, each with exactly 316 distances
    func VerifyFrameDistanceArray() -> [[Float]] {
        guard AllFramesOptionalAndMandatoryDistance.count >= 10 else {
            print("⚠️ Not enough frames. Have \(AllFramesOptionalAndMandatoryDistance.count), need at least 10.")
            return []
        }

        let last10Frames = AllFramesOptionalAndMandatoryDistance.suffix(10)

        let trimmed = last10Frames.compactMap { frame -> [Float]? in
            guard frame.count >= 316 else {
                print("⚠️ Frame too short: \(frame.count), need at least 316")
                return nil
            }
            return Array(frame[0..<316])
        }

        print("📊 [VERIFICATION] Extracted \(trimmed.count) valid frames (316 distances each)")
        return trimmed
    }
}
