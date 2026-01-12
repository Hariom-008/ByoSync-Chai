//
//  ProfilePictureViewModel.swift
//  ByoSync
//
//  Created by Hari's Mac on 23.10.2025.
//

import Foundation
import SwiftUI
import PhotosUI
import Combine

@MainActor
final class ProfilePictureViewModel: ObservableObject {
    @Published var updateState: ProfileUpdateState = .idle
    @Published var selectedImage: UIImage? = nil
    @Published var uploadedUrl: String?
    
    private let repository: ProfilePictureRepositoryProtocol
    private let cloudinary = CloudinaryManager.shared
    
    init(repository: ProfilePictureRepositoryProtocol = ProfilePictureRepository()) {
        self.repository = repository
        print("🏗️ [VM] ProfilePictureViewModel initialized")
    }
    
    func uploadAndSaveProfilePicture() {
        print("📤 [VM] uploadAndSaveProfilePicture called")
        
        guard let image = selectedImage else {
            print("❌ [VM] No image selected")
            updateState = .error("No image selected.")
            return
        }

        updateState = .updating
        print("⏳ [VM] Starting upload process...")

        Task {
            do {
                // Step 1: Upload to Cloudinary
                print("☁️ [VM] Uploading to Cloudinary...")
               // uploadedUrl = try await cloudinary.uploadImage(image)
                print("✅ [VM] Cloudinary upload successful: \(uploadedUrl ?? "no URL")")
                
                // Step 2: Save URL to UserSession
                if let _ = UserSession.shared.currentUser {
                    UserSession.shared.setProfilePicture(uploadedUrl ?? "")
                    print("✅ [VM] Profile picture saved to UserSession")
                }
                
                // Step 3: Update backend with the new URL
                print("📤 [VM] Updating backend...")
                let message = try await repository.changeProfilePicture(imageUrl: uploadedUrl ?? "")
                print("✅ [VM] Backend update successful: \(message)")

                // Step 4: Update state for UI feedback
                updateState = .success(message)
                print("✅ [VM] Profile picture update complete")
                
            } catch let error as APIError {
                print("❌ [VM] API Error: \(error.localizedDescription)")
                updateState = .error(error.localizedDescription)
            } catch {
                print("❌ [VM] Unexpected error: \(error.localizedDescription)")
                updateState = .error("Unexpected error: \(error.localizedDescription)")
            }
        }
    }
    
    deinit {
        print("♻️ [VM] ProfilePictureViewModel deallocated")
    }
}

enum ProfileUpdateState: Equatable {
    case idle
    case updating
    case success(String)
    case error(String)
}
