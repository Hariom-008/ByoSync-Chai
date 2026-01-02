//
//  AddFaceIDViewModel.swift
//  ByoSync-User
//

import Foundation
import Combine

/// ViewModel responsible for managing FaceId upload state
final class FaceIdViewModel: ObservableObject {
    
    // MARK: - Published UI State
    @Published var isUploading: Bool = false
    @Published var uploadSuccess: Bool = false
    
    @Published var showError: Bool = false
    @Published var errorMessage: String? = nil
    
    // Debug info
    @Published var lastSalt: String? = nil
    @Published var lastToken: String? = nil
    @Published var lastUploadedCount: Int = 0
    
    // MARK: - Dependencies
    private let repository: FaceIdRepository
    
    // MARK: - Init
    init(repository: FaceIdRepository = .shared) {
        self.repository = repository
    }
}

// MARK: - PUBLIC API
extension FaceIdViewModel {
    
    /// Upload a **single** FaceId (wraps into array for backend)
    func uploadSingleFaceId(
        helper: String,
        k2: String,
        token: String,
        salt: String
    ) {
        let item = AddFaceIdRequestBody(helper: helper, k2: k2, token: token)
        uploadFaceIdList(salt: salt, list: [item])
        
        // Debug
        lastToken = token
        lastSalt = salt
    }
    
    
    /// Upload **multiple** FaceId records (e.g., 80 enrollment frames)
    func uploadFaceIdList(
        salt: String,
        list: [AddFaceIdRequestBody]
    ) {
        guard !isUploading else { return }
        
        // Reset UI state
        isUploading = true
        uploadSuccess = false
        errorMessage = nil
        showError = false
        
        lastSalt = salt
        lastUploadedCount = list.count
        
        print("\n📤 [FaceIdViewModel] Uploading FaceId list…")
        print("📤 Count: \(list.count)")
        print("📤 Salt: \(salt)")
        
        repository.addFaceIds(
            salt: salt,
            records: list
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                self.isUploading = false
                
                switch result {
                case .success:
                    print("✅ [FaceIdViewModel] FaceId list upload success")
                    self.uploadSuccess = true
                    
                case .failure(let error):
                    print("❌ [FaceIdViewModel] Upload failed: \(error)")
                    self.uploadSuccess = false
                    self.errorMessage = Self.mapError(error)
                    self.showError = true
                }
            }
        }
    }
    
    
    /// Reset flags after UI dismisses banners/alerts
    func resetState() {
        uploadSuccess = false
        showError = false
        errorMessage = nil
    }
}

// MARK: - Helper
extension FaceIdViewModel {
    private static func mapError(_ error: APIError) -> String {
        return "\(error)"
    }
}
