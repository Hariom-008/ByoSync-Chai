import SwiftUI

/// View that handles route destinations
struct RouteDestinationView {
    /// Maps routes to their corresponding views
    /// Environment objects are passed explicitly to ensure they're available
    static func routeView(for route: Route) -> some View {
        Group {
            switch route {
            case .fetchUserByPhone:
                FetchUserByPhoneView()
                
            case .mlScan(let userId, let deviceKeyHash):
                MLScanView(userId: userId, deviceKeyHash: deviceKeyHash)
                
            case .claimChai(let userId, let deviceKeyHash):
                ClaimChaiFlowView(userId: userId, deviceKeyHash: deviceKeyHash)
                
            case .chaiUpdate(let chai,let userId):
                ChaiUpdateView(chai: chai,userId: userId)
                
            // Legacy routes - add placeholders or actual views
            case .authentication:
                Text("Authentication View")
                    .navigationTitle("Authentication")
                
            case .enterNumber:
                Text("Enter Number View")
                    .navigationTitle("Enter Number")
                
            case .login:
                Text("Login View")
                    .navigationTitle("Login")
                
            case .registerUser(let phoneNumber):
                Text("Register User: \(phoneNumber)")
                    .navigationTitle("Register")
                
            case .userConsent:
                Text("User Consent View")
                    .navigationTitle("Consent")
                
            case .cameraPreparation:
                Text("Camera Preparation View")
                    .navigationTitle("Camera")
                
            case .mainTab:
                Text("Main Tab View")
                    .navigationTitle("Main")
                
            case .profile:
                Text("Profile View")
                    .navigationTitle("Profile")
                
            case .settings:
                Text("Settings View")
                    .navigationTitle("Settings")
            }
        }
    }
}

