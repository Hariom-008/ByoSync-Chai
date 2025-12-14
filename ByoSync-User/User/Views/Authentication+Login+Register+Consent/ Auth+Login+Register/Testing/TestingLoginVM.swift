//
//  TestingLoginViewModel.swift
//  ByoSync
//
//  Testing view model for login with face verification
//

import Foundation
import Combine

final class TestingLoginViewModel: ObservableObject {
    
    // MARK: - Constants
    private let hardcodedDeviceKey = "1234abcde"
    private let hardcodedName = "Hariom"
    private let requiredFrameMatches = 4
    private let framesToCollect = 10
    
    // MARK: - Published State
    @Published var currentStep: LoginStep = .initial
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    
    // Frame collection
    @Published var framesCollected: Int = 0
    @Published var isCollectingFrames: Bool = false
    
    // Success states
    @Published var loginSuccess: Bool = false
    @Published var verificationResult: String?
    
    // MARK: - Private State
    private var authToken: String?
    private var cachedFaceIdData: GetFaceIdData?
    
    // MARK: - Dependencies
    private let cryptoService: any CryptoService
    private let loginRepository: LoginUserRepository
    private let faceIdFetchViewModel: FaceIdFetchViewModel
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Login Steps
    enum LoginStep: String {
        case initial = "Ready to Login"
        case fetchingInitialFaceIds = "Loading Face Data..."
        case loggingIn = "Logging In..."
        case fetchingFaceIds = "Loading Verification Data..."
        case collectingFrames = "Collecting Face Frames..."
        case verifying = "Verifying Face..."
        case success = "Login Successful!"
        case failed = "Login Failed"
    }
    
    // MARK: - Init
    init(
        cryptoService: any CryptoService = CryptoManager.shared,
        faceIdFetchViewModel: FaceIdFetchViewModel = FaceIdFetchViewModel()
    ) {
        self.cryptoService = cryptoService
        self.loginRepository = LoginUserRepository(cryptoService: cryptoService)
        self.faceIdFetchViewModel = faceIdFetchViewModel
        
        print("🧪 [TestingLoginVM] Initialized with deviceKey: \(hardcodedDeviceKey)")
    }
    
    // MARK: - Public Methods
    
    /// Step 1: Load FaceIds before login (if needed)
    func loadInitialFaceIdsIfNeeded() {
        guard cachedFaceIdData == nil else {
            print("💾 [TestingLoginVM] FaceId data already cached")
            return
        }
        
        currentStep = .fetchingInitialFaceIds
        isLoading = true
        
        print("🌐 [TestingLoginVM] Fetching initial FaceIds...")
        
        faceIdFetchViewModel.fetchFaceIds(for: hardcodedDeviceKey) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                self.isLoading = false
                
                switch result {
                case .success(let data):
                    print("✅ [TestingLoginVM] Initial FaceIds loaded: \(data.faceData.count) records")
                    self.cachedFaceIdData = data
                    self.currentStep = .initial
                    
                case .failure(let error):
                    print("❌ [TestingLoginVM] Failed to load initial FaceIds: \(error)")
                    self.showErrorMessage("Failed to load face data: \(error.localizedDescription)")
                    self.currentStep = .initial
                }
            }
        }
    }
    
    /// Step 2: Perform complete login flow
    func performCompleteLoginFlow(faceManager: FaceManager) {
        guard !isLoading else {
            print("⚠️ [TestingLoginVM] Already processing, ignoring duplicate call")
            return
        }
        
        // Reset state
        resetState()
        
        // Start login sequence
        performLogin(faceManager: faceManager)
    }
    
    /// Update frame collection progress
    func updateFrameCollection(count: Int) {
        framesCollected = count
        
        if count >= framesToCollect {
            isCollectingFrames = false
            print("✅ [TestingLoginVM] Frame collection complete: \(count) frames")
        }
    }
    
    /// Start frame collection
    func startFrameCollection() {
        framesCollected = 0
        isCollectingFrames = true
        currentStep = .collectingFrames
        print("🎥 [TestingLoginVM] Starting frame collection...")
    }
    
    /// Verify collected frames
    func verifyCollectedFrames(faceManager: FaceManager) {
        let frames = faceManager.VerifyFrameDistanceArray()
        
        guard frames.count >= framesToCollect else {
            showErrorMessage("Not enough frames collected: \(frames.count)/\(framesToCollect)")
            currentStep = .failed
            return
        }
        
        currentStep = .verifying
        isLoading = true
        
        print("🔍 [TestingLoginVM] Starting verification with \(frames.count) frames")
        
        // Load FaceIds into cache and verify
        faceManager.loadAndVerifyFaceID(
            deviceKey: hardcodedDeviceKey,
            framesToVerify: frames,
            requiredMatches: requiredFrameMatches,
            fetchViewModel: faceIdFetchViewModel
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                self.isLoading = false
                
                switch result {
                case .success(let verificationResult):
                    self.handleVerificationResult(verificationResult)
                    
                case .failure(let error):
                    print("❌ [TestingLoginVM] Verification failed: \(error)")
                    self.showErrorMessage("Verification failed: \(error.localizedDescription)")
                    self.currentStep = .failed
                }
            }
        }
    }
    
    /// Simplified testing login flow (login API → verify)
    func performTestingLogin(
        faceManager: FaceManager,
        validFrames: [[Float]],
        completion: @escaping (Result<BCHBiometric.VerificationResult, Error>) -> Void
    ) {
        currentStep = .loggingIn
        isLoading = true
        
        print("🚀 [TestingLoginVM] Starting testing login for: \(hardcodedName)")
        
        loginRepository.loginUser(
            name: hardcodedName,
            deviceKey: hardcodedDeviceKey,
            fcmToken: ""
        ) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let response):
                print("✅ [TestingLoginVM] Login successful")
                
                // Store token
                self.authToken = response.data?.device.token
                if let token = self.authToken {
                    print("🔑 [TestingLoginVM] Token received: \(token.prefix(20))...")
                    // Save to UserDefaults
                    UserDefaults.standard.set(token, forKey: "testingLoginToken")
                }
                
                // Now verify the face
                self.currentStep = .verifying
                print("🔍 [TestingLoginVM] Starting face verification...")
                
                faceManager.loadAndVerifyFaceID(
                    deviceKey: self.hardcodedDeviceKey,
                    framesToVerify: validFrames,
                    requiredMatches: self.requiredFrameMatches,
                    fetchViewModel: self.faceIdFetchViewModel
                ) { verifyResult in
                    DispatchQueue.main.async {
                        self.isLoading = false
                        
                        switch verifyResult {
                        case .success(let verification):
                            if verification.success {
                                self.currentStep = .success
                                self.loginSuccess = true
                            } else {
                                self.currentStep = .failed
                            }
                            completion(.success(verification))
                            
                        case .failure(let error):
                            self.currentStep = .failed
                            completion(.failure(error))
                        }
                    }
                }
                
            case .failure(let error):
                print("❌ [TestingLoginVM] Login failed: \(error)")
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.currentStep = .failed
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func performLogin(faceManager: FaceManager) {
        currentStep = .loggingIn
        isLoading = true
        
        print("🚀 [TestingLoginVM] Starting login for: \(hardcodedName)")
        
        loginRepository.loginUser(
            name: hardcodedName,
            deviceKey: hardcodedDeviceKey,
            fcmToken: ""
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch result {
                case .success(let response):
                    print("✅ [TestingLoginVM] Login successful")
                    
                    // Store token temporarily
                    self.authToken = response.data?.device.token
                    
                    if let token = self.authToken {
                        print("🔑 [TestingLoginVM] Token received: \(token.prefix(20))...")
                    }
                    
                    // Move to fetching FaceIds
                    self.fetchFaceIdsAfterLogin(faceManager: faceManager)
                    
                case .failure(let error):
                    print("❌ [TestingLoginVM] Login failed: \(error)")
                    self.isLoading = false
                    self.showErrorMessage("Login failed: \(error.localizedDescription)")
                    self.currentStep = .failed
                }
            }
        }
    }
    
    private func fetchFaceIdsAfterLogin(faceManager: FaceManager) {
        currentStep = .fetchingFaceIds
        
        print("🌐 [TestingLoginVM] Fetching FaceIds after login...")
        
        faceIdFetchViewModel.fetchFaceIds(for: hardcodedDeviceKey) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch result {
                case .success(let data):
                    print("✅ [TestingLoginVM] FaceIds fetched: \(data.faceData.count) records")
                    self.cachedFaceIdData = data
                    
                    // Move to frame collection
                    self.startFrameCollectionPhase(faceManager: faceManager)
                    
                case .failure(let error):
                    print("❌ [TestingLoginVM] Failed to fetch FaceIds: \(error)")
                    self.isLoading = false
                    self.showErrorMessage("Failed to load verification data: \(error.localizedDescription)")
                    self.currentStep = .failed
                }
            }
        }
    }
    
    private func startFrameCollectionPhase(faceManager: FaceManager) {
        isLoading = false
        startFrameCollection()
        
        // Observer for frame collection completion
        // The view will call verifyCollectedFrames when enough frames are collected
    }
    
    private func handleVerificationResult(_ result: BCHBiometric.VerificationResult) {
        print("📊 [TestingLoginVM] Verification result:")
        print("   • Success: \(result.success)")
        print("   • Match %: \(result.matchPercentage)")
        print("   • Notes: \(result.notes)")
        
        if result.success {
            currentStep = .success
            loginSuccess = true
            verificationResult = """
            ✅ Face Verified Successfully
            Match: \(String(format: "%.1f", result.matchPercentage))%
            \(result.notes)
            """
            
            // Save token to UserDefaults if needed
            if let token = authToken {
                UserDefaults.standard.set(token, forKey: "testingLoginToken")
                print("💾 [TestingLoginVM] Token saved to UserDefaults")
            }
            
        } else {
            currentStep = .failed
            verificationResult = """
            ❌ Face Verification Failed
            Match: \(String(format: "%.1f", result.matchPercentage))%
            \(result.notes)
            """
            showErrorMessage("Face verification failed. Please try again.")
        }
    }
    
    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }
    
    private func resetState() {
        isLoading = false
        errorMessage = nil
        showError = false
        framesCollected = 0
        isCollectingFrames = false
        loginSuccess = false
        verificationResult = nil
        authToken = nil
        currentStep = .initial
    }
}
