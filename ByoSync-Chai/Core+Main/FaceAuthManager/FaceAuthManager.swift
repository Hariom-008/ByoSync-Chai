// FaceAuthManager.swift
import SwiftUI
import Combine
enum FaceAuthMode {
    case registration
    case verification
}

final class FaceAuthManager: ObservableObject {
    static let shared = FaceAuthManager()
    
    @Published var currentMode: FaceAuthMode = .verification
    
    private init() {}
    
    func setRegistrationMode() {
        #if DEBUG
        print("📸 [FaceAuthManager] Mode set to: Registration")
        #endif
        currentMode = .registration
    }
    
    func setVerificationMode() {
        #if DEBUG
        print("🔐 [FaceAuthManager] Mode set to: Verification")
        #endif
        currentMode = .verification
    }
    
    func reset() {
        currentMode = .registration
    }
}
