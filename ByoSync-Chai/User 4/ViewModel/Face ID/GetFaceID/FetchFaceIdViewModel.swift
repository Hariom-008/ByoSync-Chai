import Foundation
import Combine

final class FaceIdFetchViewModel: ObservableObject {

    @Published var faceIdData: GetFaceIdData?
    @Published var faceIds: [FaceId] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    @Published var hasLoadedOnce: Bool = false
    @Published var isRequestInFlight: Bool = false

    private let repository: FaceIdFetchRepository

    init(repository: FaceIdFetchRepository = .shared) {
        self.repository = repository
    }

    // UI-style (no completion)
    func fetchFaceIds(deviceKeyHash: String) {
        fetchFaceIds(deviceKeyHash: deviceKeyHash) { _ in }
    }

    // ✅ Completion-based overload (THIS is what you want to call from FaceManager)
    func fetchFaceIds(
        deviceKeyHash: String,
        completion: @escaping (Result<GetFaceIdData, Error>) -> Void
    ) {
        guard !deviceKeyHash.isEmpty else {
            setError("Missing deviceKeyHash")
            completion(.failure(NSError(
                domain: "FaceIdFetchViewModel",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Missing deviceKeyHash"]
            )))
            return
        }

        if isRequestInFlight {
            if let cached = faceIdData {
                completion(.success(cached))
            } else {
                completion(.failure(NSError(
                    domain: "FaceIdFetchViewModel",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Request already in flight"]
                )))
            }
            return
        }

        isLoading = true
        isRequestInFlight = true
        errorMessage = nil
        showError = false

        repository.getFaceIds(deviceKeyHash: deviceKeyHash) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }

                self.isLoading = false
                self.isRequestInFlight = false
                self.hasLoadedOnce = true

                switch result {
                case .success(let data):
                    self.faceIdData = data
                    self.faceIds = data.faceData
                    completion(.success(data))

                case .failure(let error):
                    let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    self.setError(message)
                    completion(.failure(error))
                }
            }
        }
    }

    func resetState() {
        faceIdData = nil
        faceIds = []
        isLoading = false
        isRequestInFlight = false
        hasLoadedOnce = false
        errorMessage = nil
        showError = false
    }

    private func setError(_ message: String) {
        errorMessage = message
        showError = true
    }
}
