import Foundation
import Combine
import SwiftUI
import Alamofire

@MainActor
final class LinkedDevicesViewModel: ObservableObject {
    @Published var devices: [GetDeviceData] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    // MARK: - Dependencies
    private let repository: UserDevicesRepository
    private let userSession: UserSession
    
    // MARK: - Initialization with Dependency Injection
    init(repository: UserDevicesRepository, userSession: UserSession = .shared) {
        self.repository = repository
        self.userSession = userSession
        print("🏗️ [VM] LinkedDevicesViewModel initialized")
    }
   
    // MARK: - Fetch Linked Devices (Callback-based)
    func fetchUserDevices(clearMessages: Bool = true, showErrors: Bool = true) {
        print("📱 [VM] fetchUserDevices called (callback-based)")
        isLoading = true

        if clearMessages {
            errorMessage = nil
            successMessage = nil
        }
        
        repository.getUserDevices { [weak self] result in
            guard let self = self else { return }
            Task { @MainActor in
                self.handleDevicesResult(result, showErrors: showErrors)
            }
        }
    }
    
    // MARK: - Fetch Linked Devices (Async/Await for .refreshable)
    func fetchUserDevices() async {
        print("📱 [VM] fetchUserDevices called (async)")
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        await withCheckedContinuation { continuation in
            repository.getUserDevices { [weak self] result in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                Task { @MainActor in
                    self.handleDevicesResult(result, showErrors: true)
                    continuation.resume()
                }
            }
        }
    }
    
    // MARK: - Change Primary Device
    func changePrimaryDevice(to deviceId: String) {
        print("🔄 [VM] changePrimaryDevice called")
        print("📍 [VM] Device ID: \(deviceId)")
        
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        repository.changePrimaryDevice(deviceId: deviceId) { [weak self] result in
            guard let self = self else { return }
            Task { @MainActor in
                self.handleChangePrimaryResult(result)
            }
        }
    }
    
    // MARK: - Unlink This Device
    func unlinkThisDevice() {
        print("🔗 [VM] unlinkThisDevice called")
        
        isLoading = true
        
        let currentDeviceId = userSession.currentUserDeviceID
        print("📍 [VM] Current Device ID: \(currentDeviceId)")
       
        guard !currentDeviceId.isEmpty else {
            self.errorMessage = "No device ID found."
            isLoading = false
            print("❌ [VM] No device ID found")
            return
        }
        
        repository.unlinkThisDevice(deviceId: currentDeviceId) { [weak self] result in
            guard let self = self else { return }
            Task { @MainActor in
                self.handleUnlinkResult(result)
            }
        }
    }
    
    // MARK: - Unlink Other Device (by device ID)
    func unlinkOtherDevice(deviceId: String) {
        print("🔗 [VM] unlinkOtherDevice called")
        print("📍 [VM] Device ID: \(deviceId)")
        
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        repository.unlinkThisDevice(deviceId: deviceId) { [weak self] result in
            guard let self = self else { return }
            Task { @MainActor in
                self.handleUnlinkResult(result)
            }
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func handleDevicesResult(_ result: Result<[GetDeviceData], APIError>, showErrors: Bool) {
        isLoading = false

        switch result {
        case .success(let devices):
            self.devices = devices
            self.errorMessage = nil
            print("✅ [VM] Loaded \(devices.count) devices successfully")

        case .failure(let error):
            print("❌ [VM] Fetch devices failed: \(error.localizedDescription)")
            
            if showErrors && self.successMessage == nil {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    private func handleChangePrimaryResult(_ result: Result<String, APIError>) {
        switch result {
        case .success(let message):
            self.isLoading = false
            self.successMessage = message
            print("✅ [VM] Primary device changed: \(message)")
            
            // Update user session
            userSession.setThisDevicePrimary(false)
            print("✅ [VM] Updated user primary device status")
            
            // Refresh devices list
            self.fetchUserDevices(clearMessages: false, showErrors: false)

        case .failure(let error):
            self.isLoading = false
            self.errorMessage = error.localizedDescription
            print("❌ [VM] Change primary device failed: \(error.localizedDescription)")
        }
    }
    
    private func handleUnlinkResult(_ result: Result<String, APIError>) {
        self.isLoading = false
        
        switch result {
        case .success(let message):
            self.successMessage = message
            print("✅ [VM] Device unlinked successfully: \(message)")
            
            // Refresh the devices list after successful unlink
            self.fetchUserDevices(clearMessages: false, showErrors: false)
            
        case .failure(let error):
            self.errorMessage = error.localizedDescription
            print("❌ [VM] Unlink device failed: \(error.localizedDescription)")
        }
    }
    
    deinit {
        print("♻️ [VM] LinkedDevicesViewModel deallocated")
    }
}
