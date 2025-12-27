import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @StateObject private var authService = AuthService()
    @StateObject private var userService = UserService()
    @StateObject private var purchaseManager = PurchaseManager()
    
    // 利用規約への同意状態（ユーザーごとに管理）
    @AppStorage("hasAgreedToTerms") private var hasAgreedToTerms = false
    @AppStorage("agreedUserID") private var agreedUserID = ""
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                // 認証済みの場合
                if shouldShowTermsAgreement {
                    // 利用規約同意画面（初回または別アカウントでログイン時）
                    TermsAgreementView(hasAgreedToTerms: $hasAgreedToTerms)
                        .onChange(of: hasAgreedToTerms) { newValue in
                            if newValue {
                                // 同意したユーザーIDを記録
                                agreedUserID = authService.currentUser?.uid ?? ""
                            }
                        }
                } else if userService.currentUserProfile?.isAccountLocked == true {
                    // アカウント停止中
                    LockedAccountView()
                        .environmentObject(authService)
                } else {
                    // メイン画面
                    MainTabView()
                        .environmentObject(authService)
                        .environmentObject(userService)
                        .environmentObject(purchaseManager)
                }
            } else {
                // 未認証の場合
                AuthView()
                    .environmentObject(authService)
            }
        }
        .onChange(of: authService.currentUser?.uid) { newUID in
            // ユーザーが変わった場合、同意状態をリセット
            if let newUID = newUID, newUID != agreedUserID {
                hasAgreedToTerms = false
            }
        }
    }
    
    // 利用規約同意画面を表示すべきかどうか
    private var shouldShowTermsAgreement: Bool {
        guard let currentUID = authService.currentUser?.uid else { return false }
        
        // まだ同意していない、または別のアカウントで同意している場合
        return !hasAgreedToTerms || agreedUserID != currentUID
    }
}

#Preview {
    ContentView()
}
