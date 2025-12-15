import Foundation

enum DeviceIdentity {
    private static let key = "deviceId"

    static func resolve() -> String {
        if let existing = KeychainHelper.shared.read(forKey: key) {
            return existing
        }

        let newId = UUID().uuidString
        KeychainHelper.shared.save(newId, forKey: key)
        return newId
    }
}
