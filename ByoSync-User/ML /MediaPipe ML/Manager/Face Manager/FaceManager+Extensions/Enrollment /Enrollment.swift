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
    
    fetchViewModel.fetchFaceIds() { (result: Result<GetFaceIdData, Error>) in
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

        // ONE SALT for all frames (32 bytes)
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

                // token = SHA256(K || R-32Byte)
                let tokenBytes = sha256(kBytes + frameRec.rBytes32)

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
        let requiredRecordMatches = 1
        let expectedN = (1 << Int(BCHBiometric.BCH_M)) - 1
        
        DispatchQueue.global(qos: .userInitiated).async {

            var bestRecordMatchCount = 0
            var bestFrameIndex: Int? = nil

            // Try each captured frame; accept if ANY frame matches >=5 stored records
            for (frameIndex, frame) in framesToUse.enumerated() {
                let distances = frame.map(Double.init)

                var recordMatchCount = 0

                for record in faceIds {
                    guard record.helper.count == expectedN else { continue }
                    guard isHex(record.k2), record.k2.count == 64,
                          let k2Bytes = dataFromHex(record.k2), k2Bytes.count == 32 else { continue }
                    guard isHex(record.token), record.token.count == 64 else { continue }
                    

                    let v: BCHBiometric.FrameVerification
                    do {
                        v = try bchQueue.sync {
                            try BCHShared.initBCH()
                            return try BCHShared.verifyFrame(distances: distances, helper: record.helper)
                        }
                    } catch {
                        continue
                    }

                    guard v.success else { continue }

                    // Android:
                    // k1' = r32 XOR salt
                    // k'  = k2 XOR k1'
                    // token' = SHA256(k' || rByte32)
                    let k1Prime = xorData(v.rBytes32, saltBytes)
                    let kRecovered = xorData(k2Bytes, k1Prime)
                    let tokenCandidate = hexFromData(sha256(kRecovered + v.rBytes32))

                    if tokenCandidate.caseInsensitiveCompare(record.token) == .orderedSame {
                        recordMatchCount += 1
                        if recordMatchCount >= requiredRecordMatches {
                            break
                        }
                    }
                }

                bestRecordMatchCount = max(bestRecordMatchCount, recordMatchCount)
                if recordMatchCount >= requiredRecordMatches {
                    bestFrameIndex = frameIndex
                    break
                }
            }

            let passed = (bestFrameIndex != nil)
            let matchPct = (Double(bestRecordMatchCount) / Double(max(1, faceIds.count))) * 100.0

            let aggregated = BCHBiometric.VerificationResult(
                success: passed,
                matchPercentage: matchPct,
                registrationIndex: 0,
                hashMatch: passed,
                storedHashPreview: "",
                recoveredHashPreview: "",
                numErrorsDetected: 0,
                totalBitsCompared: 0,
                notes: "BestRecordMatches=\(bestRecordMatchCount)/\(faceIds.count), required=\(requiredRecordMatches), bestFrame=\(bestFrameIndex.map(String.init) ?? "nil")"
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
        fetchViewModel: FaceIdFetchViewModel,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        loadRemoteFaceIdsIfNeeded(
            fetchViewModel: fetchViewModel,
            completion: completion
        )
    }
}
