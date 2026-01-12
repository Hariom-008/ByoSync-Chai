//
//  dataCollection.swift
//  ML-Testing
//
//  Created by Hari's Mac on 19.11.2025.
//

import Foundation
import Foundation

// MARK: - Data Collection & Management
extension FaceManager {
    
    /// Resets all collected data and tracking states for a new user
    /// Clears calibration data, collected frames, and resets all flags
    func resetForNewUser() {
        capturedFrames.removeAll()
        totalFramesCollected = 0
        
        // Clear calibration data
        actualLeftList.removeAll()
        actualRightList.removeAll()
        rejectedFrames = 0
        
        // Reset tracking states
        isCentreTracking = false
        isMovementTracking = false
        
        // Reset upload states
        uploadSuccess = false
        uploadError = nil
        isUploadingPattern = false
        
        // Reset liveness
        isFaceReal = false

        hasEnteredPhoneNumber = false
        
    }
}

//Reset After Verification Started or Registration Started

extension FaceManager {
    func resetFrameBuffer() {
        DispatchQueue.main.async {
            self.capturedFrames.removeAll(keepingCapacity: true)
            self.totalFramesCollected = 0
            self.rejectedFrames = 0
        }
    }
}
