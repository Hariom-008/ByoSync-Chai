import UserNotifications
import UniformTypeIdentifiers

final class NotificationService: UNNotificationServiceExtension {

    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        self.bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        guard let content = bestAttemptContent else {
            contentHandler(request.content)
            return
        }

        print("📬 Notification Service Extension triggered")
        print("📦 UserInfo: \(content.userInfo)")

        // Extract image URL from notification payload
        // Firebase can send this in different keys, check both
        var imageURLString: String?
        if let customImage = content.userInfo["image"] as? String {
            imageURLString = customImage
        } else if let fcmOptions = content.userInfo["fcm_options"] as? [String: Any],
                  let image = fcmOptions["image"] as? String {
            imageURLString = image
        }

        guard let imageURLString = imageURLString,
              let url = URL(string: imageURLString) else {
            print("⚠️ No image URL found, delivering text-only notification")
            contentHandler(content)
            return
        }

        print("🖼️ Downloading image from: \(url.absoluteString)")

        // Download image with timeout
        downloadImage(from: url) { [weak self] localURL in
            guard let self = self, let content = self.bestAttemptContent else {
                contentHandler(request.content)
                return
            }

            if let localURL = localURL {
                print("✅ Image downloaded successfully")
                self.attachMedia(to: content, from: localURL)
            } else {
                print("❌ Failed to download image")
            }

            contentHandler(content)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        print("⏰ Extension time expiring, delivering notification")
        if let handler = contentHandler, let content = bestAttemptContent {
            handler(content)
        }
    }

    // MARK: - Helper Methods

    private func downloadImage(from url: URL, completion: @escaping (URL?) -> Void) {
        let session = URLSession(configuration: .default)
        
        let task = session.dataTask(with: url) { data, response, error in
            guard let data = data,
                  error == nil,
                  let mimeType = response?.mimeType else {
                print("❌ Download failed: \(error?.localizedDescription ?? "Unknown error")")
                completion(nil)
                return
            }

            // Determine file extension
            let ext = self.fileExtension(fromMimeType: mimeType, url: url)
            
            // Create temporary file URL with proper extension
            let tmpDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            let tmpFileURL = tmpDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(ext)

            do {
                try data.write(to: tmpFileURL, options: .atomic)
                print("💾 Image saved to: \(tmpFileURL.path)")
                completion(tmpFileURL)
            } catch {
                print("❌ Failed to write image: \(error.localizedDescription)")
                completion(nil)
            }
        }
        
        task.resume()
    }

    private func attachMedia(to content: UNMutableNotificationContent, from url: URL) {
            do {
                // ✅ Use the correct options dictionary type and constant key
                var options: [AnyHashable: Any]? = nil

                if #available(iOS 14.0, *) {
                    let ext = url.pathExtension.lowercased()
                    if let utType = utType(for: ext) {
                        // UNNotificationAttachmentOptionsTypeHintKey is a String constant
                        options = [UNNotificationAttachmentOptionsTypeHintKey: utType.identifier]
                    }
                }

                let attachment = try UNNotificationAttachment(
                    identifier: "notification-image",
                    url: url,
                    options: options
                )

                content.attachments = [attachment]
                print("🎉 Media attachment added successfully")

            } catch {
                print("❌ Failed to create attachment: \(error.localizedDescription)")
            }
        }

        // MARK: - File Type Helpers

        @available(iOS 14.0, *)
        private func utType(for ext: String) -> UTType? {
            switch ext.lowercased() {
            case "png":  return .png
            case "gif":  return .gif
            case "jpg", "jpeg": return .jpeg
            case "webp": return .webP   // iOS 14+
            default:     return nil
            }
        }

    // MARK: - File Type Helpers

    private func fileExtension(fromMimeType mimeType: String, url: URL) -> String {
        if mimeType.contains("png") { return "png" }
        if mimeType.contains("jpeg") || mimeType.contains("jpg") { return "jpg" }
        if mimeType.contains("gif") { return "gif" }
        if mimeType.contains("webp") { return "webp" }
        
        // Fallback to URL extension
        let ext = url.pathExtension.lowercased()
        return ext.isEmpty ? "jpg" : ext
    }
}
