//
//  FaceManager+TestingLogin.swift
//  ByoSync
//
//  Extension to support testing login flow with custom verification requirements
//

import Foundation

// MARK: - Public Testing API
extension FaceManager {
    
    /// Public wrapper for loading FaceIds and performing verification with custom match requirements
    /// - Parameters:
    ///   - deviceKey: The device key to fetch FaceIds for
    ///   - framesToVerify: Array of frame distance arrays (typically 10 frames)
    ///   - requiredMatches: Number of required matches (default 4 for testing)
    ///   - fetchViewModel: ViewModel to fetch FaceIds
    ///   - completion: Result with verification outcome
    func loadAndVerifyFaceID(
        deviceKeyHash:String,
        framesToVerify: [[Float]],
        requiredMatches: Int = 4,
        fetchViewModel: FaceIdFetchViewModel,
        completion: @escaping (Result<BCHBiometric.VerificationResult, Error>) -> Void
    ) {
        print("🔐 [FaceManager+Testing] Starting loadAndVerify flow...")
        print("   • Frames to verify: \(framesToVerify.count)")
        print("   • Required matches: \(requiredMatches)")
        
        // IMPORTANT: This must call the wrapper method you add to Enrollment.swift
        // The method will populate RemoteFaceIdCache which is needed for verification
        loadRemoteFaceIdsForVerification(deviceKeyHash:deviceKeyHash,fetchViewModel: fetchViewModel) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success:
                print("✅ [FaceManager+Testing] FaceIds loaded into cache, starting verification...")
                
                // Step 2: Verify with custom match requirement
                self.verifyFaceIDWithCustomMatches(
                    framesToUse: framesToVerify,
                    requiredMatches: requiredMatches,
                    completion: completion
                )
                
            case .failure(let error):
                print("❌ [FaceManager+Testing] Failed to load FaceIds: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    /// Verify face with custom required matches (testing version)
    /// - Parameters:
    ///   - framesToUse: Array of frame distance arrays
    ///   - requiredMatches: Number of matches required (e.g., 4 out of 10)
    ///   - completion: Result with verification outcome
    func verifyFaceIDWithCustomMatches(
        framesToUse: [[Float]],
        requiredMatches: Int,
        completion: @escaping (Result<BCHBiometric.VerificationResult, Error>) -> Void
    ) {
        // NOTE: This is a duplicate of verifyFaceIDAgainstBackend but with configurable requiredMatches
        // We need to access RemoteFaceIdCache which is private in Enrollment.swift
        
        // For now, we'll call the original verification and adjust the result
        // The original requires 5 matches, but we want 4
        
        verifyFaceIDAgainstBackend(framesToUse: framesToUse) { result in
            switch result {
            case .success(var verificationResult):
                // Extract matched frames count from notes
                // Format: "Token-only verification: matchedFrames=X/Y, required=5, storedRecords=Z"
                if let notes = verificationResult.notes,
                   let matchedRange = notes.range(of: "matchedFrames=") {
                    let afterMatched = matchedRange.upperBound
                    let remainder = notes[afterMatched...]
                    if let slashRange = remainder.firstIndex(of: "/") {
                        let matchedStr = String(remainder[..<slashRange])
                        if let matchedCount = Int(matchedStr) {
                            print("📊 [FaceManager+Testing] Matched frames: \(matchedCount)/\(framesToUse.count)")

                            // Override success based on custom requirement
                            let customSuccess = matchedCount >= requiredMatches

                            if customSuccess != verificationResult.success {
                                print("🔄 [FaceManager+Testing] Adjusting result: \(verificationResult.success) → \(customSuccess)")

                                // Create adjusted result
                                let adjustedResult = BCHBiometric.VerificationResult(
                                    success: customSuccess,
                                    matchPercentage: verificationResult.matchPercentage,
                                    registrationIndex: verificationResult.registrationIndex,
                                    hashMatch: customSuccess,
                                    storedHashPreview: verificationResult.storedHashPreview,
                                    recoveredHashPreview: verificationResult.recoveredHashPreview,
                                    numErrorsDetected: verificationResult.numErrorsDetected,
                                    totalBitsCompared: verificationResult.totalBitsCompared,
                                    notes: "Testing verification: matchedFrames=\(matchedCount)/\(framesToUse.count), required=\(requiredMatches) (custom)"
                                )

                                completion(.success(adjustedResult))
                                return
                            }
                        }
                    }
                }

                // If we couldn't parse or no adjustment needed, return original
                completion(.success(verificationResult))
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}

