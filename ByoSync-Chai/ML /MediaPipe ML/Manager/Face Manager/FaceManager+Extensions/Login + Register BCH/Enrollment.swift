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


// MARK: - Remote FaceId cache (for backend verification)
fileprivate struct RemoteEnrollmentRecord {
    let helper: String
    let salt: String        // same for all Collected records for this user
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
    deviceKeyHash: String,
    fetchViewModel: FaceIdFetchViewModel,
    completion: @escaping (Result<Void, Error>) -> Void
) {
    // If we already have salt + records, just reuse them
    if !RemoteFaceIdCache.isEmpty {
        #if DEBUG
        print("💾 [RemoteFaceIdCache] Using cached FaceId data (salt + \(RemoteFaceIdCache.faceIds.count) records).")
        #endif
        completion(.success(()))
        return
    }
    
    
    print("🌐 [RemoteFaceIdCache] Cache empty → fetching FaceIds from backend...")
    
    fetchViewModel.fetchFaceIds(deviceKeyHash: deviceKeyHash) { (result: Result<GetFaceIdData, Error>) in
        switch result {
        case .failure(let error):
            completion(.failure(error))
            
        case .success(let data):
            let saltHex = data.salt
            let faceIds = data.faceData
            
            #if DEBUG
            print("✅ [RemoteFaceIdCache] Fetched \(faceIds.count) FaceId items from backend")
            print("🔑 [RemoteFaceIdCache] SALT from backend: \(saltHex) (len=\(saltHex.count))")
            #endif
            guard !faceIds.isEmpty else {
                completion(.failure(LocalEnrollmentError.noLocalEnrollment))
                return
            }
            
            RemoteFaceIdCache.salt = saltHex
            RemoteFaceIdCache.faceIds = faceIds
            #if DEBUG
            print("💾 [RemoteFaceIdCache] Cache filled (records=\(faceIds.count))")
            #endif
            
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

private let IOD_EPSILON: Float = 0.1 // tune if needed
@inline(__always)
private func iodMatches(_ a: Float, _ b: Float) -> Bool {
    #if DEBUG
    print("IOD : \(a) - \(b)")
    #endif
    return abs(a - b) <= IOD_EPSILON
}



// MARK: - Enrollment
extension FaceManager {

    /// Upload enrollment records for ALL collected registration frames.
    func generateAndUploadFaceID(
        userId: String,
        authToken: String,
        viewModel: FaceIdViewModel,
        frames: [FrameDistance],
        minRequired: Int = 60,
        completion: ((Result<Void, Error>) -> Void)? = nil
    ) {
        // 1) Validate frames
        let valid = frames.filter { $0.distances.count == 316 }
        guard valid.count >= minRequired else {
            DispatchQueue.main.async { completion?(.failure(BCHBiometricError.noDistanceArrays)) }
            return
        }

        // 2) ONE SALT for all frames (32 bytes)
        let saltBytes = randomBytes(32)
        let saltHex = hexFromData(saltBytes)

        var addFaceIdPayload: [AddFaceIdRequestBody] = []
        addFaceIdPayload.reserveCapacity(valid.count)

        var failureCount = 0

        for (index, sample) in valid.enumerated() {
            let distancesDouble = sample.distances.map(Double.init)

            do {
                let frameRec: BCHBiometric.FrameRecord = try bchQueue.sync {
                    try BCHShared.initBCH()
                    return try BCHShared.registerFrame(distances: distancesDouble)
                }

                let k1Bytes = xorData(frameRec.rBytes32, saltBytes)
                let kBytes  = randomBytes(32)
                let k2Bytes = xorData(kBytes, k1Bytes)
                let tokenBytes = sha256(kBytes + frameRec.rBytes32)

                addFaceIdPayload.append(
                    AddFaceIdRequestBody(
                        helper: frameRec.helper,
                        k2: hexFromData(k2Bytes),
                        token: hexFromData(tokenBytes),
                        iod: String(sample.iod * 100)
                    )
                )
            } catch {
                failureCount += 1
                #if DEBUG
                print("❌ Enrollment frame \(index + 1) failed: \(error)")
                #endif
            }
        }

        guard addFaceIdPayload.count >= minRequired else {
            #if DEBUG
            print("❌ Enrollment failed — only \(addFaceIdPayload.count) generated (failures=\(failureCount))")
            #endif
            DispatchQueue.main.async { completion?(.failure(LocalEnrollmentError.noLocalEnrollment)) }
            return
        }

        viewModel.uploadFaceIdList(userId: userId, salt: saltHex, list: addFaceIdPayload)
        DispatchQueue.main.async { completion?(.success(())) }
    }
}

#if DEBUG
@inline(__always)
private func logFrameTime(
    frameIndex: Int,
    elapsedNs: UInt64
) {
    let ms = Double(elapsedNs) / 1_000_000.0
    print("🕒 [FaceVerify] Frame \(frameIndex) took \(String(format: "%.2f", ms)) ms")
}
#endif

// MARK: - Verification
extension FaceManager {

    func verifyFaceIDAgainstBackend(
        framesToUse: [FrameDistance],
        requiredMatches: Int = 4,
        completion: @escaping (Result<BCHBiometric.VerificationResult, Error>) -> Void
    ) {

        guard
            let saltHex = RemoteFaceIdCache.salt,
            isHex(saltHex), saltHex.count == 64,
            let saltBytes = dataFromHex(saltHex),
            !RemoteFaceIdCache.faceIds.isEmpty
        else {
            print("❌ [Verification] No enrollment data in cache")
            completion(.failure(LocalEnrollmentError.noLocalEnrollment))
            return
        }

        print("🔑 [Verification] Using salt: \(saltHex.prefix(16))...")
        print("📦 [Verification] Enrollment records: \(RemoteFaceIdCache.faceIds.count)")

        // 1) Pre-process records (parse hex once)
        let cachedRecords = preprocessRecords(RemoteFaceIdCache.faceIds)
        print("✅ [Verification] Preprocessed \(cachedRecords.count) records")

        // 2) Select frames to verify (keep this policy centralized)
        let framesToVerify = selectBestFrames(from: framesToUse, count: 5)

        #if DEBUG
        let iodList = framesToVerify.map { String(format: "%.4f", Double($0.iod * 100)) }.joined(separator: ", ")
        print("✅ [Verification] Selected \(framesToVerify.count) frames: [\(iodList)]")
        #endif

        DispatchQueue.global(qos: .userInitiated).async {

            var matchedFrames = 0
            let lock = NSLock()

            DispatchQueue.concurrentPerform(iterations: framesToVerify.count) { idx in
                let frame = framesToVerify[idx]

                let relevantRecords = cachedRecords.filter { iodMatches(frame.iod * 100, $0.iod) }

                #if DEBUG
                print("🎯 [Verification] Frame \(idx): \(relevantRecords.count)/\(cachedRecords.count) records pass IOD")
                #endif

                var frameMatched = false

                for record in relevantRecords {
                    // Scale distances
                    let scaledDistances = frame.distances.map { Double($0 * (record.iod / 100)) }

                    // BCH verify (serialized)
                    let v: BCHBiometric.FrameVerification
                    do {
                        v = try bchQueue.sync {
                            try BCHShared.verifyFrame(distances: scaledDistances, helper: record.helper)
                        }
                    } catch {
                        continue
                    }

                    guard v.success else { continue }

                    // Token check
                    let k1Prime = xorData(v.rBytes32, saltBytes)
                    let kRecovered = xorData(record.k2Bytes, k1Prime)
                    let tokenCandidate = sha256(kRecovered + v.rBytes32)

                    if tokenCandidate == record.tokenBytes {
                        frameMatched = true
                        break
                    }
                }

                if frameMatched {
                    lock.lock()
                    matchedFrames += 1
                    lock.unlock()
                }
            }

            let required = max(1, requiredMatches)
            let passed = matchedFrames >= required
            let matchPct = framesToVerify.isEmpty ? 0.0 : (Double(matchedFrames) / Double(framesToVerify.count)) * 100.0

            #if DEBUG
            print("✅ [Verification] matchedFrames=\(matchedFrames)/\(framesToVerify.count) required=\(required) passed=\(passed)")
            #endif

            let result = BCHBiometric.VerificationResult(
                success: passed,
                matchPercentage: matchPct,
                registrationIndex: 0,
                hashMatch: passed,
                storedHashPreview: "",
                recoveredHashPreview: "",
                numErrorsDetected: 0,
                totalBitsCompared: 0,
                notes: "Token-only verification: matchedFrames=\(matchedFrames)/\(framesToVerify.count), required=\(required), storedRecords=\(cachedRecords.count)"
            )

            DispatchQueue.main.async { completion(.success(result)) }
        }
    }

    // Helper functions
    private func preprocessRecords(_ faceIds: [FaceId]) -> [CachedRecord] {
        return faceIds.compactMap { record in
            guard let iod = Float(record.iod),
                  isHex(record.k2), let k2Bytes = dataFromHex(record.k2),
                  isHex(record.token), let tokenBytes = dataFromHex(record.token)
            else { return nil }
            
            return CachedRecord(
                k2Bytes: k2Bytes,
                tokenBytes: tokenBytes,
                iod: iod,
                helper: record.helper
            )
        }
    }

    private func selectBestFrames(from frames: [FrameDistance], count: Int) -> [FrameDistance] {
        // Strategy: Pick center frames (stable) — adjust later if needed
        let center = frames.count / 2
        let halfRange = count / 2
        let start = max(0, center - halfRange)
        let end = min(frames.count, start + count)
        return Array(frames[start..<end])
    }
    
    struct CachedRecord {
        let k2Bytes: Data
        let tokenBytes: Data
        let iod: Float
        let helper: String
    }
}

// MARK: - Public Helper for (Load Remote Cache)
extension FaceManager {
    
    /// Existing (network) loader — keep as-is for other flows
    func loadRemoteFaceIdsForVerification(
        deviceKeyHash: String,
        fetchViewModel: FaceIdFetchViewModel,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        loadRemoteFaceIdsIfNeeded(
            deviceKeyHash: deviceKeyHash,
            fetchViewModel: fetchViewModel,
            completion: completion
        )
    }

    /// New overload: populate RemoteFaceIdCache using data you already fetched (no network).
    /// Use this when FetchUserByTokenViewModel already returned salt + faceIds.
    func loadRemoteFaceIdsForVerification(
        salt: String,
        faceIds: [FaceId],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard isHex(salt), salt.count == 64, !faceIds.isEmpty else {
            completion(.failure(LocalEnrollmentError.noLocalEnrollment))
            return
        }

        RemoteFaceIdCache.reset()
        RemoteFaceIdCache.salt = salt
        RemoteFaceIdCache.faceIds = faceIds

        #if DEBUG
        print("💾 [RemoteFaceIdCache] Filled from FetchUserByTokenVM (records=\(faceIds.count))")
        #endif

        completion(.success(()))
    }
}
