import Foundation
import CryptoKit
import Security

// MARK: - Errors
enum BCHBiometricError: Error, LocalizedError {
    case notInitialized
    case invalidDistancesCount(expected: Int, actual: Int)
    case memory
    case codec(String)
    case missingRegistrationData
    case indexOutOfBounds
    case noDistanceArrays

    var errorDescription: String? {
        switch self {
        case .notInitialized: return "BCH module not initialized."
        case .invalidDistancesCount(let e, let a): return "Expected \(e) distances, got \(a)."
        case .memory: return "Failed to allocate native memory."
        case .codec(let m): return "BCH codec error: \(m)"
        case .missingRegistrationData: return "Missing helper or secret hash."
        case .indexOutOfBounds: return "Registration index out of bounds."
        case .noDistanceArrays : return "No distance arrays"
        }
    }
}


@_silgen_name("init_bch")
func c_init_bch(_ m: Int32, _ t: Int32, _ primPoly: UInt32) -> OpaquePointer?

@_silgen_name("bch_get_ecc_bits_bridge")
func c_get_ecc_bits(_ ctl: OpaquePointer?) -> Int32

@_silgen_name("encodebits_bch")
func c_encodebits_bch(_ ctl: OpaquePointer?, _ data: UnsafeMutablePointer<UInt8>!, _ ecc: UnsafeMutablePointer<UInt8>!)

@_silgen_name("decodebits_bch")
func c_decodebits_bch(_ ctl: OpaquePointer?, _ data: UnsafeMutablePointer<UInt8>!, _ recvECC: UnsafeMutablePointer<UInt8>!, _ errloc: UnsafeMutablePointer<UInt32>!) -> Int32

@_silgen_name("correctbits_bch")
func c_correctbits_bch(_ ctl: OpaquePointer?, _ databits: UnsafeMutablePointer<UInt8>!, _ errloc: UnsafeMutablePointer<UInt32>!, _ nerr: Int32)

@_silgen_name("free_bch")
func c_free_bch(_ ctl: OpaquePointer?)


final class BCHBiometric {

    // Keep in sync with Android/JS
    static let NUM_DISTANCES = 316
    static let BITS_PER_DISTANCE = 8
    static let TOTAL_DATA_BITS = NUM_DISTANCES * BITS_PER_DISTANCE

    static let BCH_M: Int32 = 13
    static let BCH_T: Int32 = 455

    typealias BitArray = [UInt8]

    // ---- Public types you already used elsewhere ----
    struct VerificationResult: Codable {
        let success: Bool
        let matchPercentage: Double
        let registrationIndex: Int
        let hashMatch: Bool
        let storedHashPreview: String
        let recoveredHashPreview: String
        let numErrorsDetected: Int
        let totalBitsCompared: Int
        let notes: String?
    }

    // ---- Android-equivalent frame primitives ----
    struct FrameRecord {
        let helper: String         // length n, "0/1" string
        let rBytesFull: Data       // packed R (K bits -> bytes)
        let rBytes32: Data         // first 32 bytes of R
    }

    struct FrameVerification {
        let success: Bool
        let rBytesFull: Data
        let rBytes32: Data
        let numErrors: Int
    }

    // MARK: - State
    private var ctl: OpaquePointer?
    private var eccBits: Int = 0
    private var n: Int = 0
    private var K: Int = 0
    private var initialized = false

    deinit {
        if let c = ctl {
            c_free_bch(c)
        }
    }

    // MARK: - Init
    func initBCH() throws {
        if initialized { return }
        guard let handle = c_init_bch(Self.BCH_M, Self.BCH_T, 0) else {
            throw NSError(domain: "BCH", code: 1, userInfo: [NSLocalizedDescriptionKey: "init_bch returned null"])
        }
        ctl = handle
        eccBits = Int(c_get_ecc_bits(handle))
        n = (1 << Int(Self.BCH_M)) - 1
        K = n - eccBits
        initialized = true
    }

    // MARK: - Public: register/verify frame (Android-aligned)
    func registerFrame(distances: [Double]) throws -> FrameRecord {
        try ensureInit()

        let biometricBits = try distancesToBits(distances)     // 2528 bits
        let alignedBio = alignBits(biometricBits, to: n)       // pad to n with zeros

        // R: K random bits (0/1 bytes)
        let secretKeyBits = generateRandomBits(length: K)
        print("secretKeyBit:\(secretKeyBits)")
        // codeword = R || ECC
        let codeword = try encodeSecretKeyBCH(secretKeyBits)   // length n (K + eccBits)
        print("codeWordBit:\(codeword)")

        // helper = codeword XOR biometricAligned
        let helperBits = xorBits(codeword, alignedBio)

        let rFull = bitsToBytes(secretKeyBits)                 // packed bytes of R
        guard rFull.count >= 32 else {
            throw NSError(domain: "BCH", code: 2, userInfo: [NSLocalizedDescriptionKey: "R must be >= 32 bytes"])
        }

        return FrameRecord(
            helper: bitArrayToString(helperBits),
            rBytesFull: rFull,
            rBytes32: Data(rFull.prefix(32))
        )
    }

    func verifyFrame(distances: [Double], helper: String) throws -> FrameVerification {
        let totalStartTime = CFAbsoluteTimeGetCurrent()
        
        #if DEBUG
        let enableTiming = true  // Set to false to disable timing logs
        #else
        let enableTiming = false
        #endif
        
        // Step 1: Ensure initialization
        var stepStartTime = CFAbsoluteTimeGetCurrent()
        try ensureInit()
        if enableTiming {
            print("🔐 [BCH] ensureInit: \(String(format: "%.2f", (CFAbsoluteTimeGetCurrent() - stepStartTime) * 1000))ms")
        }
        
        // Step 2: Validate helper length
        stepStartTime = CFAbsoluteTimeGetCurrent()
        guard helper.count == n else {
            print("❌ [BCH] Verification failed - Helper length mismatch: \(helper.count) != \(n)")
            return FrameVerification(success: false, rBytesFull: Data(), rBytes32: Data(), numErrors: 0)
        }
        if enableTiming {
            print("🔐 [BCH] Helper validation: \(String(format: "%.2f", (CFAbsoluteTimeGetCurrent() - stepStartTime) * 1000))ms")
        }
        
        // Step 3: Convert helper to bits
        stepStartTime = CFAbsoluteTimeGetCurrent()
        let helperBits = bitStringToArray(helper)
        if enableTiming {
            print("🔐 [BCH] Helper to bits: \(String(format: "%.2f", (CFAbsoluteTimeGetCurrent() - stepStartTime) * 1000))ms")
        }
        
        // Step 4: Convert distances to bits
        stepStartTime = CFAbsoluteTimeGetCurrent()
        let biometricBits = try distancesToBits(distances)
        if enableTiming {
            print("🔐 [BCH] Distances to bits: \(String(format: "%.2f", (CFAbsoluteTimeGetCurrent() - stepStartTime) * 1000))ms")
        }
        
        // Step 5: Align biometric bits
        stepStartTime = CFAbsoluteTimeGetCurrent()
        let alignedBio = alignBits(biometricBits, to: n)
        if enableTiming {
            print("🔐 [BCH] Bit alignment: \(String(format: "%.2f", (CFAbsoluteTimeGetCurrent() - stepStartTime) * 1000))ms")
        }
        
        // Step 6: XOR operation
        stepStartTime = CFAbsoluteTimeGetCurrent()
        let codewordPrime = xorBits(helperBits, alignedBio)
        if enableTiming {
            print("🔐 [BCH] XOR operation: \(String(format: "%.2f", (CFAbsoluteTimeGetCurrent() - stepStartTime) * 1000))ms")
        }
        
        // Step 7: Split codeword
        stepStartTime = CFAbsoluteTimeGetCurrent()
        let cw = alignBits(codewordPrime, to: n)
        var dataBuf = Array(cw[0..<K])
        var eccBuf = Array(cw[K..<(K + eccBits)])
        var errloc = [UInt32](repeating: 0, count: Int(Self.BCH_T))
        if enableTiming {
            print("🔐 [BCH] Codeword split: \(String(format: "%.2f", (CFAbsoluteTimeGetCurrent() - stepStartTime) * 1000))ms")
        }
        
        // Step 8: BCH decode
        stepStartTime = CFAbsoluteTimeGetCurrent()
        let nerr: Int32 = dataBuf.withUnsafeMutableBufferPointer { dataPtr in
            eccBuf.withUnsafeMutableBufferPointer { eccPtr in
                errloc.withUnsafeMutableBufferPointer { errPtr in
                    c_decodebits_bch(ctl, dataPtr.baseAddress!, eccPtr.baseAddress!, errPtr.baseAddress!)
                }
            }
        }
        if enableTiming {
            print("🔐 [BCH] BCH decode: \(String(format: "%.2f", (CFAbsoluteTimeGetCurrent() - stepStartTime) * 1000))ms | Errors: \(nerr)")
        }
        
        // Check decode status
        if nerr < 0 {
            print("❌ [BCH] Verification failed - Decode error: \(nerr)")
            return FrameVerification(success: false, rBytesFull: Data(), rBytes32: Data(), numErrors: Int(nerr))
        }
        
        // Step 9: Correct errors if detected
        if nerr > 0 {
            stepStartTime = CFAbsoluteTimeGetCurrent()
            _ = dataBuf.withUnsafeMutableBufferPointer { dataPtr in
                errloc.withUnsafeMutableBufferPointer { errPtr in
                    c_correctbits_bch(ctl, dataPtr.baseAddress!, errPtr.baseAddress!, nerr)
                }
            }
            if enableTiming {
                print("🔐 [BCH] Error correction: \(String(format: "%.2f", (CFAbsoluteTimeGetCurrent() - stepStartTime) * 1000))ms | Corrected: \(nerr)")
            }
        }
        
        // Step 10: Convert to bytes
        stepStartTime = CFAbsoluteTimeGetCurrent()
        let correctedSecretBits = dataBuf.map { $0 & 1 }
        let rFull = bitsToBytes(correctedSecretBits)
        if enableTiming {
            print("🔐 [BCH] Bits to bytes: \(String(format: "%.2f", (CFAbsoluteTimeGetCurrent() - stepStartTime) * 1000))ms")
        }
        
        // Validate result
        guard rFull.count >= 32 else {
            print("❌ [BCH] Verification failed - Insufficient bytes: \(rFull.count) < 32")
            return FrameVerification(success: false, rBytesFull: Data(), rBytes32: Data(), numErrors: Int(nerr))
        }
        
        let totalTime = (CFAbsoluteTimeGetCurrent() - totalStartTime) * 1000
        print("✅ [BCH] Verification successful | Total: \(String(format: "%.2f", totalTime))ms | Errors corrected: \(nerr)")
        
        return FrameVerification(
            success: true,
            rBytesFull: rFull,
            rBytes32: Data(rFull.prefix(32)),
            numErrors: Int(nerr)
        )
    }
    
    // MARK: - BCH encode (1 byte per bit)
    private func encodeSecretKeyBCH(_ secretKeyBits: BitArray) throws -> BitArray {
        try ensureInit()

        let data = alignBits(secretKeyBits, to: K)
        var dataBuf = data
        var eccBuf = [UInt8](repeating: 0, count: eccBits)

        dataBuf.withUnsafeMutableBufferPointer { dataPtr in
            eccBuf.withUnsafeMutableBufferPointer { eccPtr in
                c_encodebits_bch(ctl, dataPtr.baseAddress!, eccPtr.baseAddress!)
            }
        }

        return dataBuf + eccBuf
    }

    // MARK: - Distances -> bits (Android-style normalization)
    private func distancesToBits(_ distances: [Double]) throws -> BitArray {
        guard distances.count == Self.NUM_DISTANCES else {
            throw NSError(domain: "BCH", code: 3, userInfo: [NSLocalizedDescriptionKey: "Expected \(Self.NUM_DISTANCES) distances, got \(distances.count)"])
        }

        // Guard NaN/Inf like Android validateDistances()
        for d in distances {
            if d.isNaN || d.isInfinite {
                throw NSError(domain: "BCH", code: 4, userInfo: [NSLocalizedDescriptionKey: "Distance contained NaN/Inf"])
            }
        }

        guard let minVal = distances.min(), let maxVal = distances.max() else {
            return Array(repeating: 0, count: Self.TOTAL_DATA_BITS)
        }

        let range = maxVal - minVal
        let normalized: [Int]
        if range == 0 || range.isNaN {
            normalized = Array(repeating: 128, count: distances.count)
        } else {
            normalized = distances.map { d in
                let x = (d - minVal) / range
                // Fixed (Correct - Round Half Up, matches Android)
                let v = Int((x * 255.0).rounded(.toNearestOrAwayFromZero))
                
                return min(255, max(0, v))
            }
        }

        var bits: BitArray = []
        bits.reserveCapacity(Self.TOTAL_DATA_BITS)
        for v in normalized {
            for b in stride(from: 7, through: 0, by: -1) {
                bits.append(UInt8((v >> b) & 1))
            }
        }
        return bits
    }

    // MARK: - Bit utils
    private func alignBits(_ bits: BitArray, to target: Int) -> BitArray {
        if bits.count == target { return bits }
        if bits.count < target {
            return bits + [UInt8](repeating: 0, count: target - bits.count)
        }
        return Array(bits.prefix(target))
    }

    private func xorBits(_ a: BitArray, _ b: BitArray) -> BitArray {
        precondition(a.count == b.count, "xor length mismatch")
        var out = BitArray(repeating: 0, count: a.count)
        for i in 0..<a.count { out[i] = a[i] ^ b[i] }
        return out
    }

    // Matches Android bitsToBytes: MSB-first packing + pad last byte
    private func bitsToBytes(_ bits: BitArray) -> Data {
        let outCount = (bits.count + 7) / 8
        var out = [UInt8](repeating: 0, count: outCount)

        var cur: UInt8 = 0
        var idx = 0

        for i in 0..<bits.count {
            cur = (cur << 1) | (bits[i] & 1)
            if (i + 1) % 8 == 0 {
                out[idx] = cur
                idx += 1
                cur = 0
            }
        }

        if bits.count % 8 != 0 {
            let shift = 8 - (bits.count % 8)
            out[idx] = cur << UInt8(shift)
        }

        return Data(out)
    }

    private func generateRandomBits(length: Int) -> BitArray {
        let byteCount = (length + 7) / 8
        var bytes = [UInt8](repeating: 0, count: byteCount)
        let res = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
        precondition(res == errSecSuccess)

        var bits = BitArray()
        bits.reserveCapacity(length)
        for i in 0..<length {
            let byte = i / 8
            let bit = 7 - (i % 8)
            bits.append((bytes[byte] >> bit) & 1)
        }
        return bits
    }

    private func bitStringToArray(_ s: String) -> BitArray {
        var out = BitArray()
        out.reserveCapacity(s.count)
        for ch in s.utf8 { out.append(ch == 49 ? 1 : 0) } // '1' = 49
        return out
    }

    private func bitArrayToString(_ bits: BitArray) -> String {
        bits.map { $0 == 0 ? "0" : "1" }.joined()
    }

    private func ensureInit() throws {
        if !initialized { try initBCH() }
    }
}
