import SwiftUI
import AuthenticationServices
import CryptoKit

struct AuthenticationView: View {
    @EnvironmentObject var authService: AuthService
    
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景グラデーション
                LinearGradient(
                    colors: [Color.brandPurple.opacity(0.8), Color.brandPurple.opacity(0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        Spacer().frame(height: 60)
                        
                        // ロゴ・タイトル
                        VStack(spacing: 12) {
                            Image(systemName: "waveform.circle.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.white)
                            
                            Text("VoiceMatch")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("声で繋がる、新しい出会い")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        Spacer().frame(height: 20)
                        
                        // 入力フォーム
                        VStack(spacing: 16) {
                            TextField("メールアドレス", text: $email)
                                .textFieldStyle(AuthTextFieldStyle())
                                .autocapitalization(.none)
                                .keyboardType(.emailAddress)
                            
                            SecureField("パスワード", text: $password)
                                .textFieldStyle(AuthTextFieldStyle())
                            
                            // ログイン/登録ボタン
                            Button(action: {
                                performAuth()
                            }) {
                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text(isSignUp ? "アカウント作成" : "ログイン")
                                        .fontWeight(.bold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .foregroundColor(.brandPurple)
                            .cornerRadius(12)
                            .disabled(isLoading)
                            
                            // 切り替えボタン
                            Button(action: {
                                isSignUp.toggle()
                            }) {
                                Text(isSignUp ? "すでにアカウントをお持ちの方" : "新規登録はこちら")
                                    .foregroundColor(.white)
                                    .underline()
                            }
                        }
                        .padding(.horizontal, 30)
                        
                        // 区切り線
                        HStack {
                            Rectangle()
                                .fill(Color.white.opacity(0.5))
                                .frame(height: 1)
                            Text("または")
                                .foregroundColor(.white.opacity(0.8))
                                .font(.caption)
                            Rectangle()
                                .fill(Color.white.opacity(0.5))
                                .frame(height: 1)
                        }
                        .padding(.horizontal, 30)
                        
                        // ソーシャルログイン
                        VStack(spacing: 12) {
                            // Apple
                            SignInWithAppleButton(.signIn) { request in
                                let nonce = authService.prepareAppleSignIn()
                                request.requestedScopes = [.email, .fullName]
                                request.nonce = nonce
                            } onCompletion: { result in
                                handleAppleSignIn(result)
                            }
                            .signInWithAppleButtonStyle(.white)
                            .frame(height: 50)
                            .cornerRadius(12)
                            
                            // Google（オプション）
                            Button(action: {
                                signInWithGoogle()
                            }) {
                                HStack {
                                    Image(systemName: "g.circle.fill")
                                    Text("Googleでログイン")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white)
                                .foregroundColor(.black)
                                .cornerRadius(12)
                            }
                            
                            // ゲストログイン
                            Button(action: {
                                signInAnonymously()
                            }) {
                                Text("ゲストとして始める")
                                    .foregroundColor(.white.opacity(0.8))
                                    .underline()
                            }
                            .padding(.top, 10)
                        }
                        .padding(.horizontal, 30)
                        
                        Spacer()
                    }
                }
            }
            .navigationBarHidden(true)
            .alert("エラー", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - 認証処理
    
    private func performAuth() {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "メールアドレスとパスワードを入力してください"
            showError = true
            return
        }
        
        isLoading = true
        
        Task {
            do {
                if isSignUp {
                    try await authService.signUp(email: email, password: password)
                } else {
                    try await authService.signIn(email: email, password: password)
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isLoading = false
        }
    }
    
    private func signInWithGoogle() {
        Task {
            do {
                try await authService.signInWithGoogle()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func signInAnonymously() {
        Task {
            do {
                try await authService.signInAnonymously()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                Task {
                    do {
                        try await authService.signInWithApple(credential: appleIDCredential)
                    } catch {
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - カスタムテキストフィールドスタイル
struct AuthTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color.white.opacity(0.9))
            .cornerRadius(12)
    }
}

#Preview {
    AuthenticationView()
        .environmentObject(AuthService())
}
