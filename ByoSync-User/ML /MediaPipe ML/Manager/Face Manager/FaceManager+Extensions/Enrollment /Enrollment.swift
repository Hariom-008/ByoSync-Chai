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
    deviceKeyHash:String,
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
    
    fetchViewModel.fetchFaceIds(deviceKeyHash:deviceKeyHash) { (result: Result<GetFaceIdData, Error>) in
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


// MARK: - Shared BCH instance (stateful C handle)
private let BCHShared = BCHBiometric()

// Serialize BCHShared usage (C handle is not guaranteed thread-safe)
private let bchQueue = DispatchQueue(label: "bch.shared.serial")

// MARK: - Hex/Data helpers

private func isHex(_ s: String) -> Bool {
    !s.isEmpty && s.allSatisfy { $0.isHexDigit }
}

private func dataFromHex(_ hex: String) -> Data? {
    let len = hex.count
    guard len % 2 == 0 else { return nil }

    var out = Data(capacity: len / 2)
    var idx = hex.startIndex
    for _ in 0..<(len / 2) {
        let next = hex.index(idx, offsetBy: 2)
        guard let b = UInt8(hex[idx..<next], radix: 16) else { return nil }
        out.append(b)
        idx = next
    }
    return out
}

private func hexFromData(_ data: Data) -> String {
    data.map { String(format: "%02x", $0) }.joined()
}

private func randomBytes(_ count: Int) -> Data {
    var data = Data(count: count)
    let res = data.withUnsafeMutableBytes { buf in
        SecRandomCopyBytes(kSecRandomDefault, count, buf.baseAddress!)
    }
    precondition(res == errSecSuccess)
    return data
}

private func xorData(_ a: Data, _ b: Data) -> Data {
    precondition(a.count == b.count, "xorData length mismatch")
    var out = Data(count: a.count)

    out.withUnsafeMutableBytes { outPtr in
        a.withUnsafeBytes { aPtr in
            b.withUnsafeBytes { bPtr in
                let o = outPtr.bindMemory(to: UInt8.self).baseAddress!
                let ap = aPtr.bindMemory(to: UInt8.self).baseAddress!
                let bp = bPtr.bindMemory(to: UInt8.self).baseAddress!
                for i in 0..<a.count { o[i] = ap[i] ^ bp[i] }
            }
        }
    }

    return out
}

private func sha256(_ data: Data) -> Data {
    Data(SHA256.hash(data: data))
}

// MARK: - Enrollment
extension FaceManager {

    /// Generate all 80 enrollment records and upload them in ONE API call.
    func generateAndUploadFaceID(
        authToken: String,
        viewModel: FaceIdViewModel,
        completion: ((Result<Void, Error>) -> Void)? = nil
    ) {
        let trimmedFrames = save316LengthDistanceArray()

        guard trimmedFrames.count == 80 else {
            DispatchQueue.main.async { completion?(.failure(BCHBiometricError.noDistanceArrays)) }
            return
        }

        // Android: ONE SALT for all frames (32 bytes)
        let saltBytes = randomBytes(32)
        let saltHex = hexFromData(saltBytes)

        var addFaceIdPayload: [AddFaceIdRequestBody] = []
        addFaceIdPayload.reserveCapacity(80)

        var failureCount = 0

        for (index, distances) in trimmedFrames.enumerated() {
            let distancesDouble = distances.map { Double($0) }

            do {
                let frameRec: BCHBiometric.FrameRecord = try bchQueue.sync {
                    try BCHShared.initBCH()
                    return try BCHShared.registerFrame(distances: distancesDouble)
                }

                // Android:
                // K1 = R32 XOR SALT
                let k1Bytes = xorData(frameRec.rBytes32, saltBytes)

                // random 32-byte K
                let kBytes = randomBytes(32)

                // K2 = K XOR K1
                let k2Bytes = xorData(kBytes, k1Bytes)

                // token = SHA256(K || FULL_R)
                let tokenBytes = sha256(kBytes + frameRec.rBytesFull)

                addFaceIdPayload.append(
                    AddFaceIdRequestBody(
                        helper: frameRec.helper,
                        k2: hexFromData(k2Bytes),
                        token: hexFromData(tokenBytes)
                    )
                )

            } catch {
                failureCount += 1
                print("❌ Enrollment frame \(index + 1) failed: \(error)")
            }
        }

        guard addFaceIdPayload.count == 80 else {
            print("❌ Enrollment failed — only \(addFaceIdPayload.count)/80 generated (failures=\(failureCount))")
            DispatchQueue.main.async { completion?(.failure(LocalEnrollmentError.noLocalEnrollment)) }
            return
        }

        viewModel.uploadFaceIdList(salt: saltHex, list: addFaceIdPayload)

        DispatchQueue.main.async { completion?(.success(())) }
    }
}

// MARK: - Verification
extension FaceManager {
    func verifyFaceIDAgainstBackend(
        framesToUse: [[Float]],
        completion: @escaping (Result<BCHBiometric.VerificationResult, Error>) -> Void
    ) {
        guard
            let saltHex = RemoteFaceIdCache.salt,
            isHex(saltHex),
            saltHex.count == 64,
            let saltBytes = dataFromHex(saltHex),
            !RemoteFaceIdCache.faceIds.isEmpty
        else {
            DispatchQueue.main.async { completion(.failure(LocalEnrollmentError.noLocalEnrollment)) }
            return
        }

        let faceIds = RemoteFaceIdCache.faceIds
        let requiredMatches = 5
        let expectedN = (1 << Int(BCHBiometric.BCH_M)) - 1

        print("\n" + String(repeating: "=", count: 70))
        print("🔍 VERIFICATION DEBUG - START")
        print(String(repeating: "=", count: 70))
        print("📦 Cache Info:")
        print("   • Salt: \(saltHex)")
        print("   • Salt bytes: \(saltBytes.count) bytes")
        print("   • Stored records: \(faceIds.count)")
        print("   • Frames to verify: \(framesToUse.count)")
        print("   • Expected helper length (n): \(expectedN)")
        print("   • Required matches: \(requiredMatches)")
        print(String(repeating: "=", count: 70))

        DispatchQueue.global(qos: .userInitiated).async {

            var matchedFramesCount = 0
            var detailed: [(capturedIndex: Int, matched: Bool, storedIndex: Int?)] = []

            frameLoop: for (capturedIndex, capturedFrame) in framesToUse.enumerated() {
                let capturedDistances = capturedFrame.map { Double($0) }

                var frameMatched = false
                var matchedStoredIndex: Int? = nil

                print("\n" + String(repeating: "-", count: 70))
                print("🎯 CAPTURED FRAME #\(capturedIndex)")
                print(String(repeating: "-", count: 70))

                // Sample first 5 distances
                let sampleDistances = capturedDistances.prefix(5).map { String(format: "%.4f", $0) }.joined(separator: ", ")
                print("   📊 Distance sample (first 5): [\(sampleDistances)]")
                print("   🔢 Total distances: \(capturedDistances.count)")

                for (storedIndex, record) in faceIds.enumerated() {
                    
                    // CHECKPOINT 1: Helper validation
                    guard record.helper.count == expectedN else {
                        if storedIndex < 2 { // Only log first 2 to avoid spam
                            print("   ❌ Stored[\(storedIndex)] INVALID helper length: \(record.helper.count) (expected \(expectedN))")
                        }
                        continue
                    }
                    
                    // CHECKPOINT 2: K2 validation
                    guard isHex(record.k2), record.k2.count == 64,
                          let k2Bytes = dataFromHex(record.k2),
                          k2Bytes.count == 32 else {
                        if storedIndex < 2 {
                            print("   ❌ Stored[\(storedIndex)] INVALID K2: len=\(record.k2.count), isHex=\(isHex(record.k2))")
                        }
                        continue
                    }
                    
                    // CHECKPOINT 3: Token validation
                    guard isHex(record.token), record.token.count == 64 else {
                        if storedIndex < 2 {
                            print("   ❌ Stored[\(storedIndex)] INVALID token: len=\(record.token.count), isHex=\(isHex(record.token))")
                        }
                        continue
                    }

                    // CHECKPOINT 4: BCH decode
                    let v: BCHBiometric.FrameVerification
                    do {
                        v = try bchQueue.sync {
                            try BCHShared.initBCH()
                            return try BCHShared.verifyFrame(
                                distances: capturedDistances,
                                helper: record.helper
                            )
                        }
                    } catch {
                        if storedIndex < 2 {
                            print("   ❌ Stored[\(storedIndex)] BCH decode EXCEPTION: \(error)")
                        }
                        continue
                    }

                    if !v.success {
                        if storedIndex < 2 {
                            print("   ⏭️  Stored[\(storedIndex)] BCH decode FAILED (v.success = false)")
                        }
                        continue
                    }

                    // CHECKPOINT 5: BCH decode SUCCESS - detailed logging
                    if storedIndex == 0 {
                        print("   ✅ Stored[\(storedIndex)] BCH decode SUCCESS!")
                        print("      📦 v.rBytes32.count = \(v.rBytes32.count)")
                        print("      📦 v.rBytesFull.count = \(v.rBytesFull.count)")
                        print("      📦 v.numErrors = \(v.numErrors)")
                        print("      🔑 rBytes32 hex: \(hexFromData(v.rBytes32.prefix(8)))...")
                        print("      🔑 rBytesFull hex (first 16 bytes): \(hexFromData(v.rBytesFull.prefix(16)))...")
                    }

                    // CHECKPOINT 6: K1' calculation
                    let k1Prime = xorData(v.rBytes32, saltBytes)
                    if storedIndex == 0 {
                        print("      🔄 k1Prime = rBytes32 ⊕ salt")
                        print("      📦 k1Prime.count = \(k1Prime.count)")
                        print("      🔑 k1Prime hex: \(hexFromData(k1Prime.prefix(8)))...")
                    }

                    // CHECKPOINT 7: K' recovery
                    let kRecovered = xorData(k2Bytes, k1Prime)
                    if storedIndex == 0 {
                        print("      🔄 kRecovered = k2 ⊕ k1Prime")
                        print("      📦 kRecovered.count = \(kRecovered.count)")
                        print("      🔑 kRecovered hex: \(hexFromData(kRecovered.prefix(8)))...")
                        print("      🔑 k2 (stored) hex: \(record.k2.prefix(16))...")
                    }

                    // CHECKPOINT 8: Token computation
                    let tokenInput = kRecovered + v.rBytesFull
                    let tokenHash = sha256(tokenInput)
                    let tokenCandidate = hexFromData(tokenHash)
                    
                    if storedIndex == 0 {
                        print("      🔄 tokenInput = kRecovered || rBytesFull")
                        print("      📦 tokenInput.count = \(tokenInput.count) bytes (should be 32 + \(v.rBytesFull.count))")
                        print("      🔑 tokenInput hex (first 16): \(hexFromData(tokenInput.prefix(16)))...")
                        print("      🔐 tokenCandidate = SHA256(tokenInput)")
                        print("      🔑 tokenCandidate: \(tokenCandidate)")
                        print("      🔑 stored token:   \(record.token)")
                        print("      ✅ MATCH? \(tokenCandidate.caseInsensitiveCompare(record.token) == .orderedSame)")
                        print("")
                    }

                    // CHECKPOINT 9: Token comparison
                    if tokenCandidate.caseInsensitiveCompare(record.token) == .orderedSame {
                        print("   🎉 TOKEN MATCH FOUND! Captured[\(capturedIndex)] ↔ Stored[\(storedIndex)]")
                        frameMatched = true
                        matchedStoredIndex = storedIndex
                        break
                    }
                }

                if frameMatched {
                    matchedFramesCount += 1
                    detailed.append((capturedIndex, true, matchedStoredIndex))
                    print("✅ Frame #\(capturedIndex) MATCHED (total: \(matchedFramesCount)/\(requiredMatches))")
                    
                    if matchedFramesCount >= requiredMatches {
                        print("🎉 Required matches reached!")
                        break frameLoop
                    }
                } else {
                    detailed.append((capturedIndex, false, nil))
                    print("❌ Frame #\(capturedIndex) NO MATCH (checked \(faceIds.count) stored records)")
                }
            }

            let totalUsed = detailed.count
            let matchPct = totalUsed > 0 ? (Double(matchedFramesCount) / Double(totalUsed)) * 100.0 : 0.0
            let passed = matchedFramesCount >= requiredMatches

            print("\n" + String(repeating: "=", count: 70))
            print("📊 FINAL RESULT:")
            print("   • Matched frames: \(matchedFramesCount)/\(totalUsed)")
            print("   • Match percentage: \(String(format: "%.1f", matchPct))%")
            print("   • Required: \(requiredMatches)")
            print("   • PASSED: \(passed)")
            print(String(repeating: "=", count: 70))

            let aggregated = BCHBiometric.VerificationResult(
                success: passed,
                matchPercentage: matchPct,
                registrationIndex: 0,
                hashMatch: passed,
                storedHashPreview: "",
                recoveredHashPreview: "",
                numErrorsDetected: 0,
                totalBitsCompared: 0,
                notes: "Token verification: matched=\(matchedFramesCount)/\(totalUsed), required=\(requiredMatches), stored=\(faceIds.count)"
            )

            DispatchQueue.main.async { completion(.success(aggregated)) }
        }
    }
}

// ========================================
// ADD THIS TO YOUR Enrollment.swift FILE
// ========================================
//
// Location: Add this AFTER the loadRemoteFaceIdsIfNeeded() function
//           and BEFORE the "// MARK: - Shared BCH instance" line
//
// This is around line 140-180 in your Enrollment.swift
// ========================================

// MARK: - Public Helper for Testing (Load Remote Cache)
extension FaceManager {
    
    /// Public wrapper to load FaceIds into RemoteFaceIdCache for testing
    /// This must be called before verifyFaceIDAgainstBackend() for testing flows
    func loadRemoteFaceIdsForVerification(
        deviceKeyHash:String,
        fetchViewModel: FaceIdFetchViewModel,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        loadRemoteFaceIdsIfNeeded(
            deviceKeyHash:deviceKeyHash,
            fetchViewModel: fetchViewModel,
            completion: completion
        )
    }
}

// ========================================
// END OF CODE TO ADD
// ========================================
