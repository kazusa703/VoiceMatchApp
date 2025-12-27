import Foundation
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import AuthenticationServices
import CryptoKit
import Combine

@MainActor
class AuthService: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isGuestMode = false
    
    // Apple Sign In 用
    var currentNonce: String?
    
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    init() {
        setupAuthStateListener()
    }
    
    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
    
    private func setupAuthStateListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.currentUser = user
                if let user = user {
                    self?.isAuthenticated = true
                    self?.isGuestMode = user.isAnonymous
                } else {
                    self?.isAuthenticated = false
                    self?.isGuestMode = false
                }
            }
        }
    }
    
    // MARK: - Google Sign In
    
    func signInWithGoogle() {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            errorMessage = "Firebase設定エラー"
            return
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            errorMessage = "画面取得エラー"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { [weak self] result, error in
            Task { @MainActor in
                if let error = error {
                    self?.isLoading = false
                    self?.errorMessage = "Googleログインエラー: \(error.localizedDescription)"
                    print("❌ Google Sign In エラー: \(error)")
                    return
                }
                
                guard let user = result?.user,
                      let idToken = user.idToken?.tokenString else {
                    self?.isLoading = false
                    self?.errorMessage = "Google認証トークン取得エラー"
                    return
                }
                
                let credential = GoogleAuthProvider.credential(
                    withIDToken: idToken,
                    accessToken: user.accessToken.tokenString
                )
                
                do {
                    let authResult = try await Auth.auth().signIn(with: credential)
                    self?.currentUser = authResult.user
                    self?.isAuthenticated = true
                    self?.isGuestMode = false
                    print("✅ Googleログイン成功: \(authResult.user.uid)")
                } catch {
                    self?.errorMessage = "Firebase認証エラー: \(error.localizedDescription)"
                    print("❌ Firebase認証エラー: \(error)")
                }
                
                self?.isLoading = false
            }
        }
    }
    
    // MARK: - Apple Sign In
    
    func handleAppleSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
    }
    
    func handleAppleSignInCompletion(_ result: Result<ASAuthorization, Error>) {
        isLoading = true
        errorMessage = nil
        
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                guard let nonce = currentNonce else {
                    errorMessage = "認証エラー: nonce が見つかりません"
                    isLoading = false
                    return
                }
                
                guard let appleIDToken = appleIDCredential.identityToken,
                      let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                    errorMessage = "認証トークン取得エラー"
                    isLoading = false
                    return
                }
                
                let credential = OAuthProvider.appleCredential(
                    withIDToken: idTokenString,
                    rawNonce: nonce,
                    fullName: appleIDCredential.fullName
                )
                
                Task {
                    do {
                        let authResult = try await Auth.auth().signIn(with: credential)
                        self.currentUser = authResult.user
                        self.isAuthenticated = true
                        self.isGuestMode = false
                        print("✅ Appleログイン成功: \(authResult.user.uid)")
                    } catch {
                        self.errorMessage = "Firebase認証エラー: \(error.localizedDescription)"
                        print("❌ Firebase認証エラー: \(error)")
                    }
                    self.isLoading = false
                }
            }
            
        case .failure(let error):
            // ユーザーがキャンセルした場合は何もしない
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue {
                isLoading = false
                return
            }
            errorMessage = "Appleログインエラー: \(error.localizedDescription)"
            isLoading = false
            print("❌ Apple Sign In エラー: \(error)")
        }
    }
    
    // MARK: - メールアドレス認証
    
    func signUp(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            currentUser = result.user
            isAuthenticated = true
            isGuestMode = false
            print("✅ 新規登録成功: \(result.user.uid)")
        } catch {
            errorMessage = convertAuthError(error)
            throw error
        }
        
        isLoading = false
    }
    
    func signIn(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            currentUser = result.user
            isAuthenticated = true
            isGuestMode = false
            print("✅ ログイン成功: \(result.user.uid)")
        } catch {
            errorMessage = convertAuthError(error)
            throw error
        }
        
        isLoading = false
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut() // Google もサインアウト
            currentUser = nil
            isAuthenticated = false
            isGuestMode = false
            print("✅ ログアウト成功")
        } catch {
            errorMessage = "ログアウトに失敗しました"
            print("❌ ログアウトエラー: \(error)")
        }
    }
    
    func resetPassword(email: String) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            print("✅ パスワードリセットメール送信成功")
        } catch {
            errorMessage = convertAuthError(error)
            throw error
        }
        
        isLoading = false
    }
    
    // MARK: - アカウント削除
    
    func deleteAccount() async throws {
        guard let user = currentUser else { return }
        
        isLoading = true
        
        do {
            try await user.delete()
            currentUser = nil
            isAuthenticated = false
            isGuestMode = false
            print("✅ アカウント削除成功")
        } catch {
            errorMessage = convertAuthError(error)
            throw error
        }
        
        isLoading = false
    }
    
    // MARK: - Helper Methods
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        return String(nonce)
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        return hashString
    }
    
    private func convertAuthError(_ error: Error) -> String {
        let nsError = error as NSError
        
        switch nsError.code {
        case AuthErrorCode.emailAlreadyInUse.rawValue:
            return "このメールアドレスは既に使用されています"
        case AuthErrorCode.invalidEmail.rawValue:
            return "無効なメールアドレスです"
        case AuthErrorCode.weakPassword.rawValue:
            return "パスワードが弱すぎます（6文字以上必要）"
        case AuthErrorCode.wrongPassword.rawValue:
            return "パスワードが間違っています"
        case AuthErrorCode.userNotFound.rawValue:
            return "ユーザーが見つかりません"
        case AuthErrorCode.networkError.rawValue:
            return "ネットワークエラーが発生しました"
        case AuthErrorCode.tooManyRequests.rawValue:
            return "リクエストが多すぎます。しばらく待ってから再試行してください"
        case AuthErrorCode.invalidCredential.rawValue:
            return "メールアドレスまたはパスワードが間違っています"
        default:
            return "エラーが発生しました: \(error.localizedDescription)"
        }
    }
}
