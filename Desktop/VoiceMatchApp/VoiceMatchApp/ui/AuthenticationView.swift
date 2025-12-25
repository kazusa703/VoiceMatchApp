import SwiftUI
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import AuthenticationServices

struct AuthenticationView: View {
    @EnvironmentObject var userService: UserService
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("アカウントを作成して\n機能をフル活用しよう")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .padding(.top)
                
                // メール・パスワード入力
                VStack(spacing: 12) {
                    TextField("メールアドレス", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                    
                    SecureField("パスワード（6文字以上）", text: $password)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                Button(action: handleEmailAuth) {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text(isSignUp ? "新規登録" : "ログイン")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(LinearGradient.instaGradient)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
                .disabled(isLoading || email.isEmpty || password.count < 6)
                
                Button(action: { isSignUp.toggle() }) {
                    Text(isSignUp ? "すでにアカウントをお持ちの方はこちら" : "アカウントをお持ちでない方はこちら")
                        .font(.caption)
                        .foregroundColor(.brandPurple)
                }
                
                Divider().padding(.horizontal)
                
                // ソーシャルログイン
                
                // 1. Google
                GoogleSignInButton(action: handleGoogleSignIn)
                    .frame(height: 50)
                    .padding(.horizontal)
                
                // 2. Appleでサインイン
                SignInWithAppleButton(
                    onRequest: { request in
                        let nonce = authService.startSignInWithAppleFlow()
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = nonce
                    },
                    onCompletion: { result in
                        switch result {
                        case .success(let authorization):
                            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                                Task {
                                    do {
                                        try await authService.signInWithApple(credential: appleIDCredential)
                                        if let uid = Auth.auth().currentUser?.uid {
                                            try await userService.fetchOrCreateUserProfile(uid: uid)
                                        }
                                        dismiss()
                                    } catch {
                                        errorMessage = "Appleログインエラー: \(error.localizedDescription)"
                                    }
                                }
                            }
                        case .failure(let error):
                            print("Appleログイン失敗: \(error.localizedDescription)")
                        }
                    }
                )
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .padding(.horizontal)
                .cornerRadius(8)
                
                Spacer()
            }
            .navigationTitle(isSignUp ? "新規登録" : "ログイン")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
    
    // メール認証処理
    private func handleEmailAuth() {
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                if isSignUp {
                    try await Auth.auth().createUser(withEmail: email, password: password)
                } else {
                    try await Auth.auth().signIn(withEmail: email, password: password)
                }
                if let uid = Auth.auth().currentUser?.uid {
                    try await userService.fetchOrCreateUserProfile(uid: uid)
                }
                isLoading = false
                dismiss()
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }
    
    // Googleログイン処理
    private func handleGoogleSignIn() {
        Task {
            do {
                try await userService.signInWithGoogle()
                dismiss()
            } catch {
                errorMessage = "Googleログインエラー: \(error.localizedDescription)"
            }
        }
    }
}
