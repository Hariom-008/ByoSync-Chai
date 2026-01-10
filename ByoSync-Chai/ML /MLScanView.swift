import SwiftUI

struct MLScanView: View {
    let userId: String
    let deviceKeyHash: String

    @EnvironmentObject var router: Router
    @EnvironmentObject var faceAuthManager: FaceAuthManager

    var body: some View {
        ZStack(alignment: .topLeading) {
            FaceDetectionView(
                authToken: UserDefaults.standard.string(forKey: "token") ?? "",
                onComplete: {
                    print("🎯 [MLScanView] verification success → ClaimChaiView")
                    DispatchQueue.main.async {
                        router.replace(with: .claimChai(userId: userId, deviceKeyHash: deviceKeyHash))
                    }
                }
            )
            .environmentObject(faceAuthManager)
            .environmentObject(router)
            .navigationBarHidden(true)

            Button {
                router.pop()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.black.opacity(0.45))
                    .clipShape(Circle())
                    .padding(.top, 14)
                    .padding(.leading, 14)
            }
        }
    }
}

