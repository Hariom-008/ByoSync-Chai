import Foundation

// MARK: - Android-aligned types (strings match AppLogger.kt)
enum LogType: String, Codable, Sendable {
    case performance = "PERFORMANCE"
    case error = "ERROR"
    case apiCall = "API_CALL"
    case screenTransition = "SCREEN_TRANSITION"
    case cameraEvent = "CAMERA_EVENT"
    case screen = "SCREEN"
    case crash = "CRASH"
}

// Android uses "form" with values like "APP"
enum LogForm: String, Codable, Sendable {
    case app = "APP"
    case ml = "ML"
}

// Payload entry: matches Kotlin LogEntry :contentReference[oaicite:4]{index=4}
struct BackendLogEntry: Codable, Sendable {
    let type: String
    let form: String
    let message: String
    let timeTaken: String   // duration in ms (string)
    let user: String
}

// Request wrapper: matches Kotlin LogRequest :contentReference[oaicite:5]{index=5}
struct LogRequest: Codable, Sendable {
    let logsArray: [BackendLogEntry]
}

// Response (keep your existing shape)
struct LogCreateResponse: Decodable, Sendable {
    let success: Bool
    let message: String
    let statusCode: Int?
}

// Internal buffer entry (keeps it simple; no file/func/emoji formatting)
struct InternalLogEntry: Codable, Sendable {
    let type: LogType
    let form: LogForm
    let message: String
    let timeTakenMs: Int64
    let user: String

    func toBackendEntry(fallbackUserId: String) -> BackendLogEntry {
        let finalUser = user.isEmpty ? fallbackUserId : user
        return BackendLogEntry(
            type: type.rawValue,
            form: form.rawValue,
            message: message,
            timeTaken: String(max(0, timeTakenMs)),
            user: finalUser
        )
    }

    func estimatedSizeBytes() -> Int64 {
        // cheap but stable estimate: JSON-encode and count bytes
        // if encoding fails, fallback to utf8 length of message
        if let data = try? JSONEncoder().encode(self) {
            return Int64(data.count)
        }
        return Int64(message.utf8.count)
    }
}

// Backup wrapper (Android buffer_backup.json-style) :contentReference[oaicite:6]{index=6}
struct BufferBackup: Codable, Sendable {
    let logsArray: [InternalLogEntry]
    let backupTimestamp: Int64
    let bufferSizeKB: Int64
    let consecutiveFailures: Int
}
