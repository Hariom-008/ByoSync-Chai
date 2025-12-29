//
//  FrameUpload.swift
//  ByoSync-User
//
//  Created by Hari's Mac on 29.12.2025.
//

import Foundation
import UIKit
import CoreImage

extension FaceManager {

    // Convert the current preview buffer to UIImage
    // Note: orientation may need tweaking depending on your pipeline.
    func currentFrameUIImage() -> UIImage? {
        guard let pixelBuffer = latestPixelBuffer else { return nil }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()

        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }

        // If your uploaded images look rotated/mirrored, adjust orientation here.
        // Common front-cam choices: .rightMirrored or .leftMirrored
        return UIImage(cgImage: cgImage, scale: UIScreen.main.scale, orientation: .rightMirrored)
    }

    func enqueueAcceptedFrameUpload(frameIndex: Int) {
        let ts = lastDetectionTimestampMs

        // Create a tracking row immediately (so UI can show progress)
        let tracking = AcceptedFrameUpload(frameIndex: frameIndex, timestampMs: ts)
        acceptedFrameUploads.append(tracking)
        let trackingId = tracking.id

        guard let image = currentFrameUIImage() else {
            if let idx = acceptedFrameUploads.firstIndex(where: { $0.id == trackingId }) {
                acceptedFrameUploads[idx].error = "No pixelBuffer / image conversion failed"
            }
            return
        }

        // Upload off the main thread, with concurrency limit
        Task.detached { [weak self] in
            guard let self else { return }
            self.frameUploadSemaphore.wait()
            defer { self.frameUploadSemaphore.signal() }

            do {
                let url = try await CloudinaryManager.shared.uploadImage(image)
                await MainActor.run {
                    if let idx = self.acceptedFrameUploads.firstIndex(where: { $0.id == trackingId }) {
                        self.acceptedFrameUploads[idx].url = url
                    }
                }
            } catch {
                await MainActor.run {
                    if let idx = self.acceptedFrameUploads.firstIndex(where: { $0.id == trackingId }) {
                        self.acceptedFrameUploads[idx].error = "\(error)"
                    }
                }
            }
        }
    }
}
