import Foundation
import Cloudinary
import UIKit

enum CloudinaryUploadError: Error {
    case jpegEncodingFailed
    case missingSecureURL
    case sdkError(String)
}

final class CloudinaryManager {
    static let shared = CloudinaryManager()

    private let cloudinary: CLDCloudinary
    private let uploadPreset: String = "unsigned_profile_upload"

    private init() {
        let config = CLDConfiguration(cloudName: "dtf5st5gk", secure: true)
        self.cloudinary = CLDCloudinary(configuration: config)
    }

    /// Upload image as a temp JPG file so Cloudinary can use the filename (use_filename preset behavior).
    /// - Returns: secure_url
    func uploadImageAsFile(
        _ image: UIImage,
        fileName: String,
        folder: String = "accepted_frames"
    ) async throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            throw CloudinaryUploadError.jpegEncodingFailed
        }

        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: fileURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let params = CLDUploadRequestParams()
            .setFolder(folder)
            .setResourceType(.image)

        return try await withCheckedThrowingContinuation { continuation in
            cloudinary.createUploader().upload(
                url: fileURL,
                uploadPreset: uploadPreset,
                params: params
            ) { response, error in
                if let error = error {
                    continuation.resume(throwing: CloudinaryUploadError.sdkError(error.localizedDescription))
                    return
                }
                guard let secureUrl = response?.secureUrl, !secureUrl.isEmpty else {
                    continuation.resume(throwing: CloudinaryUploadError.missingSecureURL)
                    return
                }
                continuation.resume(returning: secureUrl)
            }
        }
    }
}
