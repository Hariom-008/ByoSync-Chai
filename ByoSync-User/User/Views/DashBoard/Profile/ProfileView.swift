import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var userSession = UserSession.shared
    
    @StateObject private var viewModel: ProfileViewModel
    @State private var showEditProfile: Bool = false
    @State private var openTestinLinkedDeviceView = false
    @State private var openLocationTestingView: Bool = false
    @State private var openSettingView: Bool = false
    @State private var hasLoadedProfilePicture = false
    
    @State var testing :Bool = false
    
    @EnvironmentObject private var languageManager: LanguageManager
    
    
    // MARK: - Initialization with Dependency Injection
    init(
        getUserDataRepository: GetUserDataRepositoryProtocol = GetUserDataRepository(),
        logOutRepository: LogOutRepositoryProtocol = LogOutRepository()
    ) {
        _viewModel = StateObject(
            wrappedValue: ProfileViewModel(
                getUserDataRepository: getUserDataRepository,
                logOutRepository: logOutRepository
            )
        )
        print("🏗️ [VIEW] ProfileView initialized")
    }
    
    var body: some View {
        ZStack {
            // Modern gradient background
            LinearGradient(
                colors: [
                    Color(hex: "F5F7FA"),
                    Color(hex: "E8ECF4")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    profileHeaderCard
                    personalInfoCard
                    menuSection
                }
                .padding(.bottom, 100)
            }
            
            // Loading overlay
            if viewModel.isLoading {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .overlay(
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "4B548D")))
                                .scaleEffect(1.5)
                            
                            Text(L("refreshing_profile"))
                                .foregroundColor(.primary)
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .padding(32)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white)
                                .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
                        )
                    )
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button {
                        print("📱 [VIEW] Linked devices button tapped")
                        openTestinLinkedDeviceView.toggle()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "iphone.gen3")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(Color(hex: "4B548D"))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color(hex: "4B548D").opacity(0.1))
                        )
                    }
                    
                    Button {
                        print("⚙️ [VIEW] Settings button tapped")
                        openSettingView.toggle()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(Color(hex: "4B548D"))
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(Color(hex: "4B548D").opacity(0.1))
                            )
                    }
                }
            }
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView()
        }
        .sheet(isPresented: $openTestinLinkedDeviceView) {
            LinkedDevicesView()
        }
        .sheet(isPresented: $openLocationTestingView) {
            LocationTestView()
        }
        .fullScreenCover(isPresented: $openSettingView) {
            SettingsView()
        }
        .alert(viewModel.alertTitle, isPresented: $viewModel.showAlert) {
            Button(L("ok"), role: .cancel) {}
        } message: {
            Text(viewModel.alertMessage)
        }
        // ✅ React to profile picture changes
        .onChange(of: userSession.userProfilePicture) { oldValue, newValue in
            print("🖼️ [VIEW] Profile picture changed: \(newValue)")
            viewModel.loadProfilePicture()
        }
        // ✅ React to user data changes
        .onChange(of: userSession.currentUser?.email) { oldValue, newValue in
            print("📧 [VIEW] User email changed")
        }
        .onAppear {
            print("📱 [VIEW] ProfileView appeared")
            if !hasLoadedProfilePicture {
                viewModel.loadProfilePicture()
                hasLoadedProfilePicture = true
            }
        }
    }
    
    // MARK: - Profile Header Card
    private var profileHeaderCard: some View {
        VStack(spacing: 20) {
            // Profile Picture with better styling
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: viewModel.profilePic) { phase in
                    switch phase {
                    case .empty:
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.orange.opacity(0.6), Color.orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.white)
                            )
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 4)
                            )
                            .shadow(color: Color(hex: "4B548D").opacity(0.3), radius: 15, y: 8)
                    case .failure:
                        Circle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 120, height: 120)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)
                            )
                    @unknown default:
                        EmptyView()
                    }
                }

                // Verified badge
                if userSession.isEmailVerified {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 36, height: 36)
                            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                        
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.green, Color.green.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .offset(x: 8, y: 8)
                }
            }
            .padding(.top, 8)
            
            // User Info
            VStack(spacing: 8) {
                Text("\(userSession.currentUser?.firstName ?? "User") \(userSession.currentUser?.lastName ?? "Name")")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Text("\(userSession.currentUser?.email ?? "email@example.com")")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 6) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Text("\(userSession.currentUser?.phoneNumber ?? "No phone")")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Edit Profile Button
            Button {
                print("✏️ [VIEW] Edit profile button tapped")
                showEditProfile = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 16))
                    Text(L("edit_profile"))
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "4B548D"), Color(hex: "5B64A0")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(25)
                .shadow(color: Color(hex: "4B548D").opacity(0.4), radius: 12, y: 6)
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.06), radius: 20, y: 8)
        )
        .padding(.horizontal, 20)
    }
    
    // MARK: - Personal Info Card
    private var personalInfoCard: some View {
        VStack(spacing: 24) {
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "person.text.rectangle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "4B548D"), Color(hex: "6B74A8")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text(L("user_section"))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                Spacer()
            }
            
            VStack(spacing: 16) {
                ProfileInfoRow(
                    icon: "person.fill",
                    label: L("first_name"),
                    value: userSession.currentUser?.firstName ?? "N/A",
                    iconColor: Color(hex: "4B548D")
                )
                
                Divider()
                    .padding(.leading, 60)
                
                ProfileInfoRow(
                    icon: "person.fill",
                    label: L("last_name"),
                    value: userSession.currentUser?.lastName ?? "N/A",
                    iconColor: Color(hex: "6B74A8")
                )
                
                Divider()
                    .padding(.leading, 60)
                
                ProfileInfoRow(
                    icon: "envelope.fill",
                    label: L("email_address"),
                    value: userSession.currentUser?.email ?? "N/A email",
                    iconColor: Color.blue
                )
                
                Divider()
                    .padding(.leading, 60)
                
                ProfileInfoRow(
                    icon: "phone.fill",
                    label: L("phone_number"),
                    value: userSession.currentUser?.phoneNumber ?? "N/A phone",
                    iconColor: Color.green
                )
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.06), radius: 20, y: 8)
        )
        .padding(.horizontal, 20)
    }
    
    // MARK: - Menu Section
    private var menuSection: some View {
        VStack(spacing: 16) {
            // Slide to Logout
            SlideToLogoutButton(
                isDisabled: userSession.thisDeviceIsPrimary
            ) {
                print("🚪 [VIEW] Logout initiated")
                viewModel.performLogout()
            }
            
            if userSession.thisDeviceIsPrimary {
                HStack {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.red)
                    Text("Cannot log out from primary device")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
}

#Preview {
    NavigationStack {
        ProfileView()
    }
}
