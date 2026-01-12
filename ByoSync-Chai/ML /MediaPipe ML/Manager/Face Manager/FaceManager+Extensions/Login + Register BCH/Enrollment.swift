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
    deviceKeyHash:String,
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
    
    fetchViewModel.fetchFaceIds(deviceKeyHash:deviceKeyHash){ (result: Result<GetFaceIdData, Error>) in
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

private let IOD_EPSILON: Float = 0.3// ~0.3% tolerance, tune if needed
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
        userId:String,
        authToken: String,
        viewModel: FaceIdViewModel,
        frames: [FrameDistance],                          // ✅ NEW
        minRequired: Int = 60,                            // ✅ at least center frames
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
                        iod: String(sample.iod * 100)            // ✅ per-frame iod
                    )
                )
            } catch {
                failureCount += 1
                #if DEBUG
                print("❌ Enrollment frame \(index + 1) failed: \(error)")
                #endif
            }
        }

        // 3) Don’t require “all frames succeed” anymore — require enough records
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
        framesToUse:[FrameDistance],
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
        
        DispatchQueue.global(qos: .userInitiated).async(execute: {

            var bestRecordMatchCount = 0
            var bestFrameIndex: Int? = nil

            for (frameIndex, frame) in framesToUse.enumerated() {

                #if DEBUG
                let frameStartNs = DispatchTime.now().uptimeNanoseconds
                #endif

                let distances = frame.distances.map(Double.init)
                var recordMatchCount = 0

                for record in faceIds {

                    // IOD gate (frame vs record)
                    guard iodMatches(frame.iod * 100, Float(record.iod) ?? 0) else {
                        continue
                    }

                    guard record.helper.count == expectedN else { continue }
                    guard isHex(record.k2), record.k2.count == 64,
                          let k2Bytes = dataFromHex(record.k2), k2Bytes.count == 32 else { continue }
                    guard isHex(record.token), record.token.count == 64 else { continue }

                    // ✅ Record-aligned distance scaling
                    guard let recordIOD = Float(record.iod) else { continue }
                    

                    let scaledDistances: [Double] = frame.distances.map {
                        let iodInDecimal = recordIOD/100
                        return Double($0 * iodInDecimal)
                    }

                    let v: BCHBiometric.FrameVerification
                    do {
                        v = try bchQueue.sync {
                            try BCHShared.initBCH()
                            return try BCHShared.verifyFrame(
                                distances: scaledDistances,
                                helper: record.helper
                            )
                        }
                    } catch {
                        continue
                    }

                    guard v.success else { continue }

                    let k1Prime = xorData(v.rBytes32, saltBytes)
                    let kRecovered = xorData(k2Bytes, k1Prime)
                    let tokenCandidate = hexFromData(
                        sha256(kRecovered + v.rBytes32)
                    )

                    if tokenCandidate.caseInsensitiveCompare(record.token) == .orderedSame {
                        recordMatchCount += 1
                        if recordMatchCount >= requiredRecordMatches {
                            break
                        }
                    }
                }


                #if DEBUG
                let frameEndNs = DispatchTime.now().uptimeNanoseconds
                logFrameTime(
                    frameIndex: frameIndex,
                    elapsedNs: frameEndNs - frameStartNs
                )
                #endif

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
        })
    }
}

// MARK: - Public Helper for (Load Remote Cache)
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

