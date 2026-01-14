import Foundation
import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @StateObject private var viewModel: UpdateProfileViewModel
    @StateObject private var pictureViewModel: ProfilePictureViewModel
    @State private var selectedItem: PhotosPickerItem? = nil
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var languageManager: LanguageManager
    
    // State for managing dismissal
    @State private var shouldDismiss = false
    
    // MARK: - Initialization with Dependency Injection
    init(
        updateRepository: ProfileUpdateRepositoryProtocol = ProfileUpdateRepository(),
        pictureRepository: ProfilePictureRepositoryProtocol = ProfilePictureRepository()
    ) {
        _viewModel = StateObject(
            wrappedValue: UpdateProfileViewModel(repository: updateRepository)
        )
        _pictureViewModel = StateObject(
            wrappedValue: ProfilePictureViewModel(repository: pictureRepository)
        )
        print("🏗️ [VIEW] EditProfileView initialized")
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Form {
                    // MARK: - Profile Picture Section
                    Section(L("edit_profile.profile_picture")) {
                        VStack(spacing: 16) {
                            // 1️⃣ Current or selected image
                            if let image = pictureViewModel.selectedImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 120, height: 120)
                                    .clipShape(Circle())
                                    .shadow(radius: 6)
                            } else if let url = URL(string: UserSession.shared.userProfilePicture),
                                      !UserSession.shared.userProfilePicture.isEmpty {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 120, height: 120)
                                            .clipShape(Circle())
                                    case .failure:
                                        Image(systemName: "person.circle.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 120, height: 120)
                                            .foregroundColor(.gray.opacity(0.4))
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 120, height: 120)
                                    .foregroundColor(.gray.opacity(0.4))
                            }
                            
                            // 2️⃣ Select new photo
                            PhotosPicker(
                                L("edit_profile.choose_photo"),
                                selection: $selectedItem,
                                matching: .images
                            )
                            .onChange(of: selectedItem) { oldValue, newValue in
                                Task {
                                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                                       let uiImage = UIImage(data: data) {
                                        pictureViewModel.selectedImage = uiImage
                                        print("📸 [VIEW] Image selected")
                                    }
                                }
                            }
                            
                            // 3️⃣ Upload and update backend
                            Button {
                                print("📤 [VIEW] Upload button tapped")
                                pictureViewModel.uploadAndSaveProfilePicture()
                            } label: {
                                Text(L("edit_profile.save_new_picture"))
                                    .padding()
                                    .foregroundStyle(.white)
                                    .font(.caption)
                                    .background(
                                        RoundedRectangle(cornerRadius: 24)
                                            .fill(Color(hex: "4B548D"))
                                    )
                            }
                            .disabled(pictureViewModel.updateState == .updating || pictureViewModel.selectedImage == nil)
                            
                            // 4️⃣ Feedback
                            switch pictureViewModel.updateState {
                            case .idle:
                                EmptyView()
                            case .updating:
                                ProgressView(L("edit_profile.uploading"))
                            case .success(let message):
                                Text("✅ \(message)")
                                    .foregroundColor(.green)
                                    .font(.caption)
                            case .error(let error):
                                Text("❌ \(error)")
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 10)
                    }
                    
                    // MARK: - Personal Information Section
                    Section(L("edit_profile.personal_information")) {
                        EditFieldRow(
                            icon: "person.fill",
                            label: L("edit_profile.first_name"),
                            text: $viewModel.firstName
                        )
                        
                        EditFieldRow(
                            icon: "person.fill",
                            label: L("edit_profile.last_name"),
                            text: $viewModel.lastName
                        )
                        
                        EditFieldRow(
                            icon: "envelope.fill",
                            label: L("edit_profile.email"),
                            text: $viewModel.email,
                            keyboardType: .emailAddress
                        )
                    }
                    
                    // MARK: - Update Button
                    Section {
                        Button(action: {
                            print("💾 [VIEW] Save changes button tapped")
                            viewModel.updateProfile()
                        }) {
                            HStack {
                                Spacer()
                                if viewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                } else {
                                    Text(L("edit_profile.save_changes"))
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color(hex: "4B548D"))
                                }
                                Spacer()
                            }
                        }
                        .disabled(viewModel.isLoading)
                    }
                }
                .disabled(viewModel.isLoading)
                
                // MARK: - Loading Overlay
                if viewModel.isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text(L("edit_profile.updating"))
                            .foregroundColor(.white)
                            .fontWeight(.semibold)
                    }
                    .padding(32)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(hex: "4B548D"))
                            .shadow(color: .black.opacity(0.3), radius: 20)
                    )
                }
            }
            .navigationTitle(L("edit_profile.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L("edit_profile.cancel")) {
                        print("❌ [VIEW] Cancel button tapped")
                        dismiss()
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .alert(viewModel.alertTitle, isPresented: $viewModel.showAlert) {
                Button(L("edit_profile.ok"), role: .cancel) {
                    if viewModel.isSuccess {
                        shouldDismiss = true
                    }
                }
            } message: {
                Text(viewModel.alertMessage)
            }
            // ✅ React to profile update success
            .onChange(of: viewModel.isSuccess) { oldValue, newValue in
                if newValue {
                    print("✅ [VIEW] Profile update successful, scheduling dismissal")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        shouldDismiss = true
                    }
                }
            }
            // ✅ React to profile picture update success
            .onChange(of: pictureViewModel.updateState) { oldValue, newValue in
                if case .success(let message) = newValue {
                    print("✅ [VIEW] Profile picture updated: \(message)")
                    // Update UserSession with the new URL
                    if let uploadedUrl = pictureViewModel.uploadedUrl {
                        UserSession.shared.setProfilePicture(uploadedUrl)
                        print("✅ [VIEW] User Profile Picture saved in UserSession: \(uploadedUrl)")
                    }
                }
            }
            // ✅ Handle automatic dismissal
            .onChange(of: shouldDismiss) { oldValue, newValue in
                if newValue {
                    print("👋 [VIEW] Dismissing view after successful update")
                    dismiss()
                }
            }
            .onAppear {
                print("📱 [VIEW] EditProfileView appeared")
                viewModel.firstName = UserSession.shared.currentUser?.firstName ?? ""
                viewModel.lastName = UserSession.shared.currentUser?.lastName ?? ""
                viewModel.email = UserSession.shared.currentUser?.email ?? ""
                print("📝 [VIEW] Loaded user data: \(viewModel.firstName) \(viewModel.lastName)")
            }
        }
    }
}
