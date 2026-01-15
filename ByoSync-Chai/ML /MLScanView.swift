import SwiftUI

struct MLScanView: View {
    var onDone: () -> Void
    let userId: String
    let deviceKeyHash: String
    
    let token:Int?

    @EnvironmentObject var faceAuthManager: FaceAuthManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        FaceDetectionView(
            authToken: UserDefaults.standard.string(forKey: "token") ?? "",
            onComplete: {
                DispatchQueue.main.async {
                    dismiss()   // <-- pops MLScanView correctly
                    onDone()    // parent can now present ClaimChaiView safely
                }
            },
            userId: userId,
            deviceKeyHash: deviceKeyHash, token: token ?? 0
        )
        .navigationBarHidden(true)
    }
}
