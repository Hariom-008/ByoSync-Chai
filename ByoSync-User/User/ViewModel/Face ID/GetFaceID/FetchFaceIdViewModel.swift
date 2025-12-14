import Foundation
import Combine

final class FaceIdFetchViewModel: ObservableObject {
    
    // MARK: - Published State (for UI)
    
    /// Full payload from backend (salt + faceData)
    @Published var faceIdData: GetFaceIdData?
    
    /// Convenience: just the FaceId list (for UI)
    @Published var faceIds: [FaceId] = []
    
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    @Published var hasLoadedOnce: Bool = false
    
    // Optional: if you want to know that request is in-flight and avoid duplicates
    @Published var isRequestInFlight: Bool = false
    
    // MARK: - Dependencies
    
    private let repository: FaceIdFetchRepository
    
    // MARK: - Init
    
    init(repository: FaceIdFetchRepository = .shared) {
        self.repository = repository
    }
    
    // MARK: - Public API (UI-driven)
    
    /// UI-style API (no completion, just updates @Published)
    func fetchFaceIds(for deviceKey: String) {
        guard !deviceKey.isEmpty else {
            setError("Missing device key")
            return
        }
        
        // Avoid firing twice in parallel if you want
        if isRequestInFlight {
            print("⚠️ [FaceIdFetchViewModel] Request already in flight, ignoring duplicate call")
            return
        }
        
        print("🚀 [FaceIdFetchViewModel] Starting fetchFaceIds() for deviceKey length: \(deviceKey.count)")
        
        isLoading = true
        isRequestInFlight = true
        errorMessage = nil
        showError = false
        
        repository.getFaceIds(deviceKey: deviceKey) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                self.isLoading = false
                self.isRequestInFlight = false
                self.hasLoadedOnce = true
                
                switch result {
                case .success(let data):
                    print("✅ [FaceIdFetchViewModel] Successfully fetched FaceId data")
                    print("   • salt: \(data.salt)")
                    print("   • faceData count: \(data.faceData.count)")
                    
                    self.faceIdData = data
                    self.faceIds = data.faceData
                    
                case .failure(let error):
                    print("❌ [FaceIdFetchViewModel] Failed: \(error)")
                    let message = (error as? LocalizedError)?.errorDescription
                        ?? error.localizedDescription
                    self.setError(message)
                }
            }
        }
    }
    
    /// Completion-based API for non-UI callers (e.g. FaceManager)
    func fetchFaceIds(
        for deviceKey: String,
        completion: @escaping (Result<GetFaceIdData, Error>) -> Void
    ) {
        
        guard !deviceKey.isEmpty else {
            let err = NSError(
                domain: "FaceIdFetchViewModel",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Missing device key"]
            )
            setError("Missing device key")
            completion(.failure(err))
            return
        }
        
        if isRequestInFlight {
            print("⚠️ [FaceIdFetchViewModel] Request already in flight, ignoring duplicate call")
            // Return cached value if available
            if let cached = faceIdData {
                completion(.success(cached))
            } else {
                let err = NSError(
                    domain: "FaceIdFetchViewModel",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Request already in flight"]
                )
                completion(.failure(err))
            }
            return
        }
        
        print("🚀 [FaceIdFetchViewModel] (completion) Starting fetchFaceIds() for deviceKey length: \(deviceKey.count)")
        
        isLoading = true
        isRequestInFlight = true
        errorMessage = nil
        showError = false
        
        repository.getFaceIds(deviceKey: deviceKey) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                self.isLoading = false
                self.isRequestInFlight = false
                self.hasLoadedOnce = true
                
                switch result {
                case .success(let data):
                    print("✅ [FaceIdFetchViewModel] (completion) Successfully fetched FaceId data")
                    print("   • salt: \(data.salt)")
                    print("   • faceData count: \(data.faceData.count)")
                    
                    self.faceIdData = data
                    self.faceIds = data.faceData
                    completion(.success(data))
                    
                case .failure(let error):
                    print("❌ [FaceIdFetchViewModel] (completion) Failed: \(error)")
                    let message = (error as? LocalizedError)?.errorDescription
                        ?? error.localizedDescription
                    self.setError(message)
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Convenience for clearing current state (e.g. on logout)
    func resetState() {
        print("🧹 [FaceIdFetchViewModel] Resetting state")
        faceIdData = nil
        faceIds = []
        isLoading = false
        isRequestInFlight = false
        hasLoadedOnce = false
        errorMessage = nil
        showError = false
    }
    
    // MARK: - Private
    
    private func setError(_ message: String) {
        errorMessage = message
        showError = true
    }
}
