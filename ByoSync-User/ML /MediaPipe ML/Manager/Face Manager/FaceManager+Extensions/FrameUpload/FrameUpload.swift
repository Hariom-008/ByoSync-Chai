import Foundation
import UIKit
import CoreImage

extension FaceManager {

    // Convert a pixel buffer to UIImage
    func pixelBufferToUIImage(_ pixelBuffer: CVPixelBuffer) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()

        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            print("❌ [ImageConversion] Failed to create CGImage from pixel buffer")
            return nil
        }

        let image = UIImage(cgImage: cgImage, scale: UIScreen.main.scale, orientation: .up)
        print("✅ [ImageConversion] Successfully converted pixel buffer to UIImage - Size: \(image.size)")
        return image
    }

    func enqueueAcceptedFrameUpload(frameIndex: Int, pixelBuffer: CVPixelBuffer) {
        let ts = lastDetectionTimestampMs
        print("📤 [Upload] Starting upload for frame \(frameIndex) at timestamp \(ts)ms")

        // Create a tracking row immediately (so UI can show progress)
        let tracking = AcceptedFrameUpload(frameIndex: frameIndex, timestampMs: ts)
        acceptedFrameUploads.append(tracking)
        let trackingId = tracking.id
        
        print("📊 [Upload] Created tracking ID: \(trackingId) | Total uploads tracked: \(acceptedFrameUploads.count)")

        // Convert pixel buffer to image
        guard let image = pixelBufferToUIImage(pixelBuffer) else {
            print("❌ [Upload] Frame \(frameIndex) - Image conversion failed")
            if let idx = acceptedFrameUploads.firstIndex(where: { $0.id == trackingId }) {
                acceptedFrameUploads[idx].error = "Image conversion failed"
            }
            return
        }
        
        print("✅ [Upload] Frame \(frameIndex) - Image ready for upload (Size: \(image.size))")

        // Upload off the main thread, with concurrency limit
        Task.detached { [weak self] in
            guard let self else {
                print("❌ [Upload] Frame \(frameIndex) - FaceManager deallocated")
                return
            }
            
            print("⏳ [Upload] Frame \(frameIndex) - Waiting for semaphore...")
            self.frameUploadSemaphore.wait()
            print("🚀 [Upload] Frame \(frameIndex) - Semaphore acquired, starting upload...")
            
            defer {
                self.frameUploadSemaphore.signal()
                print("✅ [Upload] Frame \(frameIndex) - Semaphore released")
            }

            do {
                print("☁️ [Upload] Frame \(frameIndex) - Uploading to Cloudinary...")

                let device = DeviceIdentity.resolve()
                let unix = Int(Date().timeIntervalSince1970)
                let fileName = "\(device)_\(unix)_\(frameIndex).jpg"

                let url = try await CloudinaryManager.shared.uploadImageAsFile(
                    image,
                    fileName: fileName,
                    folder: "accepted_frames"
                )

                print("🎉 [Upload] Frame \(frameIndex) - Upload successful! URL: \(url)")

                await MainActor.run {
                    if let idx = self.acceptedFrameUploads.firstIndex(where: { $0.id == trackingId }) {
                        self.acceptedFrameUploads[idx].url = url
                    }
                }
            } catch {
                print("❌ [Upload] Frame \(frameIndex) - Upload failed: \(error.localizedDescription)")
                await MainActor.run {
                    if let idx = self.acceptedFrameUploads.firstIndex(where: { $0.id == trackingId }) {
                        self.acceptedFrameUploads[idx].error = "\(error)"
                        print("❌ [Upload] Frame \(frameIndex) - Error saved to tracking array")
                    } else {
                        print("⚠️ [Upload] Frame \(frameIndex) - Tracking ID not found in array for error update")
                    }
                }
            }
        }
    }
}
