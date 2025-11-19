//
//  RouterView.swift
//  ByoSync-User
//
//  Created by Hari's Mac on 19.11.2025.
//
import SwiftUI

struct RouterView<Content: View>: View {
    @StateObject private var router = Router()
    let rootView: Content
    
    init(@ViewBuilder rootView: () -> Content) {
        self.rootView = rootView()
    }
    
    var body: some View {
        NavigationStack(path: $router.path) {
            rootView
                .navigationDestination(for: Route.self) { route in
                    routeView(for: route)
                }
        }
        .sheet(item: $router.presentedSheet) { route in
            NavigationStack {
                routeView(for: route)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(action: { router.dismissSheet() }) {
                                Image(systemName: "xmark")
                                    .foregroundColor(.primary)
                            }
                        }
                    }
            }
            .environmentObject(router)
        }
        .fullScreenCover(item: $router.presentedFullScreen) { route in
            routeView(for: route)
                .environmentObject(router)
        }
        .environmentObject(router)
    }
    
    @ViewBuilder
    private func routeView(for route: Route) -> some View {
        switch route {
        case .authentication:
            AuthenticationView()
            
        case .enterNumber:
            EnterNumberView()
            
        case .otpVerification(let phoneNumber, let viewModel):
            OTPVerificationView(phoneNumber: phoneNumber, viewModel: viewModel)
            
        case .login:
            LoginView()
            
        case .registerUser(let phoneNumber):
            RegisterUserView(phoneNumber: .constant(phoneNumber))
            
        case .userConsent:
            UserConsentView(onComplete: {
                router.navigate(to: .cameraPreparation, style: .fullScreenCover)
            })
            
        case .cameraPreparation:
            CameraPreparationView(onReady: {
                router.replace(with: .mlScan)
            })
            
        case .mlScan:
            MLScanView(onDone: {
                router.dismissFullScreen()
                router.navigate(to: .mainTab, style: .push)
            })
            
        case .mainTab:
            MainTabView()
            
        case .profile:
            Text("Profile View") // Replace with your ProfileView
            
        case .settings:
            Text("Settings View") // Replace with your SettingsView
        }
    }
}
