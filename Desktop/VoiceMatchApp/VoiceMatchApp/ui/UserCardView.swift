import SwiftUI

struct UserCardView: View {
    let user: UserProfile
    
    // カードのデザイン定数
    private let cardCornerRadius: CGFloat = 20
    private let cardShadowRadius: CGFloat = 10
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // --- 1. 背景画像 ---
                if let urlString = user.profileImageURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Color.gray.opacity(0.3)
                                .overlay(ProgressView())
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            fallbackImage
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                } else {
                    // 画像がない場合
                    fallbackImage
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
                
                // --- 2. グラデーションオーバーレイ ---
                // 文字を見やすくするために下部を暗くする
                LinearGradient(
                    gradient: Gradient(colors: [.clear, .black.opacity(0.8)]),
                    startPoint: .center,
                    endPoint: .bottom
                )
                
                // --- 3. ユーザー情報 ---
                VStack(alignment: .leading, spacing: 12) {
                    // 名前
                    Text(user.username)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    // ここに bio や voiceIntroURL がありましたが、
                    // プロパティが存在しないため削除しました。
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading) // 左寄せを確実にする
            }
            .background(Color.white)
            .cornerRadius(cardCornerRadius)
            .shadow(radius: cardShadowRadius)
        }
    }
    
    // 画像読み込み失敗時やURLがない時のプレースホルダー
    var fallbackImage: some View {
        ZStack {
            Color.gray.opacity(0.2)
            Image(systemName: "person.fill")
                .resizable()
                .padding(50)
                .aspectRatio(contentMode: .fit)
                .foregroundColor(.gray.opacity(0.5))
        }
    }
}

// プレビューは一時的に無効化
/*
struct UserCardView_Previews: PreviewProvider {
    static var previews: some View {
        UserCardView(user: ... )
    }
}
*/
