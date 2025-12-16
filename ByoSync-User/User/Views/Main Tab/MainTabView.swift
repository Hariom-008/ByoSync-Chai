import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @StateObject var socketManager = SocketIOManager.shared  // Add this
    @State private var selected: MainTab = .home
    @State private var openPayView = false
    @State var hideTabBar: Bool = false
    
    var body: some View {
        NavigationStack {
            ProfileView()
        }
    }
}

