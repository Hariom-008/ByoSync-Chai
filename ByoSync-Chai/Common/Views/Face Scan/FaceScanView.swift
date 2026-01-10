////
////  FaceScanView.swift
////  ByoSync
////
////  Created by Hari's Mac on 30.10.2025.
////
//
//import SwiftUI
//import UIKit
//
//struct CameraScanView: UIViewControllerRepresentable {
//    @Environment(\.presentationMode) var presentationMode
//      var onImageCaptured: (UIImage) -> Void
//
//      func makeUIViewController(context: Context) -> UIImagePickerController {
//          let picker = UIImagePickerController()
//          picker.sourceType = .camera
//          picker.delegate = context.coordinator
//          picker.allowsEditing = false
//          picker.modalPresentationStyle = .fullScreen
//          return picker
//      }
//
//      func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
//
//      func makeCoordinator() -> Coordinator {
//          Coordinator(self)
//      }
//
//      class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
//          let parent: CameraScanView
//
//          init(_ parent: CameraScanView) {
//              self.parent = parent
//          }
//
//          func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
//              if let image = info[.originalImage] as? UIImage {
//                  parent.onImageCaptured(image)
//              }
//              parent.presentationMode.wrappedValue.dismiss()
//          }
//
//          func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
//              parent.presentationMode.wrappedValue.dismiss()
//          }
//      }
//}
//
//struct FaceScanView: View {
//    @State private var showCamera = false
//    @State private var capturedImage: UIImage?
//
//    var body: some View {
//        ZStack {
//            if let image = capturedImage {
//                Image(uiImage: image)
//                    .resizable()
//                    .scaledToFit()
//                    .ignoresSafeArea()
//            } else {
//                Color.black.ignoresSafeArea()
//                Text("Tap to Open Camera")
//                    .foregroundColor(.white)
//                    .font(.title)
//            }
//        }
//        .onTapGesture {
//            showCamera = true
//        }
//        .fullScreenCover(isPresented: $showCamera) {
//            CameraScanView { image in
//                capturedImage = image
//            }
//        }
//    }
//}
//
//
//#Preview {
//    FaceScanView()
//}
