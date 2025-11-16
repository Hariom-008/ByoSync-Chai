import Foundation
import CryptoKit
import CommonCrypto
import Combine

// ✅ Protocol inherits from ObservableObject
protocol CryptoService: ObservableObject {
    func encrypt(text: String) -> String?
    func decrypt(encryptedData: String) -> String?
}

// ✅ Now conforms to CryptoService which includes ObservableObject
final class CryptoManager: CryptoService {
    
    // MARK: - Properties
    private let password: String
    private let salt: String
    private let iterations: UInt32
    private let keyLength: Int
    
    // MARK: - Initialization
    init(
        password: String = "ByoSyncPayWithFace",
        salt: String = "ByoSync",
        iterations: UInt32 = 65536,
        keyLength: Int = 32
    ) {
        self.password = password
        self.salt = salt
        self.iterations = iterations
        self.keyLength = keyLength
    }
    
    private func generateKey() -> Data? {
        guard let passwordData = password.data(using: .utf8),
              let saltData = salt.data(using: .utf8) else {
            return nil
        }
        
        var derivedKeyData = Data(repeating: 0, count: keyLength)
        let derivedCount = derivedKeyData.count
        
        let derivationStatus = derivedKeyData.withUnsafeMutableBytes { derivedKeyBytes in
            saltData.withUnsafeBytes { saltBytes in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordData.bytes,
                    passwordData.count,
                    saltBytes.bindMemory(to: UInt8.self).baseAddress,
                    saltData.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    iterations,
                    derivedKeyBytes.bindMemory(to: UInt8.self).baseAddress,
                    derivedCount
                )
            }
        }
        
        return derivationStatus == kCCSuccess ? derivedKeyData : nil
    }
    
    func encrypt(text: String) -> String? {
        guard let key = generateKey(),
              let textData = text.data(using: .utf8) else {
            return nil
        }
        
        var iv = Data(count: 16)
        let result = iv.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!)
        }
        
        guard result == errSecSuccess else { return nil }
        
        let bufferSize = textData.count + kCCBlockSizeAES128
        var buffer = Data(count: bufferSize)
        var numBytesEncrypted = 0
        
        let cryptStatus = key.withUnsafeBytes { keyBytes in
            iv.withUnsafeBytes { ivBytes in
                textData.withUnsafeBytes { textBytes in
                    buffer.withUnsafeMutableBytes { bufferBytes in
                        CCCrypt(
                            CCOperation(kCCEncrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBytes.baseAddress,
                            key.count,
                            ivBytes.baseAddress,
                            textBytes.baseAddress,
                            textData.count,
                            bufferBytes.baseAddress,
                            bufferSize,
                            &numBytesEncrypted
                        )
                    }
                }
            }
        }
        
        guard cryptStatus == kCCSuccess else { return nil }
        
        buffer.removeSubrange(numBytesEncrypted..<buffer.count)
        
        return iv.hexString + ":" + buffer.hexString
    }
    
    func decrypt(encryptedData: String) -> String? {
        let components = encryptedData.split(separator: ":")
        guard components.count == 2,
              let ivData = Data(hexString: String(components[0])),
              let encryptedBytes = Data(hexString: String(components[1])),
              let key = generateKey() else {
            return nil
        }
        
        let bufferSize = encryptedBytes.count + kCCBlockSizeAES128
        var buffer = Data(count: bufferSize)
        var numBytesDecrypted = 0
        
        let cryptStatus = key.withUnsafeBytes { keyBytes in
            ivData.withUnsafeBytes { ivBytes in
                encryptedBytes.withUnsafeBytes { encryptedBytesPtr in
                    buffer.withUnsafeMutableBytes { bufferBytes in
                        CCCrypt(
                            CCOperation(kCCDecrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBytes.baseAddress,
                            key.count,
                            ivBytes.baseAddress,
                            encryptedBytesPtr.baseAddress,
                            encryptedBytes.count,
                            bufferBytes.baseAddress,
                            bufferSize,
                            &numBytesDecrypted
                        )
                    }
                }
            }
        }
        
        guard cryptStatus == kCCSuccess else { return nil }
        
        buffer.removeSubrange(numBytesDecrypted..<buffer.count)
        
        return String(data: buffer, encoding: .utf8)
    }
}

// MARK: - Data Extensions
extension Data {
    var hexString: String {
        return map { String(format: "%02x", $0) }.joined()
    }
    
    init?(hexString: String) {
        let length = hexString.count / 2
        var data = Data(capacity: length)
        
        for i in 0..<length {
            let start = hexString.index(hexString.startIndex, offsetBy: i * 2)
            let end = hexString.index(start, offsetBy: 2)
            let bytes = hexString[start..<end]
            
            if var byte = UInt8(bytes, radix: 16) {
                data.append(&byte, count: 1)
            } else {
                return nil
            }
        }
        
        self = data
    }
    
    var bytes: [UInt8] {
        return [UInt8](self)
    }
}
