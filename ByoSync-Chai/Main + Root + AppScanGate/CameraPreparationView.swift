//
//  CameraPreparationView.swift
//  ByoSync-User
//
//  Created by Hari's Mac on 30.12.2025.
//

import Foundation
import SwiftUI
internal import AVFoundation

// Camera preparation view - handles permissions and pre-initialization
struct CameraPreparationView: View {
    let onReady: () -> Void
    
    @State private var permissionStatus: PermissionStatus = .checking
    @State private var isPreparingCamera = false
    
    private enum PermissionStatus {
        case checking, granted, denied, restricted
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(UIColor.systemGroupedBackground),
                    Color(UIColor.secondarySystemGroupedBackground)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
              
                ProgressView()
                Text(statusMessage)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                if permissionStatus == .denied || permissionStatus == .restricted {
                    Button("Open Settings") {
                        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(settingsUrl)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 16)
                }
            }
            .padding()
        }
        .onAppear {
            checkAndRequestCameraPermission()
        }
    }
    
    private var statusMessage: String {
        switch permissionStatus {
        case .checking:
            return "Checking permissions..."
        case .granted:
            return isPreparingCamera ? "Preparing camera..." : "Wait a moment.."
        case .denied:
            return "Camera access is required.\nPlease enable it in Settings."
        case .restricted:
            return "Camera access is restricted on this device."
        }
    }
    
    private func checkAndRequestCameraPermission() {
        print("📸 Checking camera permission status")
        
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            print("✅ Camera already authorized")
            permissionStatus = .granted
            prepareCamera()
            
        case .notDetermined:
            print("❓ Camera permission not determined, requesting...")
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        print("✅ Camera permission granted")
                        permissionStatus = .granted
                        prepareCamera()
                    } else {
                        print("❌ Camera permission denied")
                        permissionStatus = .denied
                    }
                }
            }
            
        case .denied:
            print("❌ Camera permission previously denied")
            permissionStatus = .denied
            
        case .restricted:
            print("⚠️ Camera access restricted")
            permissionStatus = .restricted
            
        @unknown default:
            print("⚠️ Unknown camera permission status")
            permissionStatus = .denied
        }
    }
    
    private func prepareCamera() {
        print("🎬 Starting camera preparation")
        isPreparingCamera = true
        
        // Prepare camera session on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            print("🔧 Initializing camera session...")
            
            // Simulate/perform camera initialization
            let captureSession = AVCaptureSession()
            captureSession.sessionPreset = .high
            
            // Check if camera is available
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                print("❌ No camera device found")
                DispatchQueue.main.async {
                    isPreparingCamera = false
                    permissionStatus = .denied
                }
                return
            }
            
            print("✅ Camera device found: \(videoDevice.localizedName)")
            
            // Small delay to ensure everything is ready
            Thread.sleep(forTimeInterval: 0.3)
            
            DispatchQueue.main.async {
                print("✅ Camera preparation complete")
                isPreparingCamera = false
                
                // Smooth transition to scan view
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onReady()
                }
            }
        }
    }
}
