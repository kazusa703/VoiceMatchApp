import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @EnvironmentObject var authService: AuthService
    
    @State private var isLoginMode = true
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showResetPassword = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景グラデーション
                LinearGradient(
                    colors: [Color.brandPurple.opacity(0.8), Color.brandPurple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // ロゴ
                        VStack(spacing: 10) {
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
                        .padding(.top, 50)
                        
                        // ソーシャルログイン
                        VStack(spacing: 12) {
                            // Apple でログイン
                            SignInWithAppleButton(
                                onRequest: { request in
                                    authService.handleAppleSignInRequest(request)
                                },
                                onCompletion: { result in
                                    authService.handleAppleSignInCompletion(result)
                                }
                            )
                            .signInWithAppleButtonStyle(.white)
                            .frame(height: 50)
                            .cornerRadius(10)
                            
                            // Google でログイン
                            Button(action: {
                                authService.signInWithGoogle()
                            }) {
                                HStack(spacing: 10) {
                                    Image(systemName: "g.circle.fill")
                                        .font(.title2)
                                    Text("Googleでログイン")
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.white)
                                .cornerRadius(10)
                            }
                        }
                        .padding(.horizontal)
                        
                        // 区切り線
                        HStack {
                            Rectangle()
                                .fill(Color.white.opacity(0.5))
                                .frame(height: 1)
                            Text("または")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                            Rectangle()
                                .fill(Color.white.opacity(0.5))
                                .frame(height: 1)
                        }
                        .padding(.horizontal)
                        
                        // メール/パスワードフォーム
                        VStack(spacing: 16) {
                            // モード切り替え
                            Picker("", selection: $isLoginMode) {
                                Text("ログイン").tag(true)
                                Text("新規登録").tag(false)
                            }
                            .pickerStyle(.segmented)
                            
                            // メールアドレス
                            VStack(alignment: .leading, spacing: 6) {
                                Text("メールアドレス")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                TextField("example@email.com", text: $email)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .textContentType(.emailAddress)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                            }
                            
                            // パスワード
                            VStack(alignment: .leading, spacing: 6) {
                                Text("パスワード")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                SecureField("6文字以上", text: $password)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .textContentType(isLoginMode ? .password : .newPassword)
                            }
                            
                            // 確認用パスワード（新規登録時のみ）
                            if !isLoginMode {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("パスワード（確認）")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    SecureField("もう一度入力", text: $confirmPassword)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .textContentType(.newPassword)
                                }
                            }
                            
                            // エラーメッセージ
                            if let error = authService.errorMessage {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .padding(.horizontal)
                            }
                            
                            // メインボタン
                            Button(action: authenticate) {
                                if authService.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text(isLoginMode ? "ログイン" : "新規登録")
                                        .fontWeight(.bold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.brandPurple)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .disabled(authService.isLoading || !isFormValid)
                            .opacity(isFormValid ? 1 : 0.6)
                            
                            // パスワードリセット
                            if isLoginMode {
                                Button("パスワードを忘れた方はこちら") {
                                    showResetPassword = true
                                }
                                .font(.caption)
                                .foregroundColor(.brandPurple)
                            }
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(20)
                        .padding(.horizontal)
                        
                        Spacer().frame(height: 50)
                    }
                }
            }
            .sheet(isPresented: $showResetPassword) {
                ResetPasswordView()
                    .environmentObject(authService)
            }
        }
    }
    
    private var isFormValid: Bool {
        if isLoginMode {
            return !email.isEmpty && !password.isEmpty
        } else {
            return !email.isEmpty && password.count >= 6 && password == confirmPassword
        }
    }
    
    private func authenticate() {
        Task {
            do {
                if isLoginMode {
                    try await authService.signIn(email: email, password: password)
                } else {
                    try await authService.signUp(email: email, password: password)
                }
            } catch {
                print("認証エラー: \(error)")
            }
        }
    }
}

// MARK: - パスワードリセット画面

struct ResetPasswordView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    
    @State private var email = ""
    @State private var showSuccess = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("パスワードリセット")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("登録したメールアドレスを入力してください。パスワードリセット用のリンクを送信します。")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                TextField("メールアドレス", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding(.horizontal)
                
                if let error = authService.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                Button(action: resetPassword) {
                    if authService.isLoading {
                        ProgressView()
                    } else {
                        Text("リセットメールを送信")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.brandPurple)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
                .disabled(email.isEmpty || authService.isLoading)
                
                Spacer()
            }
            .padding(.top, 30)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") { dismiss() }
                }
            }
            .alert("送信完了", isPresented: $showSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("パスワードリセット用のメールを送信しました。メールを確認してください。")
            }
        }
    }
    
    private func resetPassword() {
        Task {
            do {
                try await authService.resetPassword(email: email)
                showSuccess = true
            } catch {
                print("パスワードリセットエラー: \(error)")
            }
        }
    }
}
