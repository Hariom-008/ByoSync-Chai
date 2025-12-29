// FaceAuthManager.swift
import SwiftUI
import Combine

enum FaceAuthMode {
    case registration  // 80 frames
    case verification  // 20 frames
}

final class FaceAuthManager: ObservableObject {
    static let shared = FaceAuthManager()
    
    @Published var currentMode: FaceAuthMode = .verification
    
    private init() {}
    
    func setRegistrationMode() {
        print("📸 [FaceAuthManager] Mode set to: Registration")
        currentMode = .registration
    }
    
    func setVerificationMode() {
        print("🔐 [FaceAuthManager] Mode set to: Verification")
        currentMode = .verification
    }
    
    func reset() {
        currentMode = .registration
    }
}
