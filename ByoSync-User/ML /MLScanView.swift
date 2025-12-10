import SwiftUI

struct MLScanView: View {
    var onDone: () -> Void
    
    var body: some View {
        FaceDetectionView(onComplete: {
            print("🎯 [MLScanView] onComplete callback received")
            // Ensure we're on the main thread
            DispatchQueue.main.async {
                print("🎯 [MLScanView] Calling onDone on main thread")
                onDone()
            }
        })
        .navigationBarHidden(true)
        .onAppear {
            print("👁️ [MLScanView] View appeared")
        }
        .onDisappear {
            print("👋 [MLScanView] View disappeared")
        }
    }
}
