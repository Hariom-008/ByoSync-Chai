import SwiftUI

struct MLScanView: View {
    var onDone: () -> Void
    @EnvironmentObject var faceAuthManager: FaceAuthManager
    
    // deviceKey = UserSession.shared.deviceKey
    var body: some View {
        FaceDetectionView(authToken: UserDefaults.standard.string(forKey: "token") ?? "", deviceKey: UserSession.shared.currentUser?.deviceKey ?? "Nil",onComplete: {
            print("🎯 [MLScanView] onComplete callback received")
            print("🎯[MLScanView] deviceKey:\(UserSession.shared.currentUser?.deviceKey ?? "Nil")")
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
