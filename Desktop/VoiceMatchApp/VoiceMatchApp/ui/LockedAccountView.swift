import SwiftUI

struct LockedAccountView: View {
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // 警告アイコン
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 80))
                .foregroundColor(.red)
                .shadow(radius: 10)
            
            VStack(spacing: 16) {
                Text("アカウントが停止されました")
                    .font(.title2.bold())
                
                Text("複数のユーザーからの通報、または利用規約に違反する行為が確認されたため、このアカウントの使用を停止いたしました。")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            // お問い合わせ用（必要に応じてURLなどへ飛ばす）
            VStack(spacing: 8) {
                Text("心当たりがない場合や異議申し立ては")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text("support@voicematch-app.com")
                    .font(.subheadline.bold())
                    .foregroundColor(.brandPurple)
            }
            
            Spacer()
            
            // ログアウトして戻るボタン（他のアカウントで入り直せるように）
            Button(action: {
                authService.signOut()
            }) {
                Text("ログアウトして戻る")
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray)
                    .cornerRadius(30)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 50)
        }
        .background(Color.adaptiveBackground.ignoresSafeArea())
    }
}
