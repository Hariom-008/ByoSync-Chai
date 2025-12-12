//
//  Enrollment.swift
//  ML-Testing
//
//  Updated for BCH Fuzzy Extractor (helper + secretHash)
//
import Foundation
import Alamofire
import CryptoKit
import Security

struct EnrollmentRecord: Codable {
    let index: Int
    let helper: String          // codeword ⊕ biometricBits (as "0/1" string)
    let secretHash: String      // R = SHA256(secretKeyBitsString) hex

    let salt: String            // 256-bit hex, per enrollment (same across 80 frames)
    let k2: String              // 256-bit hex, per frame
    let token: String           // SHA256(K || R) hex, per frame

    let timestamp: Date
}

struct EnrollmentStore: Codable {
    let savedAt: String
    let enrollments: [EnrollmentRecord]
}
// MARK: - Remote FaceId cache (for backend verification)

fileprivate struct RemoteEnrollmentRecord {
    let helper: String
    //let secretHash: String  // R = SHA256(secretKeyBitsString)
    let salt: String        // same for all 80 records for this user
    let k2: String          // per-frame
    let token: String       // SHA256(K || R)
    let timestamp: Date
}

fileprivate enum RemoteEnrollmentCache {
    static var salt: String?
    static var records: [RemoteEnrollmentRecord] = []
    
    static var isEmpty: Bool {
        return salt == nil || records.isEmpty
    }
    
    static func reset() {
        salt = nil
        records = []
    }
}
// MARK: - Remote FaceId cache (for backend verification)

fileprivate struct RemoteFaceIdCache {
    static var salt: String?
    static var faceIds: [FaceId] = []
    
    static var isEmpty: Bool {
        return salt == nil || faceIds.isEmpty
    }
    
    static func reset() {
        salt = nil
        faceIds = []
    }
}

fileprivate func loadRemoteFaceIdsIfNeeded(
    deviceKey: String,
    fetchViewModel: FaceIdFetchViewModel,
    completion: @escaping (Result<Void, Error>) -> Void
) {
    // If we already have salt + records, just reuse them
    if !RemoteFaceIdCache.isEmpty {
        print("💾 [RemoteFaceIdCache] Using cached FaceId data (salt + \(RemoteFaceIdCache.faceIds.count) records).")
        completion(.success(()))
        return
    }
    
    print("🌐 [RemoteFaceIdCache] Cache empty → fetching FaceIds from backend...")
    
    fetchViewModel.fetchFaceIds(for: deviceKey) { (result: Result<GetFaceIdData, Error>) in
        switch result {
        case .failure(let error):
            print("❌ [RemoteFaceIdCache] Failed to fetch FaceIds: \(error)")
            completion(.failure(error))
            
        case .success(let data):
            let saltHex = data.salt
            let faceIds = data.faceData
            
            print("✅ [RemoteFaceIdCache] Fetched \(faceIds.count) FaceId items from backend")
            print("🔑 [RemoteFaceIdCache] SALT from backend: \(saltHex) (len=\(saltHex.count))")
            
            guard !faceIds.isEmpty else {
                print("❌ [RemoteFaceIdCache] faceData is empty")
                completion(.failure(LocalEnrollmentError.noLocalEnrollment))
                return
            }
            
            RemoteFaceIdCache.salt = saltHex
            RemoteFaceIdCache.faceIds = faceIds
            
            print("💾 [RemoteFaceIdCache] Cache filled (records=\(faceIds.count))")
            completion(.success(()))
        }
    }
}

// MARK: - Shared BCH instance (stateful: caches init/config)
private let BCHShared = BCHBiometric()

// MARK: - Crypto helpers for SALT / K / K1 / K2 / TOKEN

private func dataFromHex(_ hex: String) -> Data? {
    let len = hex.count
    guard len % 2 == 0 else { return nil }

    var data = Data(capacity: len / 2)
    var index = hex.startIndex

    for _ in 0..<(len / 2) {
        let nextIndex = hex.index(index, offsetBy: 2)
        let byteString = hex[index..<nextIndex]
        guard let byte = UInt8(byteString, radix: 16) else {
            return nil
        }
        data.append(byte)
        index = nextIndex
    }
    return data
}

private func hexFromData(_ data: Data) -> String {
    data.map { String(format: "%02x", $0) }.joined()
}

/// XOR two hex strings of equal length; returns nil if lengths or parsing fail.
private func xorHex(_ h1: String, _ h2: String) -> String? {
    guard h1.count == h2.count else {
        print("❌ xorHex length mismatch: h1=\(h1.count), h2=\(h2.count)")
        return nil
    }

    guard
        let d1 = dataFromHex(h1),
        let d2 = dataFromHex(h2),
        d1.count == d2.count
    else {
        print("❌ xorHex invalid hex or byte-length mismatch")
        return nil
    }

    var out = Data(count: d1.count)
    for i in 0..<d1.count {
        out[i] = d1[i] ^ d2[i]
    }
    return hexFromData(out)
}

/// Random N bytes -> hex (default 32 bytes = 256-bit)
private func randomHex(bytes: Int = 32) -> String {
    var data = Data(count: bytes)
    let result = data.withUnsafeMutableBytes { buf in
        SecRandomCopyBytes(kSecRandomDefault, bytes, buf.baseAddress!)
    }
    if result != errSecSuccess {
        fatalError("❌ Failed to generate secure random bytes")
    }
    return hexFromData(data)
}

/// SHA256 over UTF-8 string -> hex
private func sha256Hex(_ input: String) -> String {
    let data = Data(input.utf8)
    let digest = SHA256.hash(data: data)
    return digest.map { String(format: "%02x", $0) }.joined()
}

// MARK: - Enrollment Extension
extension FaceManager {

    /// Generate all 80 enrollment records and upload them in ONE API call.
    func generateAndUploadFaceID(
        authToken: String,
        viewModel: FaceIdViewModel,
        completion: ((Result<Void, Error>) -> Void)? = nil
    ) {

        // Capture 80 frames
        let trimmedFrames = save316LengthDistanceArray()

        guard trimmedFrames.count == 80 else {
            print("❌ Expected 80 frames, got \(trimmedFrames.count)")
            DispatchQueue.main.async {
                completion?(.failure(BCHBiometricError.noDistanceArrays))
            }
            return
        }

        print("\n🔐 ========== ENROLLMENT + UPLOAD STARTED ==========")
        print("📊 Frames: \(trimmedFrames.count)")

        // Generate 256-bit SALT for all frames
        let saltHex = randomHex(bytes: 32)
        print("🔑 SALT (256-bit): \(saltHex)")

        var addFaceIdPayload: [AddFaceIdRequestBody] = []
        var successCount = 0
        var failureCount = 0

        for (index, distances) in trimmedFrames.enumerated() {
            do {
                try BCHShared.initBCH()

                let distancesDouble = distances.map { Double($0) }

                // Registration → helper + secretHash (R)
                let reg = try BCHShared.registerBiometric(
                    distances: nil,
                    single: distancesDouble
                )

                let helper = reg.helper
                let secretHash = reg.secretHash   // R

                // K1 = R XOR SALT
                guard let k1 = xorHex(secretHash, saltHex) else {
                    print("❌ K1 failed for frame \(index+1)")
                    failureCount += 1
                    continue
                }

                // Per-frame 256-bit key
                let kHex = randomHex(bytes: 32)

                // K2 = K1 XOR K
                guard let k2Hex = xorHex(k1, kHex) else {
                    print("❌ K2 failed for frame \(index+1)")
                    failureCount += 1
                    continue
                }

                // TOKEN = SHA256(K || R)
                let tokenHex = sha256Hex(kHex + secretHash)

                // Debug logs
                print("🔹 Frame #\(index+1) CRYPTO DEBUG")
                print("   helper length = \(helper.count)")
                print("   R = \(secretHash)")
                print("   SALT = \(saltHex)")
                print("   K1 = \(k1)")
                print("   K  = \(kHex)")
                print("   K2 = \(k2Hex)")
                print("   TOKEN = \(tokenHex)")

                // Build backend payload object
                let payloadObject = AddFaceIdRequestBody(
                    helper: helper,
                    k2: k2Hex,
                    token: tokenHex
                )

                addFaceIdPayload.append(payloadObject)
                successCount += 1

            } catch {
                failureCount += 1
                print("❌ Frame \(index+1) failed: \(error)")
            }
        }

        print("\n📊 ENROLLMENT SUMMARY")
        print("   ✅ Success: \(successCount)/80")
        print("   ❌ Failure: \(failureCount)/80")

        guard addFaceIdPayload.count == 80 else {
            print("❌ Enrollment failed — only \(addFaceIdPayload.count)/80 generated")
            DispatchQueue.main.async {
                completion?(.failure(LocalEnrollmentError.noLocalEnrollment))
            }
            return
        }

        print("📤 Uploading all 80 records in ONE API call…")

        // 🚀 Upload all 80 in a single call
        viewModel.uploadFaceIdList(
            salt: saltHex,
            list: addFaceIdPayload
        )

        print("🎉 ENROLLMENT COMPLETE — UPLOAD TRIGGERED\n")

        DispatchQueue.main.async {
            completion?(.success(()))
        }
    }
}


extension FaceManager {
    
    /// Heavy token-only verification loop using cached SALT + [FaceId].
    /// This uses the "R' XOR SALT → K1' → K' → token'" logic against stored (k2, token).
    fileprivate func performBackendTokenVerificationTokenOnly(
        framesToUse: [[Float]],
        totalRawFrames: Int,
        totalValidFrames: Int,
        invalidIndices: [Int],
        completion: @escaping (Result<BCHBiometric.VerificationResult, Error>) -> Void
    ) {
        guard
            let saltHex = RemoteFaceIdCache.salt,
            !RemoteFaceIdCache.faceIds.isEmpty
        else {
            print("❌ [BackendVerify] Remote cache missing salt or records.")
            DispatchQueue.main.async {
                completion(.failure(LocalEnrollmentError.noLocalEnrollment))
            }
            return
        }
        
        let faceIds = RemoteFaceIdCache.faceIds
        
        print("✅ [BackendVerify] Using cached SALT + \(faceIds.count) FaceId records.")
        if faceIds.count != 80 {
            print("⚠️ [BackendVerify] Expected 80 remote records, got \(faceIds.count). Proceeding anyway.")
        }
        
        print("\n🔄 Starting TOKEN-ONLY frame-by-frame verification with REMOTE records (cached)...")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
        
        DispatchQueue.global(qos: .userInitiated).async {
            
            var matchedFramesCount = 0
            var unmatchedFramesCount = 0
            var detailedFrameMatches: [(capturedIndex: Int, matched: Bool, matchedStoredIndex: Int?)] = []
            let requiredMatches = 5
            
            frameLoop: for (capturedIndex, capturedFrame) in framesToUse.enumerated() {
                let capturedDistances = capturedFrame.map { Double($0) }
                
                var frameMatched = false
                var matchedStoredIndex: Int? = nil
                
                print("📸 Checking Captured Frame #\(capturedIndex + 1) against \(faceIds.count) stored tokens...")
                
                do {
                    // BCH init for this frame, used to derive R' (secretHash')
                    try BCHShared.initBCH()
                    
                    let reg = try BCHShared.registerBiometric(
                        distances: nil,
                        single: capturedDistances
                    )
                    let Rprime = reg.secretHash   // R' for this captured frame
                    
                    // K1' = R' XOR SALT
                    guard let k1Prime = xorHex(Rprime, saltHex) else {
                        print("   ⚠️ Failed to compute K1' for Captured Frame #\(capturedIndex + 1)")
                        print("      R' len=\(Rprime.count), SALT len=\(saltHex.count)")
                        unmatchedFramesCount += 1
                        detailedFrameMatches.append((capturedIndex, false, nil))
                        print("----------------------------------------------------\n")
                        continue
                    }
                    
                    // Compare against all stored K2/TOKEN pairs
                    for (storedIndex, record) in faceIds.enumerated() {
                        // K' = K1' XOR K2(stored)
                        guard let kRecovered = xorHex(k1Prime, record.k2) else {
                            print("   ⚠️ Failed to recover K' for stored frame #\(storedIndex + 1)")
                            continue
                        }
                        
                        // token' = SHA256(K' || R')
                        let tokenCandidate = sha256Hex(kRecovered + Rprime)
                        
                        if tokenCandidate == record.token {
                            frameMatched = true
                            matchedStoredIndex = storedIndex
                            
                            print("   ✅ TOKEN MATCH for Captured Frame #\(capturedIndex + 1)")
                            print("      └─ Matched Stored Frame #\(storedIndex + 1)")
                            break
                        }
                    }
                    
                } catch {
                    print("   ⚠️ BCH registerBiometric error for Captured Frame #\(capturedIndex + 1): \(error)")
                }
                
                if frameMatched {
                    matchedFramesCount += 1
                    detailedFrameMatches.append((capturedIndex, true, matchedStoredIndex))
                    
                    if let idx = matchedStoredIndex {
                        print("✅ RESULT for Captured Frame #\(capturedIndex + 1): MATCHED via token (Stored Frame #\(idx + 1))")
                    } else {
                        print("✅ RESULT for Captured Frame #\(capturedIndex + 1): MATCHED via token (Stored index: unknown)")
                    }
                } else {
                    unmatchedFramesCount += 1
                    detailedFrameMatches.append((capturedIndex, false, nil))
                    
                    print("❌ RESULT for Captured Frame #\(capturedIndex + 1): NO TOKEN MATCH among stored frames")
                }
                
                print("----------------------------------------------------\n")
                
                if matchedFramesCount >= requiredMatches {
                    print("✅ Early exit: already have required matched frames (\(matchedFramesCount)/\(requiredMatches)).")
                    break frameLoop
                }
            }
            
            let totalUsedFrames = detailedFrameMatches.count
            let matchPercentageAcrossFrames: Double =
                totalUsedFrames > 0
                ? (Double(matchedFramesCount) / Double(totalUsedFrames)) * 100.0
                : 0.0
            
            let verificationPassed = matchedFramesCount >= requiredMatches
            
            print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("📊 VERIFICATION SUMMARY (TOKEN-ONLY, BACKEND+CACHE):")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("  Raw Frames Captured: \(totalRawFrames)")
            print("  Valid Frames (distance count OK): \(totalValidFrames)")
            print("  Invalid Frames (distance count mismatch): \(invalidIndices.count)")
            print("  Frames Evaluated for Token Check: \(totalUsedFrames)")
            print("  ✅ Frames with ≥1 TOKEN MATCH: \(matchedFramesCount)/\(totalUsedFrames)")
            print("  ❌ Frames with NO TOKEN MATCH: \(unmatchedFramesCount)/\(totalUsedFrames)")
            print("  📏 Required Matched Frames (token): ≥\(requiredMatches)")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            if verificationPassed {
                print("  🎉 RESULT: ✅ VERIFICATION PASSED (TOKEN-ONLY, BACKEND+CACHE)")
            } else {
                print("  ⛔ RESULT: ❌ VERIFICATION FAILED (TOKEN-ONLY, BACKEND+CACHE)")
            }
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
            
            print("📈 FRAME-BY-FRAME TOKEN MATCH DETAILS:")
            for info in detailedFrameMatches {
                let frameNumber = info.capturedIndex + 1
                if info.matched, let idx = info.matchedStoredIndex {
                    print("  • Captured Frame #\(frameNumber): ✅ MATCHED (Stored Frame #\(idx + 1))")
                } else {
                    print("  • Captured Frame #\(frameNumber): ❌ NO TOKEN MATCH")
                }
            }
            
            print("\n🔍 ========== VERIFICATION (TOKEN-ONLY, BACKEND+CACHE) COMPLETED ==========\n")
            
            let aggregated = BCHBiometric.VerificationResult(
                success: verificationPassed,
                matchPercentage: matchPercentageAcrossFrames,
                registrationIndex: 0,
                hashMatch: verificationPassed,
                storedHashPreview: "",
                recoveredHashPreview: "",
                numErrorsDetected: 0,
                totalBitsCompared: 0,
                notes: "Backend token-only verification over \(totalUsedFrames) frames " +
                       "using cached \(faceIds.count) records; " +
                       "frames with ≥1 token match: \(matchedFramesCount); " +
                       "required ≥\(requiredMatches)."
            )
            
            DispatchQueue.main.async {
                completion(.success(aggregated))
            }
        }
    }
}

// MARK: - Verification Extension (BACKEND with cache)
extension FaceManager {
    
    /// Forward declaration note: This method uses `loadRemoteFaceIdsIfNeeded` defined above.
    ///
    /// Token-only verification using records fetched from BACKEND:
    /// - Capture ~10 frames
    /// - Ensure remote cache is filled (salt + [FaceId]) via API if needed
    /// - Use current secretHash (R') of each captured frame with SALT + K2/token from backend
    ///   to try to match tokens.
    ///
    /// NOTE: With the current crypto design (no secretHash returned for stored frames),
    ///       this scheme only matches when secretHash for a login frame equals the
    ///       secretHash used for an enrollment frame.
    func verifyFaceIDAgainstBackend(
        deviceKey: String,
        fetchViewModel: FaceIdFetchViewModel,
        completion: @escaping (Result<BCHBiometric.VerificationResult, Error>) -> Void
    ) {
        print("\n🔍 ========== VERIFICATION (TOKEN-ONLY, BACKEND+CACHE) STARTED ==========")
        
        // 1️⃣ Capture frames
        let trimmedFrames = VerifyFrameDistanceArray()
        print("📊 Captured \(trimmedFrames.count) frames total (raw)")
        
        // 2️⃣ Filter valid frames by distance count
        var validFrames: [[Float]] = []
        var invalidFrameIndices: [Int] = []
        
        for (index, frame) in trimmedFrames.enumerated() {
            if frame.count == BCHBiometric.NUM_DISTANCES {
                validFrames.append(frame)
            } else {
                invalidFrameIndices.append(index)
                print("⚠️ Frame #\(index + 1) has \(frame.count) distances (expected \(BCHBiometric.NUM_DISTANCES)) - SKIPPED")
            }
        }
        
        print("✅ Valid frames (distance count OK): \(validFrames.count)")
        print("❌ Invalid frames (distance count mismatch): \(invalidFrameIndices.count)")
        
        let requiredCollectedFrames = 10
        
        guard validFrames.count >= requiredCollectedFrames else {
            print("❌ Insufficient valid frames for token-only verification.")
            print("   Got \(validFrames.count), but need at least \(requiredCollectedFrames) valid frames.")
            
            DispatchQueue.main.async {
                completion(.failure(
                    BCHBiometricError.invalidDistancesCount(
                        expected: requiredCollectedFrames,
                        actual: validFrames.count
                    )
                ))
            }
            print("🔚 ========== VERIFICATION ABORTED (NOT ENOUGH VALID FRAMES) ==========\n")
            return
        }
        
        // We'll only use first 10 valid frames for verification
        let framesToUse = Array(validFrames.prefix(requiredCollectedFrames))
        print("🎯 Using first \(framesToUse.count) valid frames for TOKEN comparison.\n")
        
        let totalRawFrames = trimmedFrames.count
        let totalValidFrames = validFrames.count
        let invalidIndicesCopy = invalidFrameIndices
        
        // 3️⃣ Ensure remote cache is filled (salt + [FaceId])
        loadRemoteFaceIdsIfNeeded(deviceKey: deviceKey, fetchViewModel: fetchViewModel) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .failure(let error):
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                
            case .success:
                // 4️⃣ Run the heavy verification loop using cached remote data
                self.performBackendTokenVerificationTokenOnly(
                    framesToUse: framesToUse,
                    totalRawFrames: totalRawFrames,
                    totalValidFrames: totalValidFrames,
                    invalidIndices: invalidIndicesCopy,
                    completion: completion
                )
            }
        }
    }
}

