import SwiftUI

struct MLScanView: View {
    var onDone: () -> Void
    @EnvironmentObject var faceAuthManager: FaceAuthManager
    
    var body: some View {
        FaceDetectionView(authToken: UserDefaults.standard.string(forKey: "token") ?? "",onComplete: {
            print("🎯 [MLScanView] onComplete callback received")
           
            print("🎯[MLScanView] deviceKey:\( DeviceIdentity.resolve())")
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
