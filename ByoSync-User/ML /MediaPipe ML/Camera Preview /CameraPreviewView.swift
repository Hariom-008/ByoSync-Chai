import SwiftUI
import AVFoundation

struct MediapipeCameraPreviewView: UIViewRepresentable {
    let cameraManager: CameraManager
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black

        // ✅ Properly initialize and attach the preview layer
        let previewLayer = AVCaptureVideoPreviewLayer(session: cameraManager.captureSession)
        previewLayer.videoGravity = .resizeAspectFill   // maintains aspect, fills screen
        previewLayer.connection?.videoOrientation = .portrait
        previewLayer.frame = view.bounds

        view.layer.addSublayer(previewLayer)
        cameraManager.previewLayer = previewLayer       // so CameraManager can reference it

        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // ✅ Ensure preview always fills the SwiftUI view size
        DispatchQueue.main.async {
            cameraManager.previewLayer?.frame = uiView.bounds
        }
    }
}

