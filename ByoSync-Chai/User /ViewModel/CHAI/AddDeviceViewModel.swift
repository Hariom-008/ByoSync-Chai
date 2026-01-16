//
//  AddDeviceViewModel.swift
//

import Foundation
import Combine

@MainActor
final class AddDeviceViewModel: ObservableObject {

    enum State: Equatable {
        case idle
        case loading
        case success(message: String, deviceId: String)
        case failure(message: String)
    }

    @Published private(set) var state: State = .idle

    private let repo: AddDeviceRepositoryProtocol

    init(repo: AddDeviceRepositoryProtocol = AddDeviceRepository.shared) {
        self.repo = repo
    }

    func reset() { state = .idle }

    func addDevice(
        deviceKey: String,
        deviceKeyHash: String,
        deviceName: String,
        deviceData: [String: AnyEncodable] = [:]
    ) {
        state = .loading

        let body = AddDeviceRequestBody(
            deviceKey: deviceKey,
            deviceKeyHash: deviceKeyHash,
            deviceName: deviceName,
            deviceData: deviceData
        )

        repo.addDevice(body: body) { [weak self] result in
            guard let self else { return }

            DispatchQueue.main.async {
                switch result {
                case .success(let res):
                    let msg = res.message ?? "Success"
                    // Treat as success if success==true or statusCode==200
                    let ok = (res.success == true) || (res.statusCode == 200)
                    
                    if ok {
                        print("✅ [AddDeviceViewModel] Device added successfully: \(res.data._id)")
                        self.state = .success(message: msg, deviceId: res.data._id)
                    
                    } else {
                        print("⚠️ [AddDeviceViewModel] API returned non-success: \(msg)")
                        self.state = .failure(message: msg)
                    }

                case .failure(let err):
                    print("❌ [AddDeviceViewModel] API error: \(err.localizedDescription)")
                    self.state = .failure(message: err.localizedDescription)
                }
            }
        }
    }
}
