import SwiftUI
import Combine

// MARK: - Route Definition
enum Route: Hashable, Identifiable {

    // ✅ UPDATED CHAI FLOW
    case fetchUserByPhone
    case mlScan(userId: String, deviceKeyHash: String)
    case claimChai(userId: String, deviceKeyHash: String)
    case chaiUpdate(userId: String)

    // (keep old ones if you still use them elsewhere)
    case authentication
    case enterNumber
    case login
    case registerUser(phoneNumber: String)
    case userConsent
    case cameraPreparation
    case mainTab
    case profile
    case settings

    var id: String {
        switch self {
        case .fetchUserByPhone:
            return "fetchUserByPhone"

        case .mlScan(let userId, let deviceKeyHash):
            return "mlScan-\(userId)-\(deviceKeyHash)"

        case .claimChai(let userId, let deviceKeyHash):
            return "claimChai-\(userId)-\(deviceKeyHash)"

        case .chaiUpdate(let userId):
            return "chaiUpdate-\(userId)"

        // old routes
        case .authentication: return "authentication"
        case .enterNumber: return "enterNumber"
        case .login: return "login"
        case .registerUser(let phoneNumber): return "registerUser-\(phoneNumber)"
        case .userConsent: return "userConsent"
        case .cameraPreparation: return "cameraPreparation"
        case .mainTab: return "mainTab"
        case .profile: return "profile"
        case .settings: return "settings"
        }
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Route, rhs: Route) -> Bool { lhs.id == rhs.id }
}

// MARK: - Presentation Style
enum PresentationStyle {
    case push
    case sheet
    case fullScreenCover
}

// MARK: - Router Class
final class Router: ObservableObject {
    @Published var path = NavigationPath()
    @Published var presentedSheet: Route?
    @Published var presentedFullScreen: Route?

    func navigate(to route: Route, style: PresentationStyle = .push) {
        print("🧭 [ROUTER] Navigating to: \(route.id) with style: \(style)")
        switch style {
        case .push:
            path.append(route)
        case .sheet:
            presentedSheet = route
        case .fullScreenCover:
            presentedFullScreen = route
        }
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path.removeLast(path.count)
    }

    func dismissSheet() { presentedSheet = nil }
    func dismissFullScreen() { presentedFullScreen = nil }

    func replace(with route: Route) {
        if !path.isEmpty { path.removeLast() }
        path.append(route)
    }

    func reset() {
        path = NavigationPath()
        presentedSheet = nil
        presentedFullScreen = nil
    }
}
