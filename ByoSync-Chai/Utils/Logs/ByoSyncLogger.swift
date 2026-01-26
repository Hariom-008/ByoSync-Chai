import Foundation
import UIKit

/// Android-aligned logger:
/// - Payload: { type, form, message, timeTaken(ms string), user }
/// - Buffer thresholds: soft/hard in KB
/// - Batch: max N logs
/// - Periodic flush + periodic disk backup
/// - Crash: persist + best-effort upload
final class Logger {

    // MARK: - Singleton
    static let shared = Logger()

    // MARK: - Android-aligned config (mirrors AppLogger.kt)
    private let softUploadThresholdKB: Int64 = 5
    private let hardMaxThresholdKB: Int64 = 10
    private let maxBatchSize: Int = 200
    private let flushInterval: TimeInterval = 30.0
    private let backupInterval: TimeInterval = 60.0
    private let maxBodyLength: Int = 500
    private let maxMessageLength: Int = 1000

    private let maxRetryAttempts: Int = 3
    private let initialRetryDelayMs: Int64 = 5_000
    private let maxRetryDelayMs: Int64 = 60_000

    // MARK: - State
    private let queue = DispatchQueue(label: "com.byosync.logger", qos: .utility)
    private var isInitialized = false

    private var logBuffer: [InternalLogEntry] = []
    private var currentBufferBytes: Int64 = 0

    private var uploadInProgress = false
    private var consecutiveFailures = 0
    private var lastUploadAttemptTimeMs: Int64 = 0

    private var flushTimer: DispatchSourceTimer?
    private var backupTimer: DispatchSourceTimer?

    private let repository: LogRepositoryProtocol

    // MARK: - Disk
    private lazy var logDir: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("ByoSyncLogs", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private lazy var backupFile: URL = logDir.appendingPathComponent("buffer_backup.json")

    // MARK: - Init
    init(repository: LogRepositoryProtocol = LogRepository()) {
        self.repository = repository
    }

    // MARK: - Public init hook (call from AppDelegate/SceneDelegate once)
    func initialize() {
        queue.async {
            guard !self.isInitialized else { return }
            self.isInitialized = true

            self.restoreBackupBuffer()
            self.startPeriodicUploadCheck()
            self.startPeriodicBackup()
            self.setupCrashHandling()
            self.observeAppLifecycle()

            #if DEBUG
            print("✅ [Logger] initialized @ \(self.logDir.path)")
            #endif
        }
    }

    // MARK: - Android-like API surface

    /// Android: d(tag,message,timeTaken,user) => type=PERFORMANCE, form=APP
    func d(_ tag: String, _ message: String, timeTakenMs: Int64? = nil, user: String? = nil) {
        console("DEBUG", tag, message)
        addToBuffer(type: .performance, form: .app, message: message, timeTakenMs: timeTakenMs, user: user, priority: false)
    }

    /// Android: i(tag,message,timeTaken,user) => type=PERFORMANCE, form=APP
    func i(_ tag: String, _ message: String, timeTakenMs: Int64? = nil, user: String? = nil) {
        console("INFO", tag, message)
        addToBuffer(type: .performance, form: .app, message: message, timeTakenMs: timeTakenMs, user: user, priority: false)
    }

    /// Android: e(tag,message,throwable,timeTaken,user) => type=ERROR, priority=true
    func e(_ tag: String, _ message: String, error: Error? = nil, timeTakenMs: Int64? = nil, user: String? = nil) {
        let full = buildErrorMessage(message: message, error: error)
        console("ERROR", tag, full)
        addToBuffer(type: .error, form: .app, message: full, timeTakenMs: timeTakenMs, user: user, priority: true)
    }

    /// Android: api(url,requestBody,responseBody,timeTakenMs,user) => type=API_CALL
    func api(
        url: String,
        requestBody: String? = nil,
        responseBody: String? = nil,
        timeTakenMs: Int64? = nil,
        user: String? = nil
    ) {
        let req = truncate(requestBody, max: maxBodyLength)
        let res = truncate(responseBody, max: maxBodyLength)

        var msg = "\(url)"
        if let req { msg += " | Req: \(req)" }
        if let res { msg += " | Res: \(res)" }

        console("INFO", "API", msg)
        addToBuffer(type: .apiCall, form: .app, message: msg, timeTakenMs: timeTakenMs, user: user, priority: false)
    }

    func screenTransition(from: String, to: String, durationMs: Int64) {
        let msg = "\(from) → \(to)"
        console("INFO", "NAVIGATION", msg)
        addToBuffer(type: .screenTransition, form: .app, message: msg, timeTakenMs: durationMs, user: nil, priority: false)
    }

    func camera(event: String, timeTakenMs: Int64? = nil, user: String? = nil) {
        console("INFO", "CAMERA", event)
        addToBuffer(type: .cameraEvent, form: .app, message: event, timeTakenMs: timeTakenMs, user: user, priority: false)
    }

    func screen(_ tag: String, screenName: String, event: String) {
        let msg = "\(screenName) | \(event)"
        console("INFO", tag, msg)
        addToBuffer(type: .screen, form: .app, message: msg, timeTakenMs: nil, user: nil, priority: false)
    }

    // MARK: - Manual controls (same spirit as Android)
    func forceUpload() {
        queue.async { self.uploadLogs(forceClear: false) }
    }

    func uploadOnAppClose() {
        queue.async {
            let kb = self.currentBufferBytes / 1024
            guard kb > 0 else { return }
            self.uploadLogs(forceClear: false, timeoutSeconds: 5)
        }
    }

    func clearAllLogs() {
        queue.async {
            self.logBuffer.removeAll()
            self.currentBufferBytes = 0
            self.consecutiveFailures = 0
            self.deleteBackupIfExists()
            #if DEBUG
            print("🗑️ [Logger] cleared all logs")
            #endif
        }
    }

    func getBufferStatus() -> String {
        queue.sync {
            let kb = currentBufferBytes / 1024
            return "Buffer: \(logBuffer.count) logs, \(kb)KB | Failures: \(consecutiveFailures)/\(maxRetryAttempts)"
        }
    }

    // MARK: - Core buffer append

    private func addToBuffer(
        type: LogType,
        form: LogForm,
        message: String,
        timeTakenMs: Int64?,
        user: String?,
        priority: Bool
    ) {
        queue.async {
            guard self.isInitialized else { return }

            let safeTimeTaken = max(0, timeTakenMs ?? 0)
            var safeMessage = message
            if safeMessage.count > self.maxMessageLength {
                safeMessage = String(safeMessage.prefix(self.maxMessageLength - 3)) + "..."
            }

            let entry = InternalLogEntry(
                type: type,
                form: form,
                message: safeMessage,
                timeTakenMs: safeTimeTaken,
                user: user ?? ""
            )

            let entryBytes = entry.estimatedSizeBytes()
            self.logBuffer.append(entry)
            self.currentBufferBytes += entryBytes

            self.checkAndUploadIfNeeded(priority: priority)
        }
    }

    // MARK: - Threshold check (size-based like Android)

    private func checkAndUploadIfNeeded(priority: Bool) {
        let currentKB = currentBufferBytes / 1024
        if currentKB >= hardMaxThresholdKB {
            #if DEBUG
            print("⚠️ [Logger] buffer \(currentKB)KB (hard \(hardMaxThresholdKB)KB) -> force upload")
            #endif
            uploadLogs(forceClear: true)
            return
        }

        if priority {
            uploadLogs(forceClear: false)
            return
        }

        if currentKB >= softUploadThresholdKB {
            let now = nowMs()
            let sinceLast = now - lastUploadAttemptTimeMs
            let backoff = calculateBackoffDelayMs()

            if sinceLast >= backoff {
                uploadLogs(forceClear: false)
            } else {
                #if DEBUG
                print("⏳ [Logger] backing off, retry in \((backoff - sinceLast) / 1000)s")
                #endif
            }
        }
    }

    private func calculateBackoffDelayMs() -> Int64 {
        guard consecutiveFailures > 0 else { return 0 }
        // 5s, 10s, 20s, 40s, 60s (cap) — Android behavior
        let shift = max(0, consecutiveFailures - 1)
        let delay = initialRetryDelayMs * Int64(1 << shift)
        return min(delay, maxRetryDelayMs)
    }

    // MARK: - Upload

    private func uploadLogs(forceClear: Bool, timeoutSeconds: TimeInterval? = nil) {
        guard isInitialized else { return }

        if uploadInProgress {
            #if DEBUG
            print("⏭️ [Logger] upload already in progress")
            #endif
            return
        }

        guard !logBuffer.isEmpty else { return }

        uploadInProgress = true
        lastUploadAttemptTimeMs = nowMs()

        let batch = Array(logBuffer.prefix(min(logBuffer.count, maxBatchSize)))
        let payload = batch.map { $0.toBackendEntry(fallbackUserId: currentUserIdFallback()) }

        let semaphore = DispatchSemaphore(value: 0)
        var completionResult: Result<LogCreateResponse, APIError>?

        repository.sendLogs(payload) { result in
            completionResult = result
            semaphore.signal()
        }

        if let timeoutSeconds {
            _ = semaphore.wait(timeout: .now() + timeoutSeconds)
        } else {
            semaphore.wait()
        }

        // If timed out and completionResult is nil -> treat as failure without clearing buffer
        if completionResult == nil {
            #if DEBUG
            print("⏱️ [Logger] upload timeout")
            #endif
            handleUploadFailure(forceClear: forceClear)
            uploadInProgress = false
            return
        }

        switch completionResult! {
        case .success:
            consecutiveFailures = 0

            // remove uploaded
            let uploadedCount = batch.count
            for _ in 0..<uploadedCount {
                guard !logBuffer.isEmpty else { break }
                let removed = logBuffer.removeFirst()
                currentBufferBytes -= removed.estimatedSizeBytes()
            }

            // delete backup if buffer is empty
            if logBuffer.isEmpty { deleteBackupIfExists() }

            #if DEBUG
            print("✅ [Logger] uploaded \(uploadedCount) logs")
            #endif

        case .failure(let err):
            #if DEBUG
            print("⚠️ [Logger] upload failed: \(err.localizedDescription)")
            #endif
            handleUploadFailure(forceClear: forceClear)
        }

        uploadInProgress = false
    }

    private func handleUploadFailure(forceClear: Bool) {
        consecutiveFailures += 1
        let kb = currentBufferBytes / 1024

        if forceClear || consecutiveFailures >= maxRetryAttempts {
            #if DEBUG
            print("❌ [Logger] max failures or forceClear @ \(kb)KB -> clearing buffer")
            #endif
            logBuffer.removeAll()
            currentBufferBytes = 0
            consecutiveFailures = 0
            deleteBackupIfExists()
        } else {
            let nextDelay = calculateBackoffDelayMs()
            #if DEBUG
            print("⚠️ [Logger] will retry in \(nextDelay / 1000)s (attempt \(consecutiveFailures)/\(maxRetryAttempts))")
            #endif
        }
    }

    // MARK: - Backup / restore (Android buffer_backup.json)

    private func startPeriodicBackup() {
        backupTimer?.cancel()
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + backupInterval, repeating: backupInterval)
        t.setEventHandler { [weak self] in
            self?.backupBufferToDisk()
        }
        backupTimer = t
        t.resume()
    }

    private func startPeriodicUploadCheck() {
        flushTimer?.cancel()
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + flushInterval, repeating: flushInterval)
        t.setEventHandler { [weak self] in
            guard let self else { return }
            self.checkAndUploadIfNeeded(priority: false)
        }
        flushTimer = t
        t.resume()
    }

    private func backupBufferToDisk() {
        guard isInitialized, !logBuffer.isEmpty else { return }

        do {
            let wrapper = BufferBackup(
                logsArray: logBuffer,
                backupTimestamp: nowMs(),
                bufferSizeKB: currentBufferBytes / 1024,
                consecutiveFailures: consecutiveFailures
            )

            let data = try JSONEncoder().encode(wrapper)
            try data.write(to: backupFile, options: [.atomic])

            #if DEBUG
            print("💾 [Logger] backed up \(logBuffer.count) logs (\(currentBufferBytes / 1024)KB) -> \(backupFile.lastPathComponent)")
            #endif
        } catch {
            #if DEBUG
            print("❌ [Logger] backup failed: \(error)")
            #endif
        }
    }

    private func restoreBackupBuffer() {
        guard isInitialized else { return }
        guard FileManager.default.fileExists(atPath: backupFile.path) else {
            #if DEBUG
            print("ℹ️ [Logger] no backup file")
            #endif
            return
        }

        do {
            let data = try Data(contentsOf: backupFile)
            let wrapper = try JSONDecoder().decode(BufferBackup.self, from: data)

            logBuffer = wrapper.logsArray
            consecutiveFailures = wrapper.consecutiveFailures
            currentBufferBytes = logBuffer.reduce(0) { $0 + $1.estimatedSizeBytes() }

            #if DEBUG
            print("📥 [Logger] restored \(logBuffer.count) logs (failures: \(consecutiveFailures))")
            #endif

            // try to upload restored logs
            checkAndUploadIfNeeded(priority: false)
        } catch {
            #if DEBUG
            print("❌ [Logger] restore failed: \(error) -> deleting backup")
            #endif
            deleteBackupIfExists()
        }
    }

    private func deleteBackupIfExists() {
        try? FileManager.default.removeItem(at: backupFile)
    }

    // MARK: - Crash handling (best-effort; primary goal: persist like Android)

    private func setupCrashHandling() {
        // mark "app_crashed" = true each run; cleared on terminate
        if UserDefaults.standard.bool(forKey: "app_crashed") {
            #if DEBUG
            print("🔥 [Logger] previous crash detected -> try upload")
            #endif
            // try upload on next launch
            uploadLogs(forceClear: false, timeoutSeconds: 5)
            UserDefaults.standard.set(false, forKey: "app_crashed")
        }

        UserDefaults.standard.set(true, forKey: "app_crashed")

        NSSetUncaughtExceptionHandler { exception in
            let msg = "App crashed: \(exception.name.rawValue) | \(exception.reason ?? "Unknown")"
            Logger.shared.queue.sync {
                let crash = InternalLogEntry(
                    type: .crash,
                    form: .app,
                    message: msg,
                    timeTakenMs: 0,
                    user: ""
                )
                Logger.shared.logBuffer.append(crash)
                Logger.shared.currentBufferBytes += crash.estimatedSizeBytes()
                Logger.shared.backupBufferToDisk()
                Logger.shared.uploadLogs(forceClear: false, timeoutSeconds: 5)
            }
        }
    }

    // MARK: - App lifecycle

    private func observeAppLifecycle() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }

    @objc private func appDidEnterBackground() {
        queue.async {
            self.backupBufferToDisk()
            self.uploadOnAppClose()
        }
    }

    @objc private func appWillTerminate() {
        UserDefaults.standard.set(false, forKey: "app_crashed")
        queue.async {
            self.backupBufferToDisk()
            self.uploadOnAppClose()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        flushTimer?.cancel()
        backupTimer?.cancel()
    }

    // MARK: - Helpers

    private func truncate(_ s: String?, max: Int) -> String? {
        guard let s else { return nil }
        if s.count <= max { return s }
        return String(s.prefix(max)) + "..."
    }

    private func buildErrorMessage(message: String, error: Error?) -> String {
        guard let error else { return message }
        return "\(message) \(String(describing: error))"
    }

    private func nowMs() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }

    private func currentUserIdFallback() -> String {
        // Mirror Android LogsRepository: fallback to stored userId if payload user blank :contentReference[oaicite:3]{index=3}
        return UserSession.shared.currentUser?.userId ?? "UNKNOWN"
    }

    private func console(_ level: String, _ tag: String, _ msg: String) {
        #if DEBUG
        print("[\(level)] \(tag): \(msg)")
        #endif
    }
}
