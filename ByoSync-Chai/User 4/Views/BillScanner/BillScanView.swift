//
//  BillScanView.swift
//  ByoSync
//
//  Created by Hari's Mac on 09.10.2025.
//

import SwiftUI
import VisionKit

struct BillScanView: UIViewControllerRepresentable {
    @Environment(\.dismiss) var dismiss

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        var parent: BillScanView

        init(parent: BillScanView) {
            self.parent = parent
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.dismiss()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                           didFinishWith scan: VNDocumentCameraScan) {
            for i in 0..<scan.pageCount {
                let image = scan.imageOfPage(at: i)
                // 🔹 You can save or process this scanned image here
                print("Scanned page \(i + 1)")
            }
            parent.dismiss()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                           didFailWithError error: Error) {
            print("Scanner error: \(error.localizedDescription)")
            parent.dismiss()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}
}


#Preview {
    BillScanView()
}
